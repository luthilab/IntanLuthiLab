# Detection of LC peaks and LC activity surges

The functions **f_ActivitySourges** is a detailed summary of all the MATLAB-based algorithms used for the peak detection of LC activity during NREM sleep, the surges around microarousal (MA) and the description of the surges. It also includes the study of brain and body features around these surges. This analysis is used in https://doi.org/10.1038/s41593-024-01822-0.

The overal description is presented in the following figure (Supp. Figure 2 in https://doi.org/10.1038/s41593-024-01822-0).

![Figures_ALL_0516_ALLFIGS_extended_data_fig2](https://github.com/user-attachments/assets/37e79c45-1665-4638-9839-ea9c8bb094f2)

The detailed description of the algorithms are documented inside the f_ActivitySourges function which was also commented at each of the analysis blocks.

The subfunctions **p_GetTau**, **f_GetPeaks** and **f_GetPeakInfo**, are included in the same script and contain their own README. 

The functions **f_ElimMA**, **f_b2Vec**, **f_MGT** and **f_baselineCalculation** are also included in the folder and are necessary for the script to work.

For questions regarding the code computations please contact the members of the Prof. Anita Lüthi laboratory.



