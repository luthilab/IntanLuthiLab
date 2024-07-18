# Detection of LC peaks and LC activity surges

The functions f_ActivitySourges is a detiled summary of all the procedures used for the peak detection of LC activity during NREM sleep, the surges around microarousal (MA) and the description of the surges. It also includes the study of brain and body features around these surges. This analysis is used in https://doi.org/10.1101/2023.05.20.541586.

The overal description is presented in the following figure (Supp. Figure 2 in https://doi.org/10.1101/2023.05.20.541586).

![Figures_ALL_0322_ALLFIGS_supplementary_fig2](https://github.com/user-attachments/assets/0489acc4-b05c-4bb0-8971-ead997399b72)

The detailed description of the algorithms are documented inside the f_ActivitySourges function which was also commented at each of the analysis blocks.

The subfunctions p_GetTau, f_GetPeaks and f_GetPeakInfo, are included in the same script and contain their own README. 

The functions f_ElimMA, f_b2Vec, f_MGT and f_baselineCalculation are also included in the folder and are necessary for the script to work.



