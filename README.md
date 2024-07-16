# IntanLuthiLab

Welcome to the IntanLuthiLab repository.

This repository belongs to the laboratory of Prof. Anita Lüthi, Department of Fundamental Neurosciences, Faculty of Biology and Medicine, University of Lausanne, Switzerland.

https://dnf-unil.ch/group/gaining-insight-into-the-roles-of-sleep-for-neuronal-function

We share openly here the softwares developed in our lab for recording and scoring electrophysiology data with the Intan recording system. Our hardware setup contains the following parts from IntanTech (https://intantech.com/):

- C3100 RHD USB interface board
- C3211 RHD 1-ft (0.3 m) ultra thin SPI interface cable
- C3314 RHD 32-channel headstage
- C3334 RHD 16-channel headstage

The three softwares proposed here are:

**Symply2Read**

Used for recording up to 8 animals at a time for long periods.

**VeryScore2**

Used to open, visualize and score the data in three main vigilent state (NREMS, REMS, Wakefulness) obtained with Symply2Read.

**Ypnos_For_Closed_Loop_Experiments**

Used for recording data and automatic detection of the three vigilent states (NREMS, REMS, Wakefulness) using the EMG and EEG signals. This version is related to the experiments conducted in the https://doi.org/10.1101/2023.05.20.541586 paper.

**Example of an analysis**

This is a little example of the architecture for an analysis on these **bt.mat** files. We provide as well some useful analysis and ease of life functions that we wrote and use in the lab. The analysis and the functions are normally documented and commented to understand their purpose.

_Romain Cardis 2021_

## Citation:

*If you use these softwares and publish work using them, thank you for citing us in your methods.*

Our papers in which we used these tools:

**Thalamic reticular control of local sleep in mouse sensory cortex (2018)**

https://pubmed.ncbi.nlm.nih.gov/30583750/

**Cortico-autonomic local arousals and heightened somatosensory arousability during NREMS of mice in neuropathic pain (2021)**

https://pubmed.ncbi.nlm.nih.gov/34227936/

**Noradrenergic circuit control of non-REM sleep substates (2021)**

https://pubmed.ncbi.nlm.nih.gov/34648731/

**Noradrenergic locus coeruleus activity functionally partitions NREM sleep to gatekeep the NREM-REM sleep cycle (2024)**

https://doi.org/10.1101/2023.05.20.541586



