# Ypnos for closed-loop detection of sleep states using EEG/EMG electrodes

This software is simultaneously recording the data from the Intan setup and using the EEG and EMG data it detects three discrete sleep states (NREM,REM, Wake).

The present version of the code together with the functions in the RasPiFunctions folder is used to detect REM episodes (longer than 120s) and trigger leds for the inactivation of the locus coeruleus as described in the 
https://www.biorxiv.org/content/10.1101/2023.05.20.541586v1 (Figure 3).

To make it work, you need to have the Matlab Intan toolbox installed correctly and accessible through the path.

Follow the instructions from Intan:

https://intantech.com/files/Intan_RHD2000_MATLAB_toolbox.pdf

For info, we found that the toolbox works best with the C++ interpreter of Visual studio 2015.


## Creating new recording configurations

This is done in the getConf.m file which acts as a memory for the configurations. There are already a few as examples.

To create a new recording configuration, follow these steps:

Locate the Intan channels you want to save in the file.

**16 channel bipolar:**

![image](https://user-images.githubusercontent.com/58259490/132471190-23b98caa-3847-404d-b8d7-799f43b01e23.png)

**32 channel unipolar:**

![image](https://user-images.githubusercontent.com/58259490/132471297-f16f5c7e-35bd-4d35-b9e0-3679d4d30373.png)

In the lab, we are using omnetics to 10 pin strip homemade adapters that are connected like this:

![image](https://user-images.githubusercontent.com/58259490/132471747-7655dc29-859c-4976-976a-c1a60160c2dc.png)

(see how we ground the other channels and connect them to the REF pin which receive the signal from the bone over the cerebellum.
This is the best way we found to reduce the noise in the signal.)


In the **getConf.m** file, this corresponds to the pin10 configuration

**To create your own:**

Whitin the **getConf.m** file:

First, mannually add the name of your configuration in the conf.confList cell array.

Second, add your configuration as a field of the structure conf. It is **MANDATORY** that they are written in the same order as they appear
in the conf.confList cell array.

Prepare your configuration as follow:

For our configuration we needed to record the INTAN channels: **23, 22, 20, 18, 16, 14, 12, 10, 8**

Matlab indexing start with 1 so you NEED to add 1 to the channel indexes.

The final configuration is thus:
```
conf.Pin10 = {24, 23, 21, 19, 17, 15, 13, 11, 9};
```
The code is using the bipolarised EEG and EMG signals to detect the state of sleep so it is important to order your EEG and EMG signals as follows:

For example if you have two EEGs and two EMGs you can put them as a vector in the configuration like this:

```
conf.AO_S1x2 = {[24, 15], [13, 11]};
```

With this configuration, Ypnos will use the two channels from the differentials of INTAN channels 23 to 14 and 12 to 10 to perform the detection. However, you'll 
get the 4 channels idivudually in the recorded file.

Once you have done these steps, your configuration will appear in the droplist at the moment of setting up your recording.

The detection of the sleep states is based on different thresholds of delta to theta power ratios (calculated online from the EEG signals) and EMG activity, the user can set up in **Ypnos_Panel1000hz.m** lines 154-228.

## Digital output depending on the sleep state

If it is needed one can use the closed-loop detection to trigger additional devices (such as a RasPi) by changing the output of the Intan board digital outputs (0-3.3V). You can decide on which sleep state in the function **Ypnos_Main.m** at the lines 151-168:

```
for c = 1:h.nChip
	st = checkState(h.panels{c});
	stad = [st;tp];
	h.matFiles{c,i}.states(1:4,ncheck) = stad;
	% CHANGE THE STATE HERE TO HAVE TTL HIGH WHEN IT OCCURS. 1:wake, 2:NREMS, 3:REMS
	%Channels for REM and NonREM detection mod by GF   
	 switch st(1)
		 case 1 % Flag for wake
			h.board.DigitalOutputs(c+8) = 0;
			h.board.DigitalOutputs(c+12) = 0;  
		 case 3 % Flag for REM
			h.board.DigitalOutputs(c+8) = 1;
			h.board.DigitalOutputs(c+12) = 0;
		 case 2 % Flag for NonREM
			h.board.DigitalOutputs(c+8) = 0;
			h.board.DigitalOutputs(c+12) = 1;      
	 end
end
```
## Analog inputs to the Intan board 

In case you would like to add to your recordings analog inputs from the Intal card you can modify as you need the code in **Ypnos_Main.m** at the line 239:

```
toSave = [toAdd; analog(c,:)]; % add analog channel 1 for animal 1 etc...

```

This by default will save the analog 1 for the recording coming from the headstage 1 (c = 1) etc. The additional signal will be added at the end of the signals coming from the headstage and it is **not needed** to add it to your configuration (as opposed to SimplyRead).

## Naming your files
You can essentially name your file whatever you want. The soft will use the name specified by the user at the first step before the recording and add the info of which animal it belongs to.

**Example:**

You name your file: 
```
200327_superImportantRecording
```

This will result in as many files as the number of amplifier chips connected to the Intan main board, times the amount of files you specified. They will be name as follow:

**With 4 amplifier chip you will get:**
```
200327_superImportantRecording_Animal1_1.mat
200327_superImportantRecording_Animal2_1.mat
200327_superImportantRecording_Animal3_1.mat
200327_superImportantRecording_Animal4_1.mat
```

**And by asking two files of 12h each, with 4 amplifier boards plugged, you will get:**
```
200327_superImportantRecording_Animal1_1.mat
200327_superImportantRecording_Animal1_2.mat
200327_superImportantRecording_Animal2_1.mat
200327_superImportantRecording_Animal2_2.mat
200327_superImportantRecording_Animal3_1.mat
200327_superImportantRecording_Animal3_2.mat
200327_superImportantRecording_Animal4_1.mat
200327_superImportantRecording_Animal4_2.mat
```

### Efficient way of naming files:
you can use a standard way of naming your files *at this step* that allows you to use a function from VeryScore2 to rename them nicely. We strongly advise to use this naming way unless you want to spend time renaming manually after your recordings.

At this step, before the recording we name our file as:

```
date_animal1Name_animal2Name_animal3Name_animal4Name_recordingName
```

If you don't have 4 animals just put anything, like ```_x_``` At this step, the name should contain 5 underscores '''_'''.

Afterward, once you have all your files recorded, you can launch VeryScore2 and go to **file > Rename files to bt** which will rename:

This: ```200327_AN1_AN2_AN3_AN4_name_importantRecording_Animal1_1.mat```
Into: ```AN1_01_importantRecording_t.mat```

This: ```200327_AN1_AN2_AN3_AN4_name_importantRecording_Animal1_2.mat```
Into: ```AN1_02_importantRecording_t.mat```

This: ```200327_AN1_AN2_AN3_AN4_name_importantRecording_Animal2_1.mat```
Into: ```AN2_01_importantRecording_t.mat```

This: ```200327_AN1_AN2_AN3_AN4_name_importantRecording_Animal2_2.mat```
Into: ```AN2_02_importantRecording_t.mat```

etc...

The ```_t``` at the end means it contains traces. Once scored with VeryScore2, this will become ```_bt```.

## Preparing your recording

- Launch the soft and choose a destination directory by clicking on ```...```.
- Give the main name of your files. The default naming way is explained above.
- Click on ```Recording settings```
- Choose the configuration from the dropdown menu
- Choose a starting time (you can delay the start of the recording). You should keep the format style of the default date string. Our recordings start on the next day at 9am.
- Choose the duration of **each** file (we usually record 12 hours per file, but this is as you prefer).
- Choose the amount of files per animal. Here we usually record 4 files of 12 hours each per animal, effectively giving a total recording time of 48 hours.
- You can validate or decide to start the recording immediately (regardless of the starting time precised).
- Finally click on ```Start``` to launch the recording. Depending on the previous step, it will wait to start or start immediately.


Thanks and good science to y'all!

