# RasPi functions for LC optogenetic manipulation in relation to the phase of sigma power

This software is used in combination with Ypnos software for the optogenetic experiments described in https://doi.org/10.1101/2023.05.20.541586. These function are used in conjuction with the Adonis closed-loop system found in the "Adonis" folder.

In the laboratory we are using RasPi of the type described here https://www.raspberrypi.com/products/raspberry-pi-4-model-b/.

![RaspberryPi4_PB_02](https://github.com/luthilab/IntanLuthiLab/assets/120734447/e2489b12-05f6-49a4-9a7a-151e911ba261)

For optogenetic modulation of the LC, we drive the LEDs using the functions InhCon_20m40m (Optogenetic inhibition) and Stm1Hz_30ms_10sWait_20m40m (Optogenetic stimulation). The functions are activated during the first 20 min of each hour of the Raspberry clock time.
