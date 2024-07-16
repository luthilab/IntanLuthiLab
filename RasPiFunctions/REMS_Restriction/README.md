# RasPi functions for REMS restriction 

This software is used in combination with Ypnos software for REMS restriction experiments described  https://doi.org/10.1101/2023.05.20.541586.

In the laboratory we are using RasPi of the type described here https://www.raspberrypi.com/products/raspberry-pi-4-model-b/.

![RaspberryPi4_PB_02](https://github.com/luthilab/IntanLuthiLab/assets/120734447/e2489b12-05f6-49a4-9a7a-151e911ba261)

In order to wake up the animal every time REMS is detected a vibrating motor is attached (using a double-sided tape) on the headstage of the animal. 

<img width="659" alt="REMSD" src="https://github.com/user-attachments/assets/7b73a244-667c-4adf-a4ed-4377709f2fc1">


The motors we are using in the laboratory is of this kind:

https://www.amazon.com/BestTong-Vibration-Button-Type-Vibrating-Appliances/dp/B071WYG59X

and they are directly triggered by the output (0 to 3.3V) of the RasPi. 

## Wiring up

The digital outputs of the Intan board used by Ypnos are fed to the RasPi inputs defined in:

```
inREM = [5,13,19,26] 
inNREM = [25,24,23,22]
```
for each of the 4 animals we are usually recording simultaneously and with each of the input corresponds to the detection of REM and NREM states dictated by Ypnos in a closed-loop manner (see section for the Ypnos for closed loop experiments).

depending on the calculation performed by those codes the outpouts of the RasPi defined in: 

```
out = [12,16,20,21]
```

will be ON triggering the LEDs. In addition, a copy of those triggering signals are fed back to the Intan analog inputs. Each of two files permit to trigger the LEDs for the inactivation of the  locus coeruleus after a REM episode longer than 120s, in the permissive (late) or the refractory (early) period as described in 
 https://doi.org/10.1101/2023.05.20.541586 and https://pubmed.ncbi.nlm.nih.gov/34432801/ . For questions regarding the code computations please contact the members of the Prof. Anita Lüthi laboratory.
