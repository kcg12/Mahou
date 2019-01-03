function bins = timeFsToBin(time, zero_bin)
% Convert time in ps to bins (units of HeNe fringes)

global fringeToFs CONSTANTS
bins = round(time/CONSTANTS.fringeToFs) + zero_bin;
