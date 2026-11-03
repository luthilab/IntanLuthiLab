"""
optris_calibration.py - energy (ADU) -> temperature conversion for Optris PI/Xi cameras.

PIX Connect stores calibrated *energy* counts in .ravi files (uint16, to be read as int16).
The camera-specific characteristic curve ("Kennlinie") maps energy -> degC.  The Kennlinie
files are text tables named

    Kennlinie-<serial>-<fov>-<range>.prn      e.g. Kennlinie-25074068-53-M20-100.prn

(range "M20-100" = -20..100 degC, "0-250", "150-900" ...).  PIX Connect keeps them in
%APPDATA%\\Imager\\Cali on the PC that was connected to the camera (Xi cameras hand them
over from their internal memory).  Copy the files of your camera into the folder
<project>/calibration (or pass --calib-dir) and the conversion becomes available.

Convention used here (verified against PIX Connect sample data):
    energy = int16(stored uint16 value)     (two's complement reinterpretation)
    T[degC] = Kennlinie(energy)             (linear interpolation in the table)
    stored value 0  -> invalid pixel (dead pixel), mapped to NaN
"""
from __future__ import annotations

import glob
import os
import re
from dataclasses import dataclass, field
from typing import Optional

import numpy as np

__all__ = ["Kennlinie", "range_tag", "find_kennlinie", "calibration_dirs", "EnergyToCelsius"]

_HERE = os.path.dirname(os.path.abspath(__file__))


def calibration_dirs(extra=None):
    """Folders searched for calibration files, in order."""
    dirs = []
    if extra:
        dirs += [extra] if isinstance(extra, str) else list(extra)
    dirs.append(os.path.join(os.path.dirname(_HERE), "calibration"))
    dirs.append(os.path.join(_HERE, "calibration"))
    appdata = os.environ.get("APPDATA")
    if appdata:
        dirs.append(os.path.join(appdata, "Imager", "Cali"))
    return [d for d in dirs if d and os.path.isdir(d)]


def range_tag(tmin, tmax):
    """(-20, 100) -> 'M20-100' ; (0, 250) -> '0-250'."""
    def f(v):
        v = int(round(float(v)))
        return ("M%d" % -v) if v < 0 else "%d" % v
    return "%s-%s" % (f(tmin), f(tmax))


def find_kennlinie(serial, fov=None, tmin=None, tmax=None, dirs=None):
    """Return the path of the matching Kennlinie file or None."""
    pats = []
    if fov is not None and tmin is not None and tmax is not None:
        pats.append("Kennlinie-%d-%d-%s.prn" % (int(serial), int(fov), range_tag(tmin, tmax)))
    if tmin is not None and tmax is not None:
        pats.append("Kennlinie-%d-*-%s.prn" % (int(serial), range_tag(tmin, tmax)))
    pats.append("Kennlinie-%d-*.prn" % int(serial))
    for d in calibration_dirs(dirs):
        for p in pats:
            hits = sorted(glob.glob(os.path.join(d, p)))
            if hits:
                return hits[0]
    return None


@dataclass
class Kennlinie:
    """Characteristic curve energy -> temperature (degC)."""
    energy: np.ndarray
    celsius: np.ndarray
    path: str = ""
    serial: Optional[int] = None
    fov: Optional[int] = None
    range_tag_: str = ""

    @classmethod
    def load(cls, path):
        txt = open(path, "r", encoding="latin-1").read()
        rows = re.findall(r"^\s*(-?\d+)\s*(-?\d+(?:\.\d+)?)\s*$", txt, flags=re.M)
        if len(rows) < 10:
            raise ValueError("cannot parse Kennlinie file %s" % path)
        e = np.array([int(a) for a, _ in rows], dtype=np.int64)
        t = np.array([float(b) for _, b in rows], dtype=np.float64)
        order = np.argsort(e)
        e, t = e[order], t[order]
        m = re.search(r"Kennlinie-(\d+)-(\d+)-([M\d]+-\d+)\.prn$", os.path.basename(path), flags=re.I)
        return cls(e, t, path, int(m.group(1)) if m else None, int(m.group(2)) if m else None, m.group(3) if m else "")

    def celsius_of(self, energy, extrapolate=False):
        energy = np.asarray(energy, dtype=np.float64)
        t = np.interp(energy, self.energy, self.celsius)
        if not extrapolate:
            t = np.where((energy < self.energy[0]) | (energy > self.energy[-1]), np.nan, t)
        return t

    def energy_of(self, celsius):
        return np.interp(np.asarray(celsius, dtype=np.float64), self.celsius, self.energy)

    def slope_counts_per_kelvin(self, celsius):
        e = self.energy_of(np.asarray(celsius, dtype=np.float64))
        return 1.0 / np.gradient(self.celsius, self.energy)[np.searchsorted(self.energy, e).clip(0, len(self.energy) - 1)]

    def __repr__(self):
        return ("Kennlinie(%s: serial %s, FOV %s, range %s, E %d..%d -> T %.1f..%.1f degC)"
                % (os.path.basename(self.path), self.serial, self.fov, self.range_tag_,
                   self.energy[0], self.energy[-1], self.celsius[0], self.celsius[-1]))


class EnergyToCelsius:
    """uint16 stored value -> degC through a 65536-entry lookup table."""

    def __init__(self, kennlinie: Kennlinie, offset=0, invalid_value=0):
        self.kennlinie = kennlinie
        self.offset = int(offset)
        codes = np.arange(65536, dtype=np.int64)
        energy = codes.copy()
        energy[energy >= 32768] -= 65536          # int16 reinterpretation
        energy += self.offset
        lut = kennlinie.celsius_of(energy).astype(np.float32)
        if invalid_value is not None:
            lut[int(invalid_value)] = np.nan
        self.lut = lut

    def __call__(self, stored):
        return self.lut[np.asarray(stored, dtype=np.uint16)]

    @staticmethod
    def energy(stored):
        """int16 energy from stored uint16 values."""
        return np.asarray(stored, dtype=np.uint16).astype(np.int16).astype(np.int32)


if __name__ == "__main__":
    import sys
    for p in sys.argv[1:] or []:
        k = Kennlinie.load(p)
        print(k)
        for t in (-20, 0, 20, 25, 30, 35, 37, 40, 100):
            print("  %5.0f degC -> E = %7.0f  (%.1f counts/K)" % (t, k.energy_of(t), k.slope_counts_per_kelvin(t)))
    if not sys.argv[1:]:
        print("search dirs:", calibration_dirs())
