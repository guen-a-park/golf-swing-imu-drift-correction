%% R2_pv_collect.m
%  for the items where the manuscript only compared two conditions without attaching a statistical test,
%  each analysis script is run and its workspace saved in full so that a paired t test can be
%  attached. The test itself is performed in R2_pv_report.m.
%
%  each script calls clear on its first line, so a loop cannot be used and the calls are written out.
%
%  Targets
%    (1) R2_01_target_uncertainty         trajectory error per constraint condition
%    (2) R2_02_true_distance_trajectory   trajectory error of the constraint re-solved with the measured distance
%    (3) R2_06c_velocity_anchor_conditions velocity anchor conditions
%    (4) R2_07_filter_compare             complementary filter conditions
%
%  Output : revision/results/_pv1.mat ... _pv4.mat
%
%  2026-09-09
%% ========================================================================

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
