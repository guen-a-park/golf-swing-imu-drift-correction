function p = runsRoot()
%RUNSROOT Root folder holding the trained-model run directories.
%   Set the GOLF_RUNS_ROOT environment variable, or edit the fallback below.
%   Each run directory is produced by src/model/traj_ml_withtraj_matrevised_3d_1216.py
%   and is named runs_<date>_<configuration>.
p = getenv('GOLF_RUNS_ROOT');
if isempty(p)
    p = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'runs');
end
end
