"""
ravi_reader.py - pure-Python reader for Optris PIX Connect radiometric video files (.ravi).

A .ravi file is an OpenDML/AVI 2.0 RIFF container with a single 16-bit video stream
(fourcc 'YUY2', but the payload is really uint16 little-endian samples).  Each frame is
(image_height + 1) rows x width columns.  For PIX Connect >= ~3.x the FIRST row of every
frame is a metadata line (camera temperatures, hardware frame counter, flag state, ...),
the remaining rows are the image.  Pixel values are calibrated *energy* counts (ADU) of
the camera, not degrees.  Use optris_calibration.EnergyToCelsius to convert.

No third-party dependency except numpy.

Typical use
-----------
    from ravi_reader import RaviFile
    r = RaviFile("rec.ravi")
    print(r)                      # summary
    img, meta = r.read_frame(0)   # img: uint16 (H, W); meta: uint16 (W,)
    tab = r.metadata_table()      # decoded metadata for all frames (numpy structured array)
"""
from __future__ import annotations

import datetime as _dt
import os
import re
import struct
from dataclasses import dataclass
from typing import Iterator, Optional

import numpy as np

__all__ = ["RaviFile", "decode_metadata_row", "META_FIELDS"]


# --------------------------------------------------------------------------------------
# RIFF helpers
# --------------------------------------------------------------------------------------
def _u32(b, o=0):
    return struct.unpack_from("<I", b, o)[0]


@dataclass
class _Chunk:
    fourcc: bytes
    offset: int      # offset of the 8-byte chunk header
    size: int        # payload size
    list_type: bytes = b""

    @property
    def data_offset(self):
        return self.offset + 8 + (4 if self.fourcc in (b"LIST", b"RIFF") else 0)

    @property
    def end(self):
        return self.offset + 8 + self.size + (self.size & 1)


def _iter_chunks(fh, start, end):
    """Iterate over the chunks between file offsets start and end (flat, no recursion)."""
    off = start
    while off + 8 <= end:
        fh.seek(off)
        hdr = fh.read(8)
        if len(hdr) < 8:
            return
        fourcc, size = hdr[:4], _u32(hdr, 4)
        ltype = b""
        if fourcc in (b"LIST", b"RIFF"):
            ltype = fh.read(4)
        yield _Chunk(fourcc, off, size, ltype)
        off += 8 + size + (size & 1)


# --------------------------------------------------------------------------------------
# Metadata row decoding
# --------------------------------------------------------------------------------------
# Word layout of the metadata line (uint16 words), reverse engineered from PIX Connect
# files (header versions 1004..1013).  Unknown words are kept in 'raw'.
META_FIELDS = [
    ("header_bytes", 0, "u16", None),          # size of the metadata block in bytes (80/96/128)
    ("header_version", 1, "u16", None),        # 1004, 1006, 1007, 1013 ...
    ("serial", 2, "u32", None),                # words 2..3 little endian
    ("width", 4, "u16", None),
    ("height", 5, "u16", None),
    ("temp_chip", 8, "u16", 0.01),             # degC
    ("temp_flag", 9, "u16", 0.01),             # degC (shutter flag)
    ("temp_box", 10, "u16", 0.01),             # degC (housing)
    ("temp_optics", 12, "u16", 0.01),          # degC (0 on older cameras)
    ("range_index", 13, "u16", None),
    ("emissivity", 14, "u16", 0.001),
    ("t_ambient", 15, "u16", "t1000"),         # degC, (v-1000)/10
    ("fov_deg", 16, "u16", None),
    ("range_min", 17, "u16", "t1000"),         # degC, (v-1000)/10
    ("range_max", 18, "u16", "t1000"),
    ("start_ticks", 24, "u64", None),          # .NET DateTime ticks (100 ns since 0001-01-01), recording start
    ("transmissivity", 34, "u16", 0.001),
    ("hw_counter", 36, "u16", None),           # camera frame counter (16 bit, wraps)
    ("counter_hi", 37, "u16", None),           # slowly incrementing (wrap count / event count)
    ("flag_state", 38, "u16", None),           # 0 = open (normal), 1..3 = shutter cycle in progress
]


def decode_metadata_row(row: np.ndarray) -> dict:
    """Decode one metadata line (uint16 array) into a dict of physical values."""
    w = np.asarray(row, dtype=np.uint64)
    out = {}
    for name, idx, typ, scale in META_FIELDS:
        if idx >= len(w):
            out[name] = None
            continue
        if typ == "u16":
            v = int(w[idx])
        elif typ == "u32":
            v = int(w[idx]) | (int(w[idx + 1]) << 16)
        else:  # u64
            v = int(w[idx]) | (int(w[idx + 1]) << 16) | (int(w[idx + 2]) << 32) | (int(w[idx + 3]) << 48)
        if scale == "t1000":
            v = (v - 1000) / 10.0
        elif scale is not None:
            v = v * scale
        out[name] = v
    t = out.get("start_ticks") or 0
    try:
        out["start_time"] = (_dt.datetime(1, 1, 1) + _dt.timedelta(microseconds=t / 10.0)) if 0 < t < 4e18 else None
    except (OverflowError, ValueError):
        out["start_time"] = None
    out["raw"] = np.asarray(row[:64], dtype=np.uint16).copy()
    return out


# --------------------------------------------------------------------------------------
# Main class
# --------------------------------------------------------------------------------------
class RaviFile:
    """Random access to the frames of a PIX Connect .ravi file."""

    def __init__(self, path: str):
        self.path = os.fspath(path)
        self.size = os.path.getsize(self.path)
        self._fh = open(self.path, "rb")
        self.frame_width = self.frame_height = 0        # size of the stored frame (incl. metadata row)
        self.fps = None                                 # stored frame rate (frames / s)
        self.frame_interval = None                      # seconds
        self.meta_string = ""                           # content of the 'META' info chunk
        self.config_xml = ""                            # PIX Connect layout embedded in the file
        self.total_frames_header = None
        self._parse()
        self.n_frames = len(self.frame_offsets)
        self._detect_layout()

    # ---------------------------------------------------------------- parsing
    def _parse(self):
        fh = self._fh
        riffs = list(_iter_chunks(fh, 0, self.size))
        if not riffs or riffs[0].fourcc != b"RIFF":
            raise ValueError("not a RIFF/AVI file: %s" % self.path)
        self.riff_segments = riffs
        first = riffs[0]
        offsets, sizes = [], []
        indx_entries = []
        for ch in _iter_chunks(fh, first.data_offset, first.end):
            if ch.fourcc == b"LIST" and ch.list_type == b"hdrl":
                for sub in _iter_chunks(fh, ch.data_offset, ch.end):
                    if sub.fourcc == b"avih":
                        fh.seek(sub.data_offset)
                        av = struct.unpack("<14I", fh.read(56))
                        self.total_frames_header = av[4]
                        self.us_per_frame = av[0]
                        self.avih_width, self.avih_height = av[8], av[9]
                    elif sub.fourcc == b"LIST" and sub.list_type == b"strl":
                        for s2 in _iter_chunks(fh, sub.data_offset, sub.end):
                            if s2.fourcc == b"strh":
                                fh.seek(s2.data_offset)
                                strh = fh.read(56)
                                scale, rate = struct.unpack_from("<II", strh, 20)
                                if scale:
                                    self.fps = rate / scale
                                    self.frame_interval = scale / rate
                                self.stream_length = struct.unpack_from("<I", strh, 32)[0]
                            elif s2.fourcc == b"strf":
                                fh.seek(s2.data_offset)
                                bih = fh.read(40)
                                self.frame_width = struct.unpack_from("<i", bih, 4)[0]
                                self.frame_height = abs(struct.unpack_from("<i", bih, 8)[0])
                                self.bit_count = struct.unpack_from("<H", bih, 14)[0]
                                self.fourcc = bih[16:20]
                            elif s2.fourcc == b"indx":
                                fh.seek(s2.data_offset)
                                d = fh.read(s2.size)
                                n = _u32(d, 4)
                                for i in range(n):
                                    qw, sz, dur = struct.unpack_from("<QII", d, 24 + 16 * i)
                                    indx_entries.append((qw, sz, dur))
                    elif sub.fourcc == b"LIST" and sub.list_type == b"odml":
                        for s2 in _iter_chunks(fh, sub.data_offset, sub.end):
                            if s2.fourcc == b"dmlh":
                                fh.seek(s2.data_offset)
                                self.total_frames_header = _u32(fh.read(4))
            elif ch.fourcc == b"LIST" and ch.list_type == b"INFO":
                parts = []
                for sub in _iter_chunks(fh, ch.data_offset, ch.end):
                    fh.seek(sub.data_offset)
                    d = fh.read(sub.size)
                    if sub.fourcc == b"META":
                        self.meta_string = d.rstrip(b"\0").decode("latin-1")
                    elif re.match(rb"I\d{3}", sub.fourcc):
                        parts.append(d)
                self.config_xml = b"".join(parts).rstrip(b"\0").decode("latin-1", "replace")
        # frame index: prefer OpenDML super index -> standard indexes
        if indx_entries:
            for qw, sz, dur in indx_entries:
                fh.seek(qw)
                h = fh.read(32)
                if h[:4] != b"ix00":
                    raise ValueError("unexpected index chunk %r at %d" % (h[:4], qw))
                n_use = _u32(h, 12)
                base = struct.unpack_from("<Q", h, 20)[0]
                body = np.frombuffer(fh.read(n_use * 8), dtype="<u4").reshape(n_use, 2)
                offsets.extend((base + body[:, 0].astype(np.int64)).tolist())
                sizes.extend((body[:, 1] & 0x7FFFFFFF).tolist())
        else:  # fallback: linear scan of every movi list in every RIFF segment
            for r in riffs:
                for ch in _iter_chunks(fh, r.data_offset, r.end):
                    if ch.fourcc == b"LIST" and ch.list_type == b"movi":
                        for sub in _iter_chunks(fh, ch.data_offset, ch.end):
                            if sub.fourcc[2:] in (b"db", b"dc") and sub.size > 0:
                                offsets.append(sub.data_offset)
                                sizes.append(sub.size)
        self.frame_offsets = np.asarray(offsets, dtype=np.int64)
        self.frame_sizes = np.asarray(sizes, dtype=np.int64)
        if len(self.frame_offsets) == 0:
            raise ValueError("no video frames found in %s" % self.path)
        exp = self.frame_width * self.frame_height * 2
        if exp != int(self.frame_sizes[0]) and hasattr(self, "avih_width"):
            # very old PIX/PI Connect files carry a bogus BITMAPINFOHEADER; trust avih instead
            if self.avih_width * self.avih_height * 2 == int(self.frame_sizes[0]):
                self.frame_width, self.frame_height = self.avih_width, self.avih_height
                exp = self.frame_width * self.frame_height * 2
        bad = np.nonzero(self.frame_sizes != exp)[0]
        if len(bad):
            raise ValueError("%d frames have unexpected size (expected %d bytes)" % (len(bad), exp))

    def _detect_layout(self):
        """Decide where the metadata line is and the image height."""
        m = re.match(r"\((\d+),(\d+),(\d+),(\d+)\)", self.meta_string or "")
        self.image_width = self.frame_width
        self.image_height = int(m.group(2)) if m else None
        raw0 = self.read_raw(0)
        row0 = raw0[0]
        looks_like_meta = (row0[0] in (80, 96, 112, 128, 144, 160) and 1000 <= row0[1] < 1100
                           and row0[4] == self.frame_width)
        if looks_like_meta:
            self.meta_row = 0
        elif self.image_height is not None and self.frame_height == self.image_height + 1:
            self.meta_row = self.frame_height - 1      # old files: metadata line last
        else:
            self.meta_row = None
        if self.image_height is None:
            self.image_height = self.frame_height - (0 if self.meta_row is None else 1)
        self.has_metadata = self.meta_row is not None
        self.meta0 = decode_metadata_row(row0) if self.meta_row == 0 else (
            decode_metadata_row(raw0[self.meta_row]) if self.meta_row is not None else None)

    # ---------------------------------------------------------------- access
    def read_raw(self, i: int) -> np.ndarray:
        """Stored frame i as uint16 array (frame_height, frame_width), metadata row included."""
        i = int(i)
        if i < 0:
            i += self.n_frames
        self._fh.seek(int(self.frame_offsets[i]))
        buf = self._fh.read(int(self.frame_sizes[i]))
        return np.frombuffer(buf, dtype="<u2").reshape(self.frame_height, self.frame_width)

    def read_frame(self, i: int):
        """(image uint16 (image_height, width), metadata_row uint16 (width,) or None)."""
        raw = self.read_raw(i)
        if self.meta_row is None:
            return raw, None
        if self.meta_row == 0:
            return raw[1:], raw[0]
        return raw[:-1], raw[-1]

    def read_metadata_row(self, i: int) -> Optional[np.ndarray]:
        if self.meta_row is None:
            return None
        i = int(i)
        off = int(self.frame_offsets[i]) + self.meta_row * self.frame_width * 2
        self._fh.seek(off)
        return np.frombuffer(self._fh.read(self.frame_width * 2), dtype="<u2")

    def iter_frames(self, start=0, stop=None, step=1) -> Iterator[tuple]:
        stop = self.n_frames if stop is None else min(stop, self.n_frames)
        for i in range(start, stop, step):
            yield i, self.read_frame(i)

    def metadata_table(self, n_words=64) -> np.ndarray:
        """Raw metadata words of every frame: uint16 array (n_frames, n_words). Fast (reads 128 bytes/frame)."""
        if self.meta_row is None:
            return np.zeros((self.n_frames, n_words), dtype=np.uint16)
        n_words = min(n_words, self.frame_width)
        out = np.zeros((self.n_frames, n_words), dtype=np.uint16)
        rowoff = self.meta_row * self.frame_width * 2
        for i in range(self.n_frames):
            self._fh.seek(int(self.frame_offsets[i]) + rowoff)
            out[i] = np.frombuffer(self._fh.read(n_words * 2), dtype="<u2")
        return out

    def decoded_metadata(self, table=None) -> dict:
        """Per-frame decoded metadata as dict of numpy arrays (+ unwrapped hardware counter)."""
        M = self.metadata_table() if table is None else table
        M64 = M.astype(np.int64)
        d = {}
        d["temp_chip"] = M64[:, 8] * 0.01
        d["temp_flag"] = M64[:, 9] * 0.01
        d["temp_box"] = M64[:, 10] * 0.01
        d["temp_optics"] = M64[:, 12] * 0.01
        d["t_ambient"] = (M64[:, 15] - 1000) / 10.0
        d["emissivity"] = M64[:, 14] * 0.001
        d["transmissivity"] = M64[:, 34] * 0.001
        d["flag_state"] = M[:, 38].astype(np.uint8)
        d["counter_hi"] = M[:, 37].astype(np.uint16)
        hw = M64[:, 36]
        dh = np.diff(hw)
        dh[dh < 0] += 65536
        d["hw_counter"] = np.concatenate([[hw[0]], hw[0] + np.cumsum(dh)]).astype(np.int64)
        return d

    def camera_fps(self) -> Optional[float]:
        """Camera frame rate from the embedded layout (<Videoformat><FR>), if present."""
        m = re.search(r"<Videoformat>.*?<FR>([\d.]+)</FR>", self.config_xml, flags=re.S)
        return float(m.group(1)) if m else None

    def frame_times(self, use_hw_counter=True) -> np.ndarray:
        """Seconds since recording start for every stored frame.

        With use_hw_counter the camera's hardware frame counter and the camera frame rate are
        used (exact, robust to dropped frames); otherwise k / fps.
        """
        cam_fps = self.camera_fps()
        if use_hw_counter and self.has_metadata and cam_fps:
            hw = self.decoded_metadata()["hw_counter"]
            return (hw - hw[0]) / cam_fps
        return np.arange(self.n_frames) * (self.frame_interval or 0.0)

    # ---------------------------------------------------------------- misc
    def summary(self) -> str:
        m = self.meta0 or {}
        lines = [f"RaviFile: {self.path}",
                 f"  size            : {self.size / 1e9:.3f} GB, {len(self.riff_segments)} RIFF segment(s)",
                 f"  stored frame    : {self.frame_width} x {self.frame_height} x {self.bit_count} bit  (fourcc {self.fourcc!r})",
                 f"  image           : {self.image_width} x {self.image_height}  (metadata row: {self.meta_row})",
                 f"  frames          : {self.n_frames} (header says {self.total_frames_header})",
                 f"  stored fps      : {self.fps:.4f}  -> duration {self.n_frames * self.frame_interval / 3600:.3f} h" if self.fps else "  stored fps      : ?",
                 f"  camera fps      : {self.camera_fps()}",
                 f"  META            : {self.meta_string}"]
        if m:
            lines += [f"  serial          : {m.get('serial')}   FOV {m.get('fov_deg')} deg   header v{m.get('header_version')}",
                      f"  temp range      : {m.get('range_min')} .. {m.get('range_max')} degC",
                      f"  emissivity      : {m.get('emissivity')}   transmissivity {m.get('transmissivity')}   T_ambient {m.get('t_ambient')} degC",
                      f"  start time      : {m.get('start_time')}",
                      f"  T chip/flag/box : {m.get('temp_chip')} / {m.get('temp_flag')} / {m.get('temp_box')} degC (frame 0)"]
        return "\n".join(lines)

    def __repr__(self):
        return self.summary()

    def close(self):
        if self._fh:
            self._fh.close()
            self._fh = None

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.close()


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:]:
        with RaviFile(p) as r:
            print(r.summary())
