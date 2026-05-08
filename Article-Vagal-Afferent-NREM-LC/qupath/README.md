QuPath scripts and classifiers for c-Fos analysis.

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
