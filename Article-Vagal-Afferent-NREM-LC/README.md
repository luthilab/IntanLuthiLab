
# Vagal afferent activation induces a dissociated NREM sleep-like state with wake-related locus coeruleus activity

This repository contains MATLAB and QuPath scripts associated with the manuscript:

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
- `qupath/` – Scripts and classifiers used for c‑Fos image analysis

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
- QuPath (v0.4 or later) for c‑Fos image analysis

---

## 🧠 c‑Fos Image Analysis (QuPath)

c‑Fos expression in brain sections was quantified using **QuPath**, following a reproducible image‑analysis pipeline based on DAPI‑guided nucleus detection and supervised object classification.

### Nucleus detection
- Nuclei were detected using **StarDist2D** based on the DAPI channel.
- Detection was restricted to manually defined regions of interest (ROIs) corresponding to anatomical areas.
- The pretrained StarDist model `dsb2018_heavy_augment` was used.
- Detection parameters were adjusted conservatively to account for differences in image resolution and staining quality across experiments.

### c‑Fos classification
c‑Fos–positive nuclei were identified using **supervised object classifiers** implemented in QuPath.  
Due to differences in staining intensity, background, and cellular context across brain regions and experimental conditions, **separate classifiers were trained and applied**.

The following classifiers correspond to those used for the final quantitative analyses and are provided in this repository:

- **NTS / AP – vagal sensory neuron activation (DREADD) for figure 2**  
  `cfos_nts_ap_dreadd_classifier.json`

- **NTS / AP – control condition (CNO without vagal sensory neuron activation) for supplementary figure 2**  
  `cfos_nts_ap_control_classifier.json`

- **Locus coeruleus – vagal sensory neuron activation (DREADD) for figure 3**  
  `cfos_lc_dreadd_classifier.json`

All classifiers operate on the same set of nucleus detections and use fluorescence intensity and morphological features computed by QuPath.

For detailed scripts and classifiers, see the QuPath directory in this repository.

---

## 📜 Citation
If you use these scripts, please cite our paper:
> Cherrad N, Foustoukos G, Fernandez LMJ, Osorio-Forero A, Emmenegger Y, Franken P, Lüthi A. *Vagal afferent activation induces a dissociated NREM sleep-like state with wake-related locus coeruleus activity.* [Journal Name], Year.
