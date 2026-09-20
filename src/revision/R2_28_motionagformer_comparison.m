%% [R2-28] R2_28_motionagformer_comparison.m
%  Reviewer 2, Comment R2-28 response (+ generates the Hotelling-Williams input for R2-10 (e))
%  ------------------------------------------------------------------------
%  Comment: do not only say "improved linearity"; state the absolute error alongside.
%        (the sentence stating that the proposed video method raised X-axis linearity from 0.37 -> 0.72
%         over MotionAGFormer must also state what the absolute error is)
%
%  Computed     : for the estimation of constraint D (wrist displacement at impact relative to address)
%    (1) per-axis MAE / RMSE / bias  — proposed video method vs MotionAGFormer
%    (2) per-axis Pearson R (pooled / within-participant rm-corr) rm-corr)
%    (3) correlation r23 between the two methods -> Hotelling-Williams test
%        (actually tests the manuscript's claim of a "significant improvement from 0.37 -> 0.72")
%
%  MotionAGFormer estimate is computed as in swing1127_withml_3d_0304.m by
%    motionag = dl(:,1:3) + com,   com = (rias + lias)/2
%  and the values that R2_common_mocap_extract.m stored as Dag_* are used.
%
%  Prerequisite : R2_common_mocap_extract.m
%  Output       : revision/results/R2_28_method_comparison.csv
%              revision/results/R2_28_hotelling_williams.csv
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M');

axesName = {'X','Y','Z'};

Msel = M(M.club == 1, :);                                    % driver
ref  = [Msel.Dref_x, Msel.Dref_y, Msel.Dref_z] / 10;         % mm -> cm
vid  = [Msel.Dvid_x, Msel.Dvid_y, Msel.Dvid_z] / 10;         % proposed video method
ag   = [Msel.Dag_x,  Msel.Dag_y,  Msel.Dag_z ] / 10;         % MotionAGFormer
subj = Msel.subj;

ok = all(isfinite([ref vid ag]), 2);
ref = ref(ok,:); vid = vid(ok,:); ag = ag(ok,:); subj = subj(ok);
subjList = unique(subj); nS = numel(subjList); nT = numel(subj);

fprintf('\n===== [R2-28] constraint D estimation accuracy: proposed video method vs MotionAGFormer vs MotionAGFormer =====\n');
fprintf('driver, %d trials / %d subjects\n', nT, nS);

rows = {}; hwrows = {};
for d = 1:3
    x = ref(:,d); y1 = vid(:,d); y2 = ag(:,d);

    % --- participant-level error metrics ---
    [mae1, rmse1, bias1] = local_err(x, y1, subj, subjList);
    [mae2, rmse2, bias2] = local_err(x, y2, subj, subjList);

    % --- correlation ---
    r12 = corr(x, y1);            % mocap vs proposed
    r13 = corr(x, y2);            % mocap vs AGFormer
    r23 = corr(y1, y2);           % between the two estimation methods
    rm12 = local_rmcorr(x, y1, subj, subjList);
    rm13 = local_rmcorr(x, y2, subj, subjList);

    rows(end+1,:) = {axesName{d}, ...
        mae1(1), mae1(2), rmse1(1), rmse1(2), bias1(1), bias1(2), r12, rm12, ...
        mae2(1), mae2(2), rmse2(1), rmse2(2), bias2(1), bias2(2), r13, rm13, ...
        r23, nS, nT}; %#ok<SAGROW>

    % --- Hotelling-Williams : both trial-based n and participant-based n ---
    [t1, p1, df1] = hotelling_williams(r12, r13, r23, nT);
    [t2, p2, df2] = hotelling_williams(r12, r13, r23, nS);
    hwrows(end+1,:) = {axesName{d}, r12, r13, r23, nT, t1, df1, p1, nS, t2, df2, p2}; %#ok<SAGROW>
end

T = cell2table(rows, 'VariableNames', {'axis', ...
    'prop_MAE','prop_MAE_sd','prop_RMSE','prop_RMSE_sd','prop_bias','prop_bias_sd','prop_R','prop_rmR', ...
    'ag_MAE','ag_MAE_sd','ag_RMSE','ag_RMSE_sd','ag_bias','ag_bias_sd','ag_R','ag_rmR', ...
    'r_between_methods','nSubj','nTrial'});
writetable(T, fullfile(OUT_DIR, 'R2_28_method_comparison.csv'));

H = cell2table(hwrows, 'VariableNames', {'axis','r_prop','r_ag','r_between', ...
    'n_trial','t_trial','df_trial','p_trial','n_subj','t_subj','df_subj','p_subj'});
writetable(H, fullfile(OUT_DIR, 'R2_28_hotelling_williams.csv'));

%% ===== console =====
fprintf('\n--- accuracy (participant-level mean ± SD, cm) mean ± SD, cm) ---\n');
fprintf('%-5s | %-34s | %-34s\n', 'Axis', 'proposed video method', 'MotionAGFormer');
fprintf('%-5s | %10s %10s %10s | %10s %10s %10s\n', '', 'MAE', 'RMSE', 'bias', 'MAE', 'RMSE', 'bias');
for r = 1:height(T)
    fprintf('%-5s | %10.2f %10.2f %10.2f | %10.2f %10.2f %10.2f\n', T.axis{r}, ...
        T.prop_MAE(r), T.prop_RMSE(r), T.prop_bias(r), ...
        T.ag_MAE(r), T.ag_RMSE(r), T.ag_bias(r));
end

fprintf('\n--- linearity ---\n');
fprintf('%-5s %12s %12s %12s %12s %14s\n', 'Axis', 'R prop', 'R ag', 'rm-R prop', 'rm-R ag', 'r(prop,ag)');
for r = 1:height(T)
    fprintf('%-5s %12.3f %12.3f %12.3f %12.3f %14.3f\n', T.axis{r}, ...
        T.prop_R(r), T.ag_R(r), T.prop_rmR(r), T.ag_rmR(r), T.r_between_methods(r));
end

fprintf('\n--- Hotelling-Williams (comparison of two correlations from the same sample) ---\n');
fprintf('%-5s %10s %10s %10s | %8s %10s | %8s %10s\n', 'Axis', 'r_prop', 'r_ag', 'r_between', ...
    't(trial)', 'p(trial)', 't(subj)', 'p(subj)');
for r = 1:height(H)
    fprintf('%-5s %10.3f %10.3f %10.3f | %8.3f %10.4f | %8.3f %10.4f\n', H.axis{r}, ...
        H.r_prop(r), H.r_ag(r), H.r_between(r), ...
        H.t_trial(r), H.p_trial(r), H.t_subj(r), H.p_subj(r));
end
fprintf('\nn = number of trials (%d): this overestimates significance because of the repeated-measures structure.\n', nT);
fprintf('When reporting, also present the conservative result based on the number of participants (%d).\n', nS);

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_28_method_comparison.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_28_hotelling_williams.csv'));


%% ===== functions =====
function [mae, rmse, bias] = local_err(x, y, subj, subjList)
% compute per-participant metrics first, then mean and SD across participants mean, SD
    nS = numel(subjList);
    a = nan(nS,1); r = nan(nS,1); b = nan(nS,1);
    for si = 1:nS
        k = subj == subjList(si);
        e = y(k) - x(k);
        a(si) = mean(abs(e)); r(si) = sqrt(mean(e.^2)); b(si) = mean(e);
    end
    mae = [mean(a) std(a)]; rmse = [mean(r) std(r)]; bias = [mean(b) std(b)];
end

function r = local_rmcorr(x, y, subj, subjList)
% repeated-measures correlation : correlation after removing participant means
    xc = x; yc = y;
    for si = 1:numel(subjList)
        k = subj == subjList(si);
        xc(k) = x(k) - mean(x(k));
        yc(k) = y(k) - mean(y(k));
    end
    r = corr(xc, yc);
end

function [t, p, df] = hotelling_williams(r12, r13, r23, n)
% Williams(1959) / Steiger(1980) : test of the difference between two correlations sharing common variable 1
    R  = 1 - r12^2 - r13^2 - r23^2 + 2*r12*r13*r23;
    rb = (r12 + r13) / 2;
    df = n - 3;
    num = (r12 - r13) * sqrt((n - 1) * (1 + r23));
    den = sqrt( 2*(n-1)/(n-3) * R + rb^2 * (1 - r23)^3 );
    t = num / den;
    p = 2 * (1 - tcdf(abs(t), df));
end
