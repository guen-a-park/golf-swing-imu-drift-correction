%% [R2-10] R2_10_statistics.m
%  Error-based accuracy metrics and repeated-measures statistics for Figure 3.
%  Output       : revision/results/R2_10_figure3_accuracy.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M');

axesName = {'X','Y','Z'};

%% Part A. Figure 3A-C : motion capture D vs video-based D_Vision
Msel = M(M.club == 1, :);                                  % driver
meas = [Msel.Dref_x, Msel.Dref_y, Msel.Dref_z] / 10;       % mm -> cm
pred = [Msel.Dvid_x, Msel.Dvid_y, Msel.Dvid_z] / 10;
subj = Msel.subj;
ok   = all(isfinite([meas pred]), 2);
meas = meas(ok,:); pred = pred(ok,:); subj = subj(ok);
subjList = unique(subj); nS = numel(subjList);

accRows = {}; corRows = {};
for d = 1:3
    x = meas(:,d); y = pred(:,d);

    [r_pool, p_pool] = corr(x, y, 'Type', 'Pearson');

    rs = nan(nS,1); ns = nan(nS,1);
    for si = 1:nS
        k = subj == subjList(si);
        if sum(k) >= 3 && std(x(k)) > 0 && std(y(k)) > 0
            rs(si) = corr(x(k), y(k));
            ns(si) = sum(k);
        end
    end
    v = isfinite(rs);
    z = atanh(min(max(rs(v), -0.999), 0.999));
    w = ns(v) - 3;
    r_fisher = tanh(sum(w.*z) / sum(w));
    se_z     = 1/sqrt(sum(w));
    ci_fisher = tanh([sum(w.*z)/sum(w) - 1.96*se_z, sum(w.*z)/sum(w) + 1.96*se_z]);

    xc = x; yc = y;
    for si = 1:nS
        k = subj == subjList(si);
        xc(k) = x(k) - mean(x(k));
        yc(k) = y(k) - mean(y(k));
    end
    r_rm = corr(xc, yc);
    df_rm = numel(x) - nS - 1;
    t_rm = r_rm * sqrt(df_rm / max(1 - r_rm^2, eps));
    p_rm = 2 * (1 - tcdf(abs(t_rm), df_rm));

    tbl = table(y, x, categorical(subj), 'VariableNames', {'pred','meas','subj'});
    lme = fitlme(tbl, 'pred ~ meas + (1|subj)');
    ci  = coefCI(lme);
    slope = lme.Coefficients.Estimate(2);
    p_lme = lme.Coefficients.pValue(2);
    slope_ci = ci(2,:);

    corRows(end+1,:) = {axesName{d}, r_pool, p_pool, r_fisher, ci_fisher(1), ci_fisher(2), ...
        r_rm, p_rm, df_rm, slope, slope_ci(1), slope_ci(2), p_lme, nS, numel(x)}; %#ok<SAGROW>

    e = y - x;                                             % bias sign kept
    sm = nan(nS,1); sa = nan(nS,1); sr = nan(nS,1);
    for si = 1:nS
        k = subj == subjList(si);
        sm(si) = mean(e(k));                               % subject bias
        sa(si) = mean(abs(e(k)));                          % subject MAE
        sr(si) = sqrt(mean(e(k).^2));                      % subject RMSE
    end
    loa = [mean(e) - 1.96*std(e), mean(e) + 1.96*std(e)];  % Bland-Altman 95% LoA
    accRows(end+1,:) = {axesName{d}, mean(sa), std(sa), mean(sr), std(sr), ...
        mean(sm), std(sm), loa(1), loa(2), nS, numel(x)}; %#ok<SAGROW>
end

Tcor = cell2table(corRows, 'VariableNames', {'axis', ...
    'r_pooled','p_pooled','r_fisher','r_fisher_lo','r_fisher_hi', ...
    'r_rm','p_rm','df_rm','lme_slope','lme_slope_lo','lme_slope_hi','lme_p','nSubj','nTrial'});
Tacc = cell2table(accRows, 'VariableNames', {'axis', ...
    'MAE_mean','MAE_sd','RMSE_mean','RMSE_sd','bias_mean','bias_sd', ...
    'LoA_lower','LoA_upper','nSubj','nTrial'});
writetable(Tcor, fullfile(OUT_DIR, 'R2_10_correlation_methods.csv'));
writetable(Tacc, fullfile(OUT_DIR, 'R2_10_figure3_accuracy.csv'));

fprintf('\n===== [R2-10] Part A. Figure 3A-C (video D vs mocap D), driver =====\n');
fprintf('%d trials / %d subjects\n\n', numel(x), nS);
fprintf('--- Correlation: comparison by aggregation method ---\n');
fprintf('%-5s %14s %22s %20s %22s\n', 'Axis', 'pooled R', 'Fisher-z mean R [95%CI]', 'rm-corr (p)', 'LME slope [95%CI], p');
for r = 1:height(Tcor)
    fprintf('%-5s %8.3f (%s) %8.3f [%.3f %.3f] %8.3f (%.4f) %8.3f [%.3f %.3f] %.4f\n', ...
        Tcor.axis{r}, Tcor.r_pooled(r), local_pstr(Tcor.p_pooled(r)), ...
        Tcor.r_fisher(r), Tcor.r_fisher_lo(r), Tcor.r_fisher_hi(r), ...
        Tcor.r_rm(r), Tcor.p_rm(r), ...
        Tcor.lme_slope(r), Tcor.lme_slope_lo(r), Tcor.lme_slope_hi(r), Tcor.lme_p(r));
end

fprintf('\n--- Accuracy metrics (participant-level mean ± SD, cm) mean ± SD, cm) ---\n');
fprintf('%-5s %16s %16s %16s %20s\n', 'Axis', 'MAE', 'RMSE', 'bias', 'Bland-Altman LoA');
for r = 1:height(Tacc)
    fprintf('%-5s %7.2f ± %-6.2f %7.2f ± %-6.2f %7.2f ± %-6.2f [%6.2f, %6.2f]\n', ...
        Tacc.axis{r}, Tacc.MAE_mean(r), Tacc.MAE_sd(r), ...
        Tacc.RMSE_mean(r), Tacc.RMSE_sd(r), Tacc.bias_mean(r), Tacc.bias_sd(r), ...
        Tacc.LoA_lower(r), Tacc.LoA_upper(r));
end

%% Bland-Altman figure
figure('Color','w','Position',[100 100 1000 320]);
for d = 1:3
    subplot(1,3,d); hold on; grid on;
    x = meas(:,d); y = pred(:,d);
    mu = (x + y)/2; e = y - x;
    cmap = lines(nS);
    for si = 1:nS
        k = subj == subjList(si);
        scatter(mu(k), e(k), 16, cmap(si,:), 'filled', 'MarkerFaceAlpha', 0.6);
    end
    yline(mean(e), 'k-', 'LineWidth', 1.5);
    yline(mean(e) + 1.96*std(e), 'k--');
    yline(mean(e) - 1.96*std(e), 'k--');
    xlabel(sprintf('mean of mocap & video, %s (cm)', axesName{d}));
    ylabel('video - mocap (cm)');
    title(sprintf('%s: bias %.2f, LoA [%.2f, %.2f]', axesName{d}, ...
        mean(e), mean(e)-1.96*std(e), mean(e)+1.96*std(e)));
end
exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_10_blandaltman.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_10_blandaltman.svg'));

%% Part B. Hotelling-Williams test
HW = struct();
HW.n   = numel(x);                                  % number of trials (pooled basis)
HW.r12 = [0.72 0.63 0.82];                          % proposed video-based (manuscript Fig 3A-C) Fig 3A-C)
HW.r13 = [0.37 0.66 0.77];                          % MotionAGFormer (manuscript text)
HW.r23 = [NaN  NaN  NaN ];                          % <<< correlation between the two estimates (input required)

fprintf('\n===== [R2-10] Part B. Hotelling-Williams test =====\n');
if all(isnan(HW.r23))
    fprintf('r23 (correlation between the two estimation methods) is empty, so the computation is skipped.\n');
    fprintf('MotionAGFormer estimates: obtain them and fill HW.r23, or call the function below directly:\n');
    fprintf('  [t, p, df] = hotelling_williams(r12, r13, r23, n)\n');
else
    for d = 1:3
        if isnan(HW.r23(d)), continue; end
        [tv, pv, dfv] = hotelling_williams(HW.r12(d), HW.r13(d), HW.r23(d), HW.n);
        fprintf('  %s : r12=%.2f vs r13=%.2f (r23=%.2f, n=%d) -> t(%d)=%.3f, p=%.4f\n', ...
            axesName{d}, HW.r12(d), HW.r13(d), HW.r23(d), HW.n, dfv, tv, pv);
    end
end
fprintf('\nNote: using the number of trials as n overestimates significance because of the repeated-measures structure.\n');
fprintf('      To report at participant level, set n = number of participants (%d) and interpret conservatively.\n', nS);

%% Part C. Welch's t-test against prior work Kim & Park (2024) Welch's t-test
CMP = {
  'Orientation ADD',   11.00, 4.00, 10,   7.6, 3.1, 20;
  'Orientation BST',   10.70, 3.24, 10,   8.5, 3.3, 20;
  'Orientation IMP',   29.04, 8.28, 10,  14.1, 4.5, 20;
  'Orientation FIN',   16.25,11.58, 10,  11.1, 5.9, 20;
  'Orientation ALL',   13.75, 3.83, 10,   9.5, 3.2, 20;
  'Traj Backswing',    14.13, 4.06, 10,  11.2, 4.2, 20;
  'Traj Downswing',    15.13, 5.55, 10,  26.6,12.3, 20;
  'Traj Followthrough',32.56,19.18, 10,  34.3,14.0, 20;
  'Traj Entire',       19.56, 7.12, 10,  16.8, 5.4, 20};

wrows = {};
fprintf('\n===== [R2-10] Part C. Welch''s t-test vs Kim & Park (2024) =====\n');
fprintf('%-20s %14s %14s %8s %8s %10s %6s\n', 'Quantity', 'Proposed', 'Kim', 't', 'df', 'p', '');
for r = 1:size(CMP,1)
    [tv, pv, dfv] = welch_ttest(CMP{r,2}, CMP{r,3}, CMP{r,4}, CMP{r,5}, CMP{r,6}, CMP{r,7});
    fprintf('%-20s %6.2f ± %-6.2f %6.2f ± %-6.2f %8.2f %8.1f %10.4f %6s\n', ...
        CMP{r,1}, CMP{r,2}, CMP{r,3}, CMP{r,5}, CMP{r,6}, tv, dfv, pv, local_star(pv));
    wrows(end+1,:) = {CMP{r,1}, CMP{r,2}, CMP{r,3}, CMP{r,4}, CMP{r,5}, CMP{r,6}, CMP{r,7}, tv, dfv, pv}; %#ok<SAGROW>
end
W = cell2table(wrows, 'VariableNames', {'quantity','mean1','sd1','n1','mean2','sd2','n2','t','df','p'});
writetable(W, fullfile(OUT_DIR, 'R2_10_welch_prior_study.csv'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_10_correlation_methods.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_figure3_accuracy.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_welch_prior_study.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_10_blandaltman.png'));

%% functions
function [t, p, df] = hotelling_williams(r12, r13, r23, n)
    R  = 1 - r12^2 - r13^2 - r23^2 + 2*r12*r13*r23;      % determinant of the correlation matrix
    rb = (r12 + r13) / 2;
    df = n - 3;
    num = (r12 - r13) * sqrt((n - 1) * (1 + r23));
    den = sqrt( 2*(n-1)/(n-3) * R + rb^2 * (1 - r23)^3 );
    t = num / den;
    p = 2 * (1 - tcdf(abs(t), df));
end

function [t, p, df] = welch_ttest(m1, s1, n1, m2, s2, n2)
    se2 = s1^2/n1 + s2^2/n2;
    t   = (m1 - m2) / sqrt(se2);
    df  = se2^2 / ( (s1^2/n1)^2/(n1-1) + (s2^2/n2)^2/(n2-1) );
    p   = 2 * (1 - tcdf(abs(t), df));
end

function s = local_star(p)
    if     p < 0.001, s = '***';
    elseif p < 0.01,  s = '**';
    elseif p < 0.05,  s = '*';
    else,             s = 'n.s.';
    end
end

function s = local_pstr(p)
    if p < 0.001, s = 'p<0.001'; else, s = sprintf('p=%.3f', p); end
end
