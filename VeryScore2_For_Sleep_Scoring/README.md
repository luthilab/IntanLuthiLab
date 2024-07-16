# VeryScore2

This software allows you to score the data in 4 second epochs.

Simply launch the VS2_main and import a file obtained with Simply2Read in the "File" menu.
The files should be named like this:

AnimalName_recordingNumber_condition_t.mat

Your raw traces now appear.

**Important notice: All the display changes you will do on the traces, such as filters, gain changes or supressing traces are not saved in the file. The only thing saved is the b string containing your scoring. This means you should not be afraid to make display changes to ease your scoring.**

**Second notice: In the lab we are using super nintendo USB controllers to score. Coupled with a small software such as JoyToKey, you can score much faster and more confortably (https://joytokey.net/en/). We provide a configuration for JoyToKey that is prepared for super nintendo controllers in the VeryScore2 folder.**



## Naming your traces
It is advised at this step to give names to your traces, especially if you have more than 2. To do so, you need to go into:

File > Edit file Infos

There you should choose to create a **New** field.

The new field name SHOULD be: **Channel**
now in the Field content put the trace labels between commas such as: EEG, EMG, S1, CA1
You can name them whatever.

Now go to:

**Tools > Reload Names from Infos**

You should see the names on the right of the traces.

Before Scoring:

You can select the traces by clicking on them. The selected ones are orange.

Once selected, you can filter the trace(s) in the menu **Traces > Filter traces**

If your EMG or EEG is composed of two traces, you can "bipolarize" them to get the difference betweem the two.

Select two traces > **Traces > Bipolarize**

This simulates a referencing of one to the other.

To use the autoscoring, you should first filter the EEG over 0.75 Hz and the EMG over 25 Hz.

Select both EEG and EMG > **Tools > Auto-Scoring**

You can now correct the autoscoring which is **not perfect**. It is just faster to correct than to score from scratch.

The blue epochs are _unknown_ and represent potential changes during long NREMS sleep bouts. This is oversensitive on purpose and allows not to miss any events such as microarousals. You can safely jump from transition to transition using the arrows and assign them correctly.


## Moving around and scoring

Left: **a**

right: **d**

next transition to the left: **left arrow**

next transition to the right: **right arrow**

increase gain of all traces: **up arrow** (when none selected or of the selected traces only)

decrease gain of all traces: **down arrow** (when none selected or of the selected traces only)

WAKE epoch: **w**

NREM epoch: **n**

REM epoch: **r**

WAKE artifact: **1**

NREM artifact: **2**

REM artifact: **3**

Microarousal: **m**

Whatever purple epoch: **f**

Moving the selected trace up and down in position: **shift+arrow**



## Advanced functions

**File >**

**Import:** Let you import a new file.

**Import randomly:** Let you select multiple files and give them for you to score in a random order without knowing which one. This is very useful in case you need to score your files in a blind manner. We are all subjected to treatment biases so doing this removes this concern.

**Save:** Save your current scoring. The file will then receive a **b** in its name to show that is contains scoring data. If you load that file again, the saved scoring will appear.

**Edit file Infos:** This allows you to add field to the Infos structure contained in the file. You can precise treatments, important time points, or whatever you would like to use for future analysis with this file. Like mentionned above, you can create the field **Channel** to add names to your traces. An idea is to put the name of the person that did the scoring.

**Reduce file size:** We noticed that loading the whole file and saving it again all in one shot sometimes reduces the file size. If size is a problem for you, you can try this function once you have a file loaded.

**Rename files:** function to come

**Tools >**

**Auto-Scoring:** The autoscoring. To use whith EEG and EMG selected and filtered. The autoscoring is not perfect, but represents a way to greatly reduce the time to score on file. Once the autoscoring is done, you should move from transition to transition with the arrows and correct manually the scoring.

**Reload Names from Infos:** Once the field **Channel** exists in Infos and contains the trace names, you can load the names for them to appear on the chart.

**Take a snapshot:** It takes a snapshot of the current window, essentially reploting the current view in a new figure. You can then save the figure to keep track of your nicest spindles or show irregularities to your collegues.

**Traces >**

**Lock YLim:** The Y-limit of the chart is dynamically updated to see all the traces. While scoring, you sometimes have big artifacts that would mess up the view. You can lock the YLim for it not to move. It is then more confortable to score.

**Filter traces:** Allows to apply filters to selected traces. Three filters are available: >0.75 Hz, >25 Hz, <25 Hz. We typically filter >75 Hz for EEGs and LFPs and >25 Hz for EMGs.

**Bipolarize:** Create a new trace from the difference of two selected traces. You can choose to keep the two original or not.

**Change gain * 1000:** This allows to change the gain massively, instead of using the arrows up and down.

**Notch:** Apply a notch on the selected traces. You can use 50 hz or 60 hz notches. We record our animal within faraday cages so we usually don't require notches.

**Supress selected traces:** If a specific trace in not needed for your scoring, or you want to not see a stimulation trace, you can select it and supress it from the display. The trace will still exist in the file and would appear if you load it again.

**Swap traces positions:** Select two traces and swap their position on the display. This change will not affect the ordering of the channel within the file. This is for display purpose only.

**Reverse gain and filter:** If a trace is unreadable due to a false manipulation or if you want to reset it to raw data, you can reverse the changes made to it.

**Reverse all changes:** Returns the display of the traces to the original state at the moment of loading the file. This will not affect your scoring, it reverses only the display.

**Width >**

This menu allows to change the view window to zoom in or out on the x-axis. I prefer to score in 40 s-windows, Alejo prefers in 32 s-windows for example.


**In the name of the Lüthi lab, we wish you a good scoring!** 
