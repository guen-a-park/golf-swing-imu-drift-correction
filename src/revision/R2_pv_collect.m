%% R2_pv_collect.m
%  for the items where the manuscript only compared two conditions without attaching a statistical test,
%  Output : revision/results/_pv1.mat ... _pv4.mat

clc; clear; close all;

run(fullfile(fileparts(mfilename('fullpath')), 'R2_01_target_uncertainty.m'));
save(fullfile(fileparts(mfilename('fullpath')), 'results', '_pv1.mat'));

clear; close all;
run(fullfile(fileparts(mfilename('fullpath')), 'R2_02_true_distance_trajectory.m'));
save(fullfile(fileparts(mfilename('fullpath')), 'results', '_pv2.mat'));

clear; close all;
run(fullfile(fileparts(mfilename('fullpath')), 'R2_06c_velocity_anchor_conditions.m'));
save(fullfile(fileparts(mfilename('fullpath')), 'results', '_pv3.mat'));

clear; close all;
run(fullfile(fileparts(mfilename('fullpath')), 'R2_07_filter_compare.m'));
save(fullfile(fileparts(mfilename('fullpath')), 'results', '_pv4.mat'));

fprintf('\n\n4 workspaces saved\n');

clear; close all;
run(fullfile(fileparts(mfilename('fullpath')), 'R2_13_fps_phase_error.m'));
save(fullfile(fileparts(mfilename('fullpath')), 'results', '_pv5.mat'));
