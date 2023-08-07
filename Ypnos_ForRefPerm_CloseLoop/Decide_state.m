% The last 4 seconds + the current second of EEG data are represented as a
% logical vector of 5 points.
% 1 is when the ratio del/the is above the threshold
% 0 is when it is below.
% Example : [1,1,1,0,0] means that during the previous and the current
% second, the ratio went below the threshold.
% Emg data is the same with 1 when it is above (active) and 0 when it is
% below (inactive)
% The choice to change state first depend on the current state of the
% panel. That's the role of the switch case. 1 is wake, 2 is nrem and 3 is
% rem.

% if it is 1 (in wake) the only state it can change to is 2 (nrem). The
% condition to switch to nrem is that the last 3 points of emg are at 0 and
% that the sum of the last 4 points of ratio is at least 3.
% Example : ratio = [0,0,1,0,1] and emg = [1,1,0,0,0] would switch state to
% nrem.

% If it is 2 (nrem) the panel can switch either to wake or rem. To switch
% to wake the last two points of emg need to be 1: [0,0,0,1,1].
% To switch to rem, the emg needs to be 0 (low) for all the points and the
% ratio also needs to be low for all the points : emg[0,0,0,0,0],
% ratio[0,0,0,0,0].

% if it is 3 (rem) it can either go to wake or back to NREM. The latter
% transition is unusual but necessary since very short wake after rem might
% not be detected before going back to nrem.
% To switch to wake the last two points of emg need to be 1: [0,0,0,1,1].
% To switch to nrem the ratio must be high for four out of the five points.

r = obj.delTheLine.YData > 1; % 1 if it's above
m = obj.emgValLine.YData > 0.45; % 1 if it's high
switch obj.curentState
    case 1 % wake - the animal is in wake and goes to nrem
        if sum(m(3:5)) == 0 && sum(r(4:5)) >= 3 
            obj.curentState = 2;
            updateState(2)
        end
    case 2 % nrem - the animal is in nrem and goes to wake or rem
        if sum(m(4:5)) == 2 
            obj.curentState = 1;
            updateState(1)
        elseif sum(m) == 0 && sum(r) == 0 % attention sum(r) == 0 is a very strict condition
            obj.curentState = 3;
            updateState(3)
        end
    case 3 % rem - the animal is in rem and goes to wake or nrem
        if sum(m(4:5)) == 2 
            obj.curentState = 1;
            updateState(1)
        elseif sum(r) >= 4 
            obj.curentState = 2;
            updateState(2)
        end
end