%% [R2r2-13] R2r2_13_figure2_data.m
%  Trial-wise d_mocap of the amateur and professional participants for the revised Figure 2.
%  Output : revision/results/R2r2_13_figure2_d_mocap.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
baseDir = fileparts(thisDir);

L = load(fullfile(RES, 'R2_common_mocap_metrics.mat'), 'M'); M = L.M;
Ma = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
Ma = Ma(isfinite(Ma.Dref_x), :);
grp = repmat("Amateur", height(Ma), 1);
T = table(grp, Ma.subj, Ma.trial, Ma.Dref_x/10, Ma.Dref_y/10, Ma.Dref_z/10, ...
    'VariableNames', {'group','subj','trial','dx','dy','dz'});

proFile = fullfile(fileparts(baseDir), 'GolfSwing_0424', 'data', 'swingData_IMP-3.5+1_20Hz_spline.mat');
if ~isfile(proFile), proFile = fullfile(baseDir, 'data', 'swingData_IMP-3.5+1_20Hz_spline.mat'); end
P = load(proFile); fn = fieldnames(P); swingData = P.(fn{1});
IMP_IDX = 700 - 1;
R = {};
for si = 1:9
    subj = 11 + si;
    for trial = 1:10
        if subj == 19 && trial == 8, continue; end
        s = swingData(subj).clubN(1).trialN(trial);
        if isempty(s) || ~isfield(s, 'Mwrist'), continue; end
        d = (s.Mwrist(IMP_IDX,:) - s.Mwrist(s.address,:)) * 100;
        R(end+1,:) = {"Professional", si, trial, d(1), d(2), d(3)};
    end
end
T = [T; cell2table(R, 'VariableNames', T.Properties.VariableNames)];
writetable(T, fullfile(RES, 'R2r2_13_figure2_d_mocap.csv'));

for g = ["Amateur" "Professional"]
    Tg = T(T.group == g, :);
    fprintf('%s : %d trials, %d participants\n', g, height(Tg), numel(unique(Tg.subj)));
    for s = unique(Tg.subj)'
        k = Tg.subj == s;
        fprintf('  %2d  n=%2d  mean %6.2f %6.2f %6.2f\n', s, nnz(k), ...
            mean(Tg.dx(k)), mean(Tg.dy(k)), mean(Tg.dz(k)));
    end
end
