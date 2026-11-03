#!/usr/bin/env python
"""
ravi2h5.py - convert an Optris PIX Connect .ravi recording into a compact HDF5 file that
MATLAB (h5read / h5info) and Python (h5py) can read without any Optris software.

    python ravi2h5.py  AH2_thermBL1.ravi                 # -> AH2_thermBL1.h5 next to the input
    python ravi2h5.py  rec.ravi -o out.h5 --every 2      # keep every 2nd frame
    python ravi2h5.py  rec.ravi --bin 2                  # 2x2 spatial binning (mean), 4x smaller
    python ravi2h5.py  rec.ravi --crop 40 240 100 340    # rows r0:r1, cols c0:c1 (0-based, end exclusive)
    python ravi2h5.py  rec.ravi --no-frames              # only metadata + per-frame statistics (tiny)
    python ravi2h5.py  rec.ravi --calib-dir D:\\cali      # extra folder with Kennlinie-*.prn files
    python ravi2h5.py  rec.ravi --info                   # print file information and exit

HDF5 layout (dimension order as seen from Python; MATLAB's h5read returns the reversed
order, i.e. /frames is [width x height x nframes] in MATLAB):

    /frames          uint16 [n, H, W]   stored energy counts (int16 semantics), 0 = invalid pixel
    /celsius_lut     float32 [65536]    temperature for every possible stored value (NaN = invalid)
                                        -> only present when the camera's Kennlinie file was found
    /time_s          float64 [n]        seconds since recording start (from the camera frame counter)
    /frame_valid     uint8   [n]        1 = normal frame, 0 = shutter (flag) cycle or before the first flag event
    /meta/<name>     per-frame camera metadata (temp_chip, temp_flag, temp_box, hw_counter, flag_state, ...)
    /meta_raw        uint16 [n, 64]     the raw metadata line (first row of every stored frame)
    /stats/<name>    per-frame statistics in counts (median, p01, p99, max, top50_mean, mean)
    root attributes  serial, fov_deg, range_min/max, start_time (ISO), fps, camera_fps, width, height,
                     source_file, kennlinie_file, ...
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
import sys
import time

import h5py
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ravi_reader import RaviFile                                   # noqa: E402
from optris_calibration import Kennlinie, EnergyToCelsius, find_kennlinie  # noqa: E402

VERSION = "1.0"


def parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("ravi")
    p.add_argument("-o", "--output", help="output .h5 path (default: same name, .h5 extension)")
    p.add_argument("--every", type=int, default=1, help="keep every N-th frame (default 1 = all)")
    p.add_argument("--start", type=int, default=0, help="first frame index (0-based)")
    p.add_argument("--stop", type=int, default=None, help="stop frame index (exclusive)")
    p.add_argument("--bin", type=int, default=1, help="spatial binning factor (mean of KxK blocks)")
    p.add_argument("--crop", type=int, nargs=4, metavar=("R0", "R1", "C0", "C1"), help="crop rows R0:R1, cols C0:C1 before binning")
    p.add_argument("--no-frames", action="store_true", help="do not store the frames (metadata + statistics only)")
    p.add_argument("--compression", default="gzip", choices=["gzip", "lzf", "none"])
    p.add_argument("--gzip-level", type=int, default=1)
    p.add_argument("--chunk-frames", type=int, default=16, help="frames per HDF5 chunk (default 16)")
    p.add_argument("--calib-dir", action="append", help="additional folder(s) with Kennlinie-*.prn files")
    p.add_argument("--kennlinie", help="explicit Kennlinie .prn file to use")
    p.add_argument("--energy-offset", type=int, default=0, help="add this offset to the int16 energy before the lookup (expert)")
    p.add_argument("--top-n", type=int, default=50, help="N for the per-frame 'mean of N hottest pixels' statistic")
    p.add_argument("--info", action="store_true", help="only print information about the .ravi file")
    p.add_argument("--overwrite", action="store_true")
    return p.parse_args(argv)


def bin_frame(img, k):
    if k <= 1:
        return img
    h, w = img.shape
    h2, w2 = h // k * k, w // k * k
    return img[:h2, :w2].reshape(h2 // k, k, w2 // k, k).mean(axis=(1, 3))


def main(argv=None):
    a = parse_args(argv)
    r = RaviFile(a.ravi)
    print(r.summary())
    if a.info:
        return 0
    out = a.output or os.path.splitext(a.ravi)[0] + ".h5"
    if os.path.exists(out) and not a.overwrite:
        print("output exists, use --overwrite:", out)
        return 1

    m0 = r.meta0 or {}
    serial, fov, tmin, tmax = m0.get("serial"), m0.get("fov_deg"), m0.get("range_min"), m0.get("range_max")

    # ---- calibration -------------------------------------------------------
    kfile = a.kennlinie or (find_kennlinie(serial, fov, tmin, tmax, a.calib_dir) if serial else None)
    conv = None
    if kfile:
        k = Kennlinie.load(kfile)
        conv = EnergyToCelsius(k, offset=a.energy_offset)
        print("calibration:", k)
    else:
        print("WARNING: no Kennlinie file for serial %s, FOV %s, range %s..%s found -> frames are stored in counts only.\n"
              "         Copy Kennlinie-%s-%s-*.prn (from %%APPDATA%%\\Imager\\Cali of the recording PC) into the "
              "'calibration' folder and re-run, or run add_calibration.py on the .h5 later."
              % (serial, fov, tmin, tmax, serial, fov))

    # ---- frame selection -----------------------------------------------------
    stop = r.n_frames if a.stop is None else min(a.stop, r.n_frames)
    sel = np.arange(a.start, stop, a.every)
    n = len(sel)
    img0, _ = r.read_frame(int(sel[0]))
    if a.crop:
        r0, r1, c0, c1 = a.crop
        img0 = img0[r0:r1, c0:c1]
    img0b = bin_frame(img0.astype(np.float32), a.bin)
    H, W = img0b.shape
    store_dtype = np.uint16
    print(f"converting {n} frames -> {out}  (image {W}x{H}, bin {a.bin}, crop {a.crop})")

    # ---- metadata (all frames, fast) ------------------------------------------
    table = r.metadata_table()
    dec = r.decoded_metadata(table)
    times_all = r.frame_times()
    flag = dec["flag_state"]
    valid_all = (flag == 0).astype(np.uint8)
    first_flag = np.argmax(flag != 0) if (flag != 0).any() else 0
    valid_all[:first_flag] = 0          # frames before the first shutter reference are not calibrated

    with h5py.File(out, "w") as h:
        # root attributes
        attrs = dict(source_file=os.path.abspath(a.ravi), converter="ravi2h5.py v" + VERSION,
                     converted_at=dt.datetime.now().isoformat(timespec="seconds"),
                     width=W, height=H, n_frames=n, stored_width=r.frame_width, stored_height=r.frame_height,
                     image_width=r.image_width, image_height=r.image_height,
                     bin_factor=a.bin, crop=np.array(a.crop if a.crop else [0, r.image_height, 0, r.image_width]),
                     every=a.every, first_frame=int(sel[0]),
                     fps=float(r.fps or 0) / a.every, frame_interval_s=float(r.frame_interval or 0) * a.every,
                     camera_fps=float(r.camera_fps() or 0),
                     serial=int(serial or 0), fov_deg=int(fov or 0), range_min=float(tmin or 0), range_max=float(tmax or 0),
                     emissivity=float(m0.get("emissivity") or 0), transmissivity=float(m0.get("transmissivity") or 0),
                     start_time=(m0.get("start_time").isoformat(timespec="milliseconds") if m0.get("start_time") else ""),
                     kennlinie_file=os.path.abspath(kfile) if kfile else "",
                     energy_offset=a.energy_offset,
                     value_semantics="uint16 stored value; energy = int16(value) (two's complement); 0 = invalid pixel; "
                                     "temperature = celsius_lut[value+1] in MATLAB / celsius_lut[value] in Python",
                     meta_string=r.meta_string)
        for k_, v in attrs.items():
            h.attrs[k_] = v
        h.create_dataset("config_xml", data=np.bytes_(r.config_xml.encode("latin-1", "replace")))

        h.create_dataset("frame_index", data=sel.astype(np.int64))
        h.create_dataset("time_s", data=times_all[sel])
        h.create_dataset("frame_valid", data=valid_all[sel])
        h.create_dataset("meta_raw", data=table[sel], compression="gzip", compression_opts=4)
        g = h.create_group("meta")
        for k_, v in dec.items():
            g.create_dataset(k_, data=np.asarray(v)[sel])
        if conv is not None:
            h.create_dataset("celsius_lut", data=conv.lut)
            h["celsius_lut"].attrs["kennlinie"] = os.path.basename(kfile)
            h["celsius_lut"].attrs["energy_offset"] = a.energy_offset

        # ---- frames + statistics ----------------------------------------------
        st = {k_: np.zeros(n, dtype=np.float32) for k_ in ("median", "p01", "p99", "max", "min", "mean", "top%d_mean" % a.top_n)}
        st_c = {k_: np.zeros(n, dtype=np.float32) for k_ in ("median_c", "max_c", "top%d_mean_c" % a.top_n)} if conv else {}
        ds = None
        if not a.no_frames:
            comp = {} if a.compression == "none" else (dict(compression="gzip", compression_opts=a.gzip_level, shuffle=True)
                                                       if a.compression == "gzip" else dict(compression="lzf", shuffle=True))
            ds = h.create_dataset("frames", shape=(n, H, W), dtype=store_dtype, chunks=(min(a.chunk_frames, n), H, W), **comp)
            ds.attrs["dims"] = "python [frame, row, col]; MATLAB h5read -> [col, row, frame]"
        cf = min(a.chunk_frames, n)
        buf = np.zeros((cf, H, W), dtype=store_dtype)
        t0 = time.time()
        for j0 in range(0, n, cf):
            jj = range(j0, min(j0 + cf, n))
            for jj_i, j in enumerate(jj):
                img, _ = r.read_frame(int(sel[j]))
                if a.crop:
                    img = img[r0:r1, c0:c1]
                imf = img.astype(np.float32)
                if a.bin > 1:
                    # binning: treat invalid (0) pixels as NaN, then mean of valid pixels
                    imf[img == 0] = np.nan
                    hb, wb = imf.shape[0] // a.bin * a.bin, imf.shape[1] // a.bin * a.bin
                    blocks = imf[:hb, :wb].reshape(hb // a.bin, a.bin, wb // a.bin, a.bin)
                    with np.errstate(invalid="ignore"):
                        imb = np.nanmean(blocks, axis=(1, 3))
                    imb = np.where(np.isnan(imb), 0, imb)
                    img_out = np.rint(imb).astype(np.uint16)
                else:
                    img_out = img
                buf[jj_i] = img_out
                vals = img_out[img_out != 0].astype(np.float32)
                if vals.size:
                    e = vals.astype(np.uint16).astype(np.int16).astype(np.float32)   # energy for statistics
                    top = np.partition(e, -min(a.top_n, e.size))[-a.top_n:]
                    p01, med, p99 = np.percentile(e, [1, 50, 99])
                    st["median"][j], st["p01"][j], st["p99"][j] = med, p01, p99
                    st["max"][j], st["min"][j], st["mean"][j] = e.max(), e.min(), e.mean()
                    st["top%d_mean" % a.top_n][j] = top.mean()
                    if conv is not None:
                        tc = conv(img_out[img_out != 0])
                        tct = np.sort(tc[~np.isnan(tc)])
                        if tct.size:
                            st_c["median_c"][j] = np.median(tct)
                            st_c["max_c"][j] = tct[-1]
                            st_c["top%d_mean_c" % a.top_n][j] = tct[-a.top_n:].mean()
            if ds is not None:
                ds[j0:j0 + len(jj)] = buf[:len(jj)]
            if (j0 // cf) % 50 == 0:
                el = time.time() - t0
                print(f"  {j0 + len(jj)}/{n} frames, {el:.0f}s elapsed, {(n - j0 - len(jj)) * el / max(j0 + len(jj), 1):.0f}s left", flush=True)
        gs = h.create_group("stats")
        for k_, v in st.items():
            gs.create_dataset(k_, data=v)
        for k_, v in st_c.items():
            gs.create_dataset(k_, data=v)
        gs.attrs["note"] = "energy counts (int16) unless suffixed _c (degC); computed on valid pixels only"
    r.close()
    print(f"done in {time.time() - t0:.0f}s -> {out} ({os.path.getsize(out) / 1e9:.2f} GB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
