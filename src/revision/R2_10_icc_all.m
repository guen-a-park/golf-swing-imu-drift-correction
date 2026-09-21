%% [R2-10] R2_10_icc_all.m
%  Compares the between-participant reproducibility of the four estimates by ICC against a single motion capture reference.
%  Output : revision/results/R2_10_icc_all.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
NL  = char(10);

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
subj = M.subj;
Dref = [M.Dref_x M.Dref_y M.Dref_z] / 10;
Dvid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
Dag  = [M.Dag_x  M.Dag_y  M.Dag_z ] / 10;
Dpool = local_load(fullfile(ML, 'runs_0112_accgyro_400800_ori7traj2'), subj, false);
Dloso = local_load(fullfile(ML, 'runs_0224_accgyro_400800_loso3'),     subj, true);

NAME = {'D_Vision', 'D_Infer', 'D_Infer LOSO', 'D_AGFormer'};
EST  = {Dvid, Dpool, Dloso, Dag};
axName = {'X (fore-aft)','Y (left-right)','Z (up-down)'};
u = unique(subj);

fprintf([NL 'ICC(C,1) against motion capture D, %d participant means' NL NL], numel(u));
fprintf('%-14s', 'estimate');
for d = 1:3, fprintf('%26s', axName{d}); end
fprintf(NL);
rows = {};
for m = 1:4
    fprintf('%-14s', NAME{m});
    for d = 1:3
        ok = isfinite(Dref(:,d)) & isfinite(EST{m}(:,d));
        a = arrayfun(@(x) mean(Dref(ok & subj==x, d)), u);
        b = arrayfun(@(x) mean(EST{m}(ok & subj==x, d)), u);
        g = isfinite(a) & isfinite(b);
        [ic, lo, hi, p] = local_icc(a(g), b(g));
        fprintf('  %5.2f [%5.2f,%5.2f] %s', ic, lo, hi, local_star(p));
        rows = [rows; {NAME{m}, axName{d}, ic, lo, hi, p}]; %#ok<AGROW>
    end
    fprintf(NL);
end
fprintf([NL '* p < 0.05   ** p < 0.01   *** p < 0.001' NL]);

T = cell2table(rows, 'VariableNames', {'estimate','axis','ICC','CI_lo','CI_hi','p'});
writetable(T, fullfile(OUT, 'R2_10_icc_all.csv'));
fprintf([NL 'saved: results/R2_10_icc_all.csv' NL]);

%% helper functions
function D = local_load(runDir, subj, isLoso)
    D = nan(numel(subj), 3);
    for su = unique(subj)'
        if isLoso
            f = fullfile(runDir, sprintf('fold_subj%d', su), ...
                         sprintf('subj%d_driver_test_est.csv', su));
        else
            f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        end
        if ~isfile(f), continue; end
        T = readtable(f); idx = find(subj == su);
        for k = 1:min(numel(idx), height(T))
            D(idx(k), :) = [T.pred_x(k) T.pred_y(k) T.pred_z(k)];
        end
    end
    D = D / 10;
end
function [icc, lo, hi, p] = local_icc(x, y)
    Y = [x(:) y(:)]; [n, k] = size(Y); gm = mean(Y(:));
    MSR = k * sum((mean(Y,2) - gm).^2) / (n-1);
    MSC = n * sum((mean(Y,1) - gm).^2) / (k-1);
    MSE = (sum((Y(:) - gm).^2) - (n-1)*MSR - (k-1)*MSC) / ((n-1)*(k-1));
    icc = (MSR - MSE) / (MSR + (k-1)*MSE);
    F = MSR / MSE; df1 = n-1; df2 = (n-1)*(k-1);
    p = 1 - fcdf(F, df1, df2);
    fL = F / finv(0.975, df1, df2); fU = F * finv(0.975, df2, df1);
    lo = (fL - 1) / (fL + k - 1); hi = (fU - 1) / (fU + k - 1);
end
function s = local_star(p)
    if p < 0.001, s = '***'; elseif p < 0.01, s = '** '; elseif p < 0.05, s = '*  '; else, s = '   '; end
end
