# Symply2Read

As it's name imply, this software is simply to read and records the data from the Intan setup.

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
In the file you can find examples and ways to get special channels such as:

Analog channels from the **INTAN USB MAIN BOARD**:

indicate them as string ```'1','2','3'``` etc...

To get the data from the accelerometer if available, add ```'xyz'``` (this will add three more channel).

if you have a different configuration per animals, indicate each like this:

```
conf.Lila = struct('A1', {{24, 21, 19, 15, 11, '1'}},... 
    'A2', {{24, 15, 23, 19, 9, 13, '2'}},... 
    'A3', {{24, 21, 19, 13, 11, 17, '3'}},... 
    'A4', {{24, 21, 19, 13, 11, 17, '4'}});
```
    
If you want to **DISPLAY** one channel from the referencing of one to another, for example you have two EMGs 
and two EEGs and you want to see the differentials, you can put them as a vector in the configuration like this:

```
conf.AO_S1x2 = {[24, 15], [13, 11]};
```

The display will show two channels from the differentials of INTAN channels 23 to 14 and 12 to 10. However, you'll 
get the 4 channels idivudually in the recorded file.

Once you have done these steps, your configuration will appear in the droplist at the moment of setting up your recording.

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

