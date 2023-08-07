# RasPi functions for led triggering

This software is used in combination with Ypnos software for triggering of leds for optogenetic experiments as the ones described in https://www.biorxiv.org/content/10.1101/2023.05.20.541586v1.

In the laboratory we are using RasPi of the type described here https://www.raspberrypi.com/products/raspberry-pi-4-model-b/.


## Wiring up

The digital outputs of the Intan board used by Ypnos are fed to the RasPi inputs defined in 

```
inREM = [5,13,19,26] 
inNREM = [25,24,23,22]
```
for each of the 4 animals we are usually recording simultaneously.

depending on the calculation performed by those codes the outpouts of the RasPi defined in 

```
out = [12,16,20,21]
```

will be ON triggering the LEDs. In addition, a copy of those triggering signals are fed back to the Intan analog inputs. 