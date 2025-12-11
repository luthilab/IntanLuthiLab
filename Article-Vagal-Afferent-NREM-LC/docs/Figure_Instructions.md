
# Figure Instructions for Manuscript Analyses

This document provides detailed instructions for reproducing each figure from the manuscript:

**Title:** Vagal afferent activation induces a dissociated NREM sleep-like state with wake-related locus coeruleus activity.

---

## Figure 1: Anatomical and in vitro functional identification of vagal sensory neurons (VSNs)
- All data were manually analyzed using pClamp software.

## Figure 2: Validation of the in vivo efficacy of chemogenetic activation of VSNs
- **Figure 2c:** cFos counts obtained through QuPath using a pretrained supervised machine learning model. See `QuPath_Code.txt` for steps.
- **Figure 2f:** Heart rates calculated using `f_HeartRate_nrem.m` and `f_HeartRate_rem.m` applied to state vectors `b` and EMG traces.
- **Figure 2g:** Ethovision right (no codes provided).

## Figure 3: Activation of the LC by chemogenetic stimulation of VSNs
- **Figure 3a:** cFos counts as described for Figure 2c.
- **Figure 3d1-4:** Plots in d1,d2 from `LCact_VNS.m` using vigilance state file `b` and ΔF/F0 data. File generation shown in `f_ReduceAndNameChnsAndAddFib.m`. Plots in d3,d4 from Morlet Wavelet-based spectral analysis.

## Figure 4: Chemogenetic activation of VSN axons induces a NREMS-like state
- Power dynamics calculated using `p_PowerSpectrum_Dynamics_nrems.m` from PSA structures storing power spectral densities.

## Figure 5: Chemogenetic activation of VSNs alters sleep architecture
- Standard architectural analysis of vigilance state files scored in 4-s epochs.

## Figure 6: Chemogenetic activation of VSNs preserves homeostatic regulation
- Standard architectural analysis of vigilance state files scored in 4-s epochs.

## Figure 7: Chemogenetic VSN stimulation induces transient brain-body temperature decrease
- Temperature values calculated using `f_corticaltemperature.m` with PSA containing measured voltages and beta value.
- Max temperature drop calculated via `f_drop_temperature(b, t_temp).m`.
- Drop at first REM sleep episode calculated via `f_temp_recoveryREMS.m`.

## Figure 8: Antagonizing VSN stimulation-induced cooling by ambient warming
- Calculations as described for Figures 4 and 7.
