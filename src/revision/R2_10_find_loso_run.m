%% [R2-10] R2_10_find_loso_run.m
%  Finds which LOSO run produced the correlations (0.07 / 0.33 / 0.19) printed in panels G-I of
%  Figure 3 of the manuscript, because the same run must be used when Figure 3 is redrawn.
%
%  2026-09-06
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
vid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
s = M.subj;

fprintf([NL 'Figure 3 G-I correlations per LOSO run   (printed in manuscript: 0.07 / 0.33 / 0.19)' NL]);
for r = 1:5
    runDir = fullfile(ML, sprintf('runs_0224_accgyro_400800_loso%d', r));
    D = nan(numel(s), 3);
    for su = unique(s)'
        f = fullfile(runDir, sprintf('fold_subj%d', su), ...
                     sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f); idx = find(s == su);
        for k = 1:min(numel(idx), height(T))
            D(idx(k), :) = [T.pred_x(k) T.pred_y(k) T.pred_z(k)];
        end
    end
    D = D / 10;
    line = sprintf('  loso%d :', r);
    for d = 1:3
        ok = isfinite(vid(:,d)) & isfinite(D(:,d));
        if nnz(ok) < 3, line = [line '   (none)']; continue; end %#ok<AGROW>
        [rr, pp] = corr(vid(ok,d), D(ok,d));
        if pp < 0.05, mark = '*'; else, mark = ' '; end
        line = [line sprintf('  %+.2f%s', rr, mark)]; %#ok<AGROW>
    end
    fprintf([line '   (n = %d)' NL], nnz(all(isfinite(D), 2)));
end
fprintf([NL '* is p < 0.05' NL]);
