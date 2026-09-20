function p = dataRoot()
%DATAROOT Root folder of the raw experimental data.
%   Set the GOLF_DATA_ROOT environment variable, or edit the fallback below.
%   The folder is expected to contain the subfolders imu/, mocap/ and video/,
%   each holding one directory per participant (S01 ... S10).
%
%   The dataset is not distributed with this repository; it is available from
%   the corresponding author on reasonable request.
p = getenv('GOLF_DATA_ROOT');
if isempty(p)
    p = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data');
end
end
