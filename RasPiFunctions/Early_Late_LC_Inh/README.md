# RasPi functions for led triggering

This software is used in combination with Ypnos software for triggering of leds for optogenetic experiments as the ones described in  https://doi.org/10.1101/2023.05.20.541586.

In the laboratory we are using RasPi of the type described here https://www.raspberrypi.com/products/raspberry-pi-4-model-b/.

![RaspberryPi4_PB_02](https://github.com/luthilab/IntanLuthiLab/assets/120734447/e2489b12-05f6-49a4-9a7a-151e911ba261)


## Wiring up

The digital outputs of the Intan board used by Ypnos are fed to the RasPi inputs defined in:

```
inREM = [5,13,19,26] 
inNREM = [25,24,23,22]
```
for each of the 4 animals we are usually recording simultaneously and with each of the input corresponds to the detection of REM and NREM states dictated by Ypnos (see section for the Ypnos for closed loop experiments).

depending on the calculation performed by those codes the outpouts of the RasPi defined in: 

```
out = [12,16,20,21]
```

will be ON triggering the LEDs. In addition, a copy of those triggering signals are fed back to the Intan analog inputs. Each of two files permit to trigger the LEDs for the inactivation of the  locus coeruleus after a REM episode longer than 120s, in the permissive (late) or the refractory (early) period as described in 
 https://doi.org/10.1101/2023.05.20.541586 and https://pubmed.ncbi.nlm.nih.gov/34432801/ . For questions regarding the code computations please contact the members of the Prof. Anita Lüthi laboratory.
