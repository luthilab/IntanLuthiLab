
# Vagal afferent activation induces a dissociated NREM sleep-like state with wake-related locus coeruleus activity

This repository contains MATLAB scripts associated with the manuscript:

**Authors:** Najma Cherrad, Georgios Foustoukos, Laura MJ Fernandez, Alejandro Osorio-Forero, Yann Emmenegger, Paul Franken, Anita Lüthi*

---

## 📂 Repository Contents
Each script corresponds to a specific analysis or figure in the manuscript:

- `f_HeartRate_nrem.m` – Calculate heart rate during NREM sleep
- `f_HeartRate_rem.m` – Calculate heart rate during REM sleep
- `LCact_VNS.m` – Analyze LC activity during VSN stimulation
- `f_ReduceAndNameChnsAndAddFib.m` – Preprocess fiber photometry data
- `p_PowerSpectrum_Dynamics_nrems.m` – Compute power dynamics for NREMS
- `f_corticaltemperature.m` – Convert voltage to cortical temperature
- `f_drop_temperature.m` – Calculate maximal temperature drop
- `f_temp_recoveryREMS.m` – Calculate temperature recovery at first REMS

Additional details for each figure are in `docs/Figure_Instructions.md`.

---

## ▶️ How to Use
1. Download or clone this repository.
2. Open MATLAB and add the folder containing the scripts to your path.
3. Call the relevant function with the required inputs (see comments in each `.m` file).
4. Refer to `docs/Figure_Instructions.md` for figure-specific workflows.

---

## 🛠 Requirements
- MATLAB R2021a to R2025a
- Toolboxes:
  - Signal Processing Toolbox
  - Wavelet Toolbox
- QuPath for cFos analysis (see `QuPath_Code.txt`)

---

## 📜 Citation
If you use these scripts, please cite our paper:
> Cherrad N, Foustoukos G, Fernandez LMJ, Osorio-Forero A, Emmenegger Y, Franken P, Lüthi A. *Vagal afferent activation induces a dissociated NREM sleep-like state with wake-related locus coeruleus activity.* [Journal Name], Year.
