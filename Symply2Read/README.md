Symply2Read

As it's name imply, this software is simply to read and record the data from the Intan setup.

The utilisation of the software itself is straightforward. The only "complicated" part is the creation of new recording configuration.

This is done in the getConf.m file which acts as a memory for the configurations. There are already a few as examples.

To create a new recording configuration, follow these steps:

Locate the Intan channels you want to save in the file.

16 channel bipolar:

![image](https://user-images.githubusercontent.com/58259490/132471190-23b98caa-3847-404d-b8d7-799f43b01e23.png)

32 channel unipolar:

![image](https://user-images.githubusercontent.com/58259490/132471297-f16f5c7e-35bd-4d35-b9e0-3679d4d30373.png)

In the lab, we are using omnetics to 10 pin strip homemade adapter that are connected like this:

![image](https://user-images.githubusercontent.com/58259490/132471747-7655dc29-859c-4976-976a-c1a60160c2dc.png)

(see how we ground the other channels and connect them to the REF pin which receive the signal from the bone over the cerebellum.
This is the best way we found to reduce the noise in the signal.)


In the getConf.m file, this corresponds to the pin10 configuration

Whitin the getConf.m file:

First, mannually add the name of your configuration in the conf.confList cell array.

Second, add your configuration as a field of the structure conf. It is MANDATORY that they are written in the same order as they appear
in the conf.confList cell array.

Prepare your configuration as follow:
For our configuration we needed to record the INTAN channels: 23, 22, 20, 18, 16, 14, 12, 10, 8
Matlab indexing start with 1 so you NEED to add 1 to the channel indexes.

The final configuration is thus:

conf.Pin10 = {24, 23, 21, 19, 17, 15, 13, 11, 9};

In the file you can find examples and ways to get special channel such as:

Analog channels from the INTAN MAIN BOARD:
indicate them as string '1','2','3' etc...

To get the data from the accelerometer if available, add 'xyz' (will add three more channel)

if you have a different configuration per animals, indicate each like this:

conf.Lila = struct('A1',{{24,21,19,15,11}},... % ref,EMG,EEF,EEP,EMG JB5
    'A2',{{24,15,23,19,9,13}},... % ref,EMG,EEF,EEP,EMG, A1 JB6
    'A3',{{24,21,19,13,11,17}},... %ref,EMG,EEF,EEP,EMG, A1
    'A4',{{24,21,19,13,11,17}});
    
If you want to DISPLAY one channel from the referencing of one to another, for example you have two EMGs 
and two EEGs and you want to see the differentials, you can put them as a vector in the configuration like this:

conf.AO_S1x2 = {[24, 15], [13, 11]};

The display will show two channels from the differentials of INTAN channels 23 to 14 and 12 to 10. However, you'll 
get the 4 channels idivudually in the recorded file.

Once you have done these steps, your configuration will appear in the droplist at the moment of setting up your recording.

The steps from launching the soft to launching the recordings should be straightforward. If you have any problem, feel free to
post a request on this Github.

Thanks and good science to y'all!

