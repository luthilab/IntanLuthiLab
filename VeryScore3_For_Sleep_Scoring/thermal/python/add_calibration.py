#!/usr/bin/env python
"""
add_calibration.py - add (or replace) the degC lookup table in an existing .h5 produced by
ravi2h5.py, without converting the .ravi again.

    python add_calibration.py AH2_thermBL1.h5                       # auto-detect Kennlinie file
    python add_calibration.py AH2_thermBL1.h5 --kennlinie path\\to\\Kennlinie-25074068-53-M20-100.prn
    python add_calibration.py AH2_thermBL1.h5 --calib-dir D:\\cali

The Kennlinie file is searched in <project>/calibration, python/calibration and
%APPDATA%\\Imager\\Cali (see optris_calibration.py).  Per-frame statistics in degC
(stats/median_c, stats/max_c, stats/topN_mean_c) are recomputed from the stored frames.
"""
import argparse
import os
import sys

import h5py
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from optris_calibration import Kennlinie, EnergyToCelsius, find_kennlinie  # noqa: E402


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("h5")
    p.add_argument("--kennlinie")
    p.add_argument("--calib-dir", action="append")
    p.add_argument("--energy-offset", type=int, default=0)
    p.add_argument("--top-n", type=int, default=50)
    p.add_argument("--no-stats", action="store_true", help="do not recompute per-frame degC statistics")
    a = p.parse_args(argv)
    with h5py.File(a.h5, "r+") as h:
        serial, fov = int(h.attrs["serial"]), int(h.attrs["fov_deg"])
        tmin, tmax = float(h.attrs["range_min"]), float(h.attrs["range_max"])
        kfile = a.kennlinie or find_kennlinie(serial, fov, tmin, tmax, a.calib_dir)
        if not kfile:
            print("no Kennlinie file found for serial %d, FOV %d, range %g..%g" % (serial, fov, tmin, tmax))
            return 1
        k = Kennlinie.load(kfile)
        print("using", k)
        if k.serial and k.serial != serial:
            print("WARNING: Kennlinie serial %s differs from recording serial %d" % (k.serial, serial))
        conv = EnergyToCelsius(k, offset=a.energy_offset)
        if "celsius_lut" in h:
            del h["celsius_lut"]
        d = h.create_dataset("celsius_lut", data=conv.lut)
        d.attrs["kennlinie"] = os.path.basename(kfile)
        d.attrs["energy_offset"] = a.energy_offset
        h.attrs["kennlinie_file"] = os.path.abspath(kfile)
        h.attrs["energy_offset"] = a.energy_offset
        if not a.no_stats and "frames" in h:
            fr = h["frames"]
            n = fr.shape[0]
            med = np.zeros(n, np.float32); mx = np.zeros(n, np.float32); top = np.zeros(n, np.float32)
            step = fr.chunks[0] if fr.chunks else 16
            for j0 in range(0, n, step):
                blk = fr[j0:j0 + step]
                for j in range(blk.shape[0]):
                    t = conv(blk[j])
                    t = np.sort(t[~np.isnan(t)])
                    if t.size:
                        med[j0 + j], mx[j0 + j], top[j0 + j] = np.median(t), t[-1], t[-a.top_n:].mean()
                if (j0 // step) % 200 == 0:
                    print("  stats %d/%d" % (j0, n), flush=True)
            gs = h.require_group("stats")
            for name, v in (("median_c", med), ("max_c", mx), ("top%d_mean_c" % a.top_n, top)):
                if name in gs:
                    del gs[name]
                gs.create_dataset(name, data=v)
        print("done:", a.h5)
    return 0


if __name__ == "__main__":
    sys.exit(main())
