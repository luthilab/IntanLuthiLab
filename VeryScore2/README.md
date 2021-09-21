# VeryScore2

This software allows you to score the data in 4 second epochs.

Simply launch the VS2_main and import a file obtained with Simply2Read in the "File" menu.
The files should be named like this:

AnimalName_recordingNumber_condition_t.mat

Your raw traces now appear.

It is advised at this step to give names to your traces, especially if you have more than 2. To do so, you need to go into:

File > Edit file Infos

There you should choose to create a "New" field.

The new field name SHOULD be: Channel
now in the Field content put the trace labels between commas such as: EEG, EMG, S1, CA1
You can name them whatever.

Now go to:

Tools > Reload Names from Infos

You should see the names on the right of the traces.

Before Scoring:

You can select the traces by clicking on them. The selected ones are orange.

Once selected, you can filter the trace(s) in the menu Traces > Filter traces

If your EMG or EEG is composed of two traces, you can "bipolarize" them to get the difference betweem the two.

Select two traces > Traces > Bipolarize

This simulates a referencing of one to the other.

To use the autoscoring, you should first filter the EEG over 0.75 Hz and the EMG over 25 Hz.

Select both EEG and EMG > Tools > Auto-Scoring


# Moving around and scoring

Left: a
right: d
next transition to the left: left arrow
next transition to the right: right arrow

increase gain of all traces: up arrow (when none selected or of the selected traces only)
decrease gain of all traces: down arrow (when none selected or of the selected traces only)

NREM epoch: n
WAKE epoch: w
REM epoch: r

NREM artifact: 2
WAKE artifact: 1
REM artifact: 3

Microarousal: m
Whatever purple epoch: f

# Advanced functions

File >
Import
Import randomly
Save
Edit file Infos
Reduce file size
Rename files

Tools >
Auto-Scoring
Reload Names from Infos
Take a snapshot

Traces >
Lock YLim
Filter traces
Bipolarize
Change gain * 1000
Notch
Supress selected traces
Swap traces positions
Reverse gain and filter
Reverse all changes

Width >
This menu allows to change the view window to zoom in or out on the x-axis. I prefer to score in 40 s-windows, Alejo prefers in 32 s-windows for example.
