# Changelog

## VeryScore3 3.1 (2026-10-30)

The additions of Wenjie (October 2026, written with Codex as a separate "synchronized review" program,
`VS3_review`) brought into the main window of VeryScore3 instead (Alejandro Osorio-Forero, with Claude).
The separate program is not part of VeryScore3; its video, timing and sensor functions are.

- Tools > Video (`VS3_videoPanel`, `VS3_video`): the Raspberry Pi camera and the thermal video in a column
  right of the traces, shown when a video is opened and gone when the last one is closed. The frame at the
  start of the epoch follows every move of the main window; Play 4 s (or the space bar) plays the epoch with
  a line running over the traces. Views: Pi camera, thermal, one above the other, or the thermal image over
  the camera (warm parts opaque, opacity slider), aligned with points clicked in both videos.
  - Pi frames found by the times of their `.timestamps.csv` (variable frame rate stays exact), the
    `.ravi` read directly (hardware frame counter, start time, shutter frames), or the `.h5` of the thermal tool.
  - Offsets as for the temperature (video time at EEG sample 1), from the start times of the recordings
    (Pi: UTC of its first frame against `Infos.StartTimePosix`), the temperature analysis, or typed.
  - Load recorder timing folder (`VS3_videoTiming`): per-frame clock maps of the recorder (camera clock
    observations, EEG sample of every thermal frame) instead of the offset; unmapped frames are not shown.
  - Estimate Pi offset from the movement and Align thermal on Pi from the movement (`VS3_videoMotion`): the
    animal starting to walk in both videos gives the delay of the Pi video; its places in both videos while
    it walks give the place, scale and rotation thermal -> Pi (RANSAC). On the overnight recording of
    2026-10-28 the Pi video was 2 s late on its start time, and the thermal image had to be enlarged about
    3.5 times and turned by 180 degrees.
  - Thermal frames of the `.ravi` timed from the camera counter of one frame in about 1400 (opening in under
    1 s on a network drive instead of 1.5 min); the shutter state of a frame is read with the frame.
  - ROIs on either video: movement (dx, dy, tracked by correlation) and brightness, or thermal mean, for
    every frame of the epoch, drawn under the videos with the spectrum of one of them. MATLAB only.
  - Save stores the videos, offsets, view, alignment and ROIs as `Video`; they are reopened at loading.
  - `VS3_main(file, 'pi', video, 'thermal', video)` opens a file and its videos from a script.
- Tools > Sensor data and File > Sensor CSV files to one H5 (`VS3_sensorConvert`, `VS3_sensorTool`,
  `VS3_sensorView`, by Wenjie): the Pi sensor compared with the EEG / EMG traces as displayed, respiration and
  heart candidates of every 4-s epoch over the recording and the epoch in detail, following the main window;
  stored as `Sensor`. Tools > Sensor data > Import sensor CSV takes the CSV of the sensor: it is read once into
  an `.h5` next to the EEG file, used again at the next import (an `.h5` used to be needed first).
- File > Convert Open Ephys recording: any folder of a recording (down to the stream folder) finds it; lists
  to choose the recordings and the channels; recordings already converted are skipped or converted again on
  request; option `'channels'`; `Infos.ConvertedChannels`.
- Open Ephys acquisition board files: every trace centred in its slot on screen (display only). Files whose
  `Infos.Channel` lists more channels than they hold are named from `traceName`.
- File > Import and the video, sensor and timing dialogs start in the folder used last for that kind of
  file (`VS3_fileHistory`).
- Tools > Reload Names from Infos shows the names typed in `Infos.Channel` (File > Edit file Infos) also
  for files converted from Open Ephys: their recorded names (`traceName`) won before, so the names typed
  were never shown. File > Edit file Infos > New: Cancel no longer gives an error.
- Sensor comparison: cancelling the calculation of the trends showed an error instead of the partial trends.
- Tools > Summary figure: the breathing (per min) of the Pi sensor and the one seen by Pi ROIs of the video
  (one epoch per minute, coloured by state), the heart rate of the sensor, and, without a Thermal analysis,
  the temperature of the warm spot of the thermal video. The video signals are measured once (asked
  first, with the time it takes) and saved with the video settings (`Video.breathing`, `Video.warmSpot`).
  `VS3_videoPanel.roiBreathing`; `VS3_videoMotion('warmSpot')` also gives the temperature of the spot.
- `tutorial/README.md`: VeryScore3 step by step for students and new users, with figures of a real
  recording, and a video tour (`VS3_tour.mp4`, in the releases of the repository) filmed in the program.
- Tests in `tests/` (synthetic data): `test_video` (Pi video, .h5, .ravi, column, playback, ROI, recorder
  timing maps), `test_videoMotion` (a walking animal in both videos, known delay and transform),
  `test_openEphys`, `test_sensor` (by Wenjie), `test_summary` (sensor, video breathing and warm-spot panels). Checked on the overnight recording of 2026-10-28.
  `alignOverlay(xyPi, xyThermal)` aligns from a script.

## VeryScore3 3.0 (2026-10)

VeryScore2 1.6, 1.7 and 1.8 (below) brought together in one program, with every file renamed `VS3_*`
(Alejandro Osorio-Forero, with Claude). Files are the same as in VeryScore2, in both directions.

- `VS3_main` starts the program; `VS3_display`, `VS3_tracesPlot`, `VS3_autoScoreTool`, `VS3_thermalTool`,
  `VS3_photometry`, `VS3_convertOpenEphys`, `VS3_summary`, `VS3_logo`, `VS3_autoScoreClassic` (the VeryScore2 autoscoring) and `VS3_pref`.
- File > Convert Open Ephys recording (`VS3_convertOpenEphys`): the converter used until now (`ToVS2_2026`)
  in VeryScore3, with the same output (checked on 14 recordings), folders asked and remembered, its own `.npy`
  reader (no npy-matlab), and the converted file opened on request.
- Tools > Summary figure (`VS3_summary`): hypnogram, sigma activity (10-15 Hz, % of the NREM mean), temperature
  and photometry of the whole recording; on the right the clock times, a ring of the time in each state, box
  plots of the bout durations and the states hour by hour; clicking navigates the main window.
  Saved as .fig (the panels stay zoomed together when it is opened again, without VeryScore3) and .png.
- File > Export displayed traces (.mat): the traces as displayed (filters, notches, bipolar, photometry dF/F; order
  of the screen, suppressed traces left out) saved in a new file at 200 Hz, in the units of the recording (display
  gain and loading scaling undone, dF/F in %), with the channel names (asked), `Infos.Fs`, `Infos.StartTime` and
  what was done to each trace (`traceProcessing`). The scored file is never overwritten.
- The VeryScore3 logo (`images/`, `VS3_logo`): start screen of the main window, progress windows of every tool,
  Help > About VeryScore3 (credits and repositories), summary figure.
- Photometry display: the dF/F is scaled from its typical spread within one minute (five times taller than in
  VeryScore2 1.7 on an 8-h recording) and centred in its trace slot on every screen.
- Preferences are stored in the group `VeryScore3`; the ones set in VeryScore2 1.6-1.8 (python.exe, folders,
  photometry and auto-scoring choices) are taken over automatically.
- Auto-scoring library: the shipped recordings (`autoscore/VS3_autoLibrary.mat`) are never modified; your own
  recordings go to `autoscore/VS3_autoLibrary_local.mat` (ignored by git).
- Fixes of VeryScore2 behaviour:
  - Save: a file whose name ended in `t.mat` without underscore lost characters (`AH2_test.mat` became
    `AH2_te_bt.mat`); now `name_t.mat` and `name.mat` both become `name_bt.mat`.
  - Import randomly no longer needs the Statistics toolbox (`randperm` instead of `datasample`).
  - Rename files to bt refused every correctly named file (`sep ~= 7` instead of `numel(sep) ~= 7`) and failed
    when a single file was selected.
  - `ReduceBTfileSize.m`, called by File > Reduce file size, is now part of the folder.
  - In blind mode (Import randomly) the auto-scoring, photometry and thermal messages do not show the file name.
  - Reverse all changes dropped the transitions placed by hand, so the next Save wrote NaN into `bTrans`; it
    also showed a hidden temperature panel again.
  - Clicking the hypnogram left of 4 s or after the last epoch gave an error, and a click went one epoch too early.
  - Closing the Filter traces or Notch dialog without choosing gave an error.
- Thermal video (after a review of v1.6/1.8):
  - Parallel workers re-open the video when it changed (calibration added, converted again); before, they could
    return the old uncalibrated values labelled degC.
  - The hypnogram keeps the time range of the recording when the temperature panel is shown (a longer video or a
    large offset squeezed it).
  - A new analysis uses `Infos.StartTime` instead of the offset of the previous analysis, unless that offset was
    typed or estimated by you. Start times: fixed priority (StartTime first), a date alone is not used, a start
    time more than 12 h away from the video is ignored.
  - Serial run when the parallel pool cannot start; the workers' own error messages are shown; ROI functions of
    your own work on the pool.
  - The movement estimate reads the hot-spot position of each ROI method (hottestBlob gave nonsense), is not
    offered below a correlation of 0.3, and tells how flat it is and how precise the timestamps are.
  - hottestBlob's 3 K threshold is converted to counts on uncalibrated videos.
  - New ROI methods from the Thermal project (2026-10-02): `shavedPatch` (the shaved skin, segmented inside the
    animal) and `mouseBody` (the whole animal), sharing `mouseMask`, with motion censoring
    (`thermal_motion_censor`, options `motionCensor` and `speedThr`) applied to them by default. Only the
    temperatures are filled over the censored frames; the position and area columns keep their measured values
    (option `keepCols`), so that the movement estimate of the offset works with these methods too (it gave
    nonsense when the positions were interpolated).
  - ROI method names and N are checked; the scoring file must be writable before the long extraction, and a
    failed save keeps the result; a camera calibration of another camera is refused before it is applied;
    temporary logs are deleted; the offset source is recorded correctly; VS3 always uses its own thermal code.
- Photometry (after a review of v1.7):
  - NaN samples (a few are interpolated, many are refused), flat channels, too short recordings for the
    exponential baseline (< 20 min after the skipped start) and a zero baseline give clear messages.
  - The fast bleaching time constant cannot be shorter than a third of the skipped start (its extrapolation to
    the start exploded); a warning when a fitted time constant sits at its limit.
  - The display scale comes from the fitted part; extreme extrapolated values are clipped on screen only.
  - One photometry channel per file: computing another one asks first and restores the raw trace of the first.
  - A purple carrier above the Nyquist frequency counts as no purple LED; int16 traces, BitVolts as text or as
    one value; the skipped time is remembered; a failed save keeps the result on screen; less memory at high
    sampling rates.

## VeryScore2 1.8 (2026-10-01)

- New auto-scoring (Tools > Auto-Scoring > Score this file): EEG band powers and EMG above 30 Hz per 4-s epoch,
  a linear discriminant model trained on a library of manually scored recordings, vetoed by the bimodal muscle
  tone, then adapted to the recording; uncertain epochs left unscored for review. 90-93 % agreement with a
  human scorer on recordings left out of the library (VeryScore1 autoscoring: 57-79 %).
- Tools > Auto-Scoring > Add this scoring to the library / Library contents.
- shift+b jumps to the next unscored epoch.
- The VeryScore1 autoscoring stays as Classic auto-scoring.

## VeryScore2 1.7 (2026-10-01)

- Tools > Photometry: dF/F of the selected trace (raw LED-modulated photometry channel) read at full rate from the
  file; lock-in demodulation of the 465 nm and 405 nm carriers; baseline from the purple signal or from a
  double-exponential bleaching fit; stored as `Photometry` and shown at loading; overview figure.

## VeryScore2 1.6 (2026-09)

- Tools > Thermal video: temperature of the animal from an Optris `.ravi` video (conversion to `.h5` with Python,
  ROI methods, alignment to the EEG by offset, start times or movement), stored as `Thermal`, shown in a panel
  above the hypnogram. Faster ROI extraction and parallel workers (2026-10-01).
- File > Edit file Infos works with files without the Intan `Configuration` field (Open Ephys).

## VeryScore2 1.5 and before (Lüthi lab)

- See the header of `VS3_main.m` and the history of `VeryScore2_For_Sleep_Scoring` in this repository
  (Romain Cardis 2018-2021, Georgios Foustoukos 2023-2024).
