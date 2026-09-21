%% [R2-2] R2_02_ball_wrist_distance.m
%  Validity and sensitivity of the club-length geometric constraint.
%  Output    : revision/results/R2_02_ball_wrist_distance.csv

clc; clear; close all;
set(groot, 'defaultAxesFontSize', 12);

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M', 'club_length');

subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];

T_CAM = [1944.24195587, -147.53836065, 1065.52214668, 1988.64350687,  74.47982735, 1112.23512068;
         1946.26368487, -145.41073665, 1064.27866168, 1994.22126587,  81.45108035, 1111.14594468;
         1941.23811087, -147.26589965, 1064.27767068, 2038.02827187,  89.00796435, 1111.81709868;
         1966.736499  , -163.74432434, 1081.82660875, 2065.960681  ,  72.87786766, 1128.88531375;
         1967.165515  , -166.96142634, 1080.93007875, 2066.129566  ,  78.63897666, 1128.51837375;
         2102.062     , -175.03607234, 1081.19622275, 2146.704822  ,  81.41601466, 1128.71147375;
         2102.23739517, -178.74541095, 1095.93619444, 2101.42642117,  54.29340805, 1122.86608444;
         2103.45266617, -187.32518295, 1074.79984244, 2200.30862417,  62.93507005, 1123.65457044;
         2100.91714417, -175.84581295, 1072.13565044, 2200.96078417,  52.08002905, 1121.78629644;
         2106.32278417, -184.96391595, 1074.71015144, 2171.27706817,  62.53522905, 1123.21138744];

CLUB_SEL = 1;                       % driver
Msel = M(M.club == CLUB_SEL, :);
nT = height(Msel);

%% (A) actual ball-wrist distance
d_add = Msel.L_add - Msel.L_assumed;        % mm, actual - assumed
d_imp = Msel.L_imp - Msel.L_assumed;
d_impadd = Msel.L_imp - Msel.L_add;         % IMP - ADD (change in effective distance)

subjList = unique(Msel.subj);
nS = numel(subjList);

Arows = {};
for si = 1:nS
    s = subjList(si);
    k = Msel.subj == s;
    Arows(end+1,:) = { s, string(subjN(s)), sum(k), Msel.L_assumed(find(k,1))/10, ...
        mean(Msel.L_add(k))/10, std(Msel.L_add(k))/10, ...
        mean(Msel.L_imp(k))/10, std(Msel.L_imp(k))/10, ...
        mean(d_add(k))/10, mean(d_imp(k))/10, ...
        mean(d_impadd(k))/10, std(d_impadd(k))/10 }; %#ok<SAGROW>
end
A = cell2table(Arows, 'VariableNames', {'subj','subjName','nTrial','clubLength_cm', ...
    'Ladd_mean_cm','Ladd_sd_cm','Limp_mean_cm','Limp_sd_cm', ...
    'diffADD_cm','diffIMP_cm','IMPminusADD_mean_cm','IMPminusADD_sd_cm'});
writetable(A, fullfile(OUT_DIR, 'R2_02_ball_wrist_distance.csv'));

fprintf('\n===== [R2-2] (A) actual ball-wrist distance (driver, %d trials / %d subj) =====\n', nT, nS);
fprintf('%-6s %8s %16s %16s %10s %10s %14s\n', 'Subj', 'club l', 'L@ADD (cm)', 'L@IMP (cm)', ...
    'ADD-l', 'IMP-l', 'IMP-ADD');
for r = 1:height(A)
    fprintf('%-6s %8.1f %8.1f ± %-5.1f %8.1f ± %-5.1f %10.1f %10.1f %7.1f ± %-5.1f\n', ...
        A.subjName(r), A.clubLength_cm(r), ...
        A.Ladd_mean_cm(r), A.Ladd_sd_cm(r), A.Limp_mean_cm(r), A.Limp_sd_cm(r), ...
        A.diffADD_cm(r), A.diffIMP_cm(r), A.IMPminusADD_mean_cm(r), A.IMPminusADD_sd_cm(r));
end
fprintf('%-6s %8s %8.1f ± %-5.1f %8.1f ± %-5.1f %10.1f %10.1f %7.1f ± %-5.1f   <- between-participant mean ± SD\n', ...
    'ALL', '', mean(A.Ladd_mean_cm), std(A.Ladd_mean_cm), ...
    mean(A.Limp_mean_cm), std(A.Limp_mean_cm), ...
    mean(A.diffADD_cm), mean(A.diffIMP_cm), ...
    mean(A.IMPminusADD_mean_cm), std(A.IMPminusADD_mean_cm));
fprintf('\nwithin-participant between-trial SD (mean) : ADD %.2f cm, IMP %.2f cm\n', ...
    mean(A.Ladd_sd_cm), mean(A.Limp_sd_cm));
[~, p_ai] = ttest(A.Ladd_mean_cm, A.Limp_mean_cm);
fprintf('ADD vs IMP effective distance difference (participant-level paired samples) : %.2f cm, p = %.4f\n', ...
    mean(A.Limp_mean_cm - A.Ladd_mean_cm), p_ai);

%% (B) assumed distance error -> D_Vision sensitivity
DELTA_CM = 2;                                % +-2 cm, used as a worked example
Brows = {};
sens_add = nan(nT, 3); sens_imp = nan(nT, 3);   % dX/dl  (dimensionless, mm/mm)
dD_true  = nan(nT, 3);                           % change in D when l is replaced by the actual distance
dD_2cm   = nan(nT, 3);                           % change in D when l is increased by 2 cm

for k = 1:nT
    subj = Msel.subj(k);
    Tw = T_CAM(subj, 1:3)';                      % club 1/3 use columns 1:3
    l0 = Msel.L_assumed(k);

    p_add = [Msel.addEst_x(k); Msel.addEst_y(k); Msel.addEst_z(k)];
    p_imp = [Msel.impEst_x(k); Msel.impEst_y(k); Msel.impEst_z(k)];
    if any(~isfinite([p_add; p_imp])), continue; end

    [sa, ra] = local_ray(Tw, p_add);
    [si_, ri] = local_ray(Tw, p_imp);

    sens_add(k,:) = local_dXdl(Tw, ra, l0)';
    sens_imp(k,:) = local_dXdl(Tw, ri, l0)';

    qa = local_solve(Tw, ra, Msel.L_add(k), sa);
    qi = local_solve(Tw, ri, Msel.L_imp(k), si_);
    dD_true(k,:) = ((qi - qa) - (p_imp - p_add))';

    qa2 = local_solve(Tw, ra, l0 + DELTA_CM*10, sa);
    qi2 = local_solve(Tw, ri, l0 + DELTA_CM*10, si_);
    dD_2cm(k,:) = ((qi2 - qa2) - (p_imp - p_add))';
end

dDdl = sens_imp - sens_add;                      % dD/dl  (per component)
ok = all(isfinite(dDdl), 2);

fprintf('\n===== [R2-2] (B) club length error -> D_Vision sensitivity =====\n');
fprintf('dD/dl  (change in D when l increases by 1 cm, cm)\n');
fprintf('   X %+.3f ± %.3f   Y %+.3f ± %.3f   Z %+.3f ± %.3f   |dD| %.3f ± %.3f\n', ...
    mean(dDdl(ok,1)), std(dDdl(ok,1)), mean(dDdl(ok,2)), std(dDdl(ok,2)), ...
    mean(dDdl(ok,3)), std(dDdl(ok,3)), ...
    mean(vecnorm(dDdl(ok,:), 2, 2)), std(vecnorm(dDdl(ok,:), 2, 2)));

n2 = vecnorm(dD_2cm(ok,:), 2, 2) / 10;
fprintf('\nwhen l is mis-assumed by +%d cm, |ΔD| = %.2f ± %.2f cm (max %.2f)\n', ...
    DELTA_CM, mean(n2), std(n2), max(n2));

nt = vecnorm(dD_true(ok,:), 2, 2) / 10;
fprintf('when the motion capture measured distance is used instead of l, |ΔD| = %.2f ± %.2f cm (max %.2f)\n', ...
    mean(nt), std(nt), max(nt));
fprintf('  ΔD per axis (cm) : X %+.2f ± %.2f, Y %+.2f ± %.2f, Z %+.2f ± %.2f\n', ...
    mean(dD_true(ok,1))/10, std(dD_true(ok,1))/10, ...
    mean(dD_true(ok,2))/10, std(dD_true(ok,2))/10, ...
    mean(dD_true(ok,3))/10, std(dD_true(ok,3))/10);

%% (C) D_Vision error -> propagation into corrected trajectory error (closed form)
wbar_full = nan(nT,1); wbar_down = nan(nT,1);
for k = 1:nT
    a = Msel.idxADD(k); b = Msel.idxBST(k); i = Msel.idxIMP(k);
    w = ((a:i) - a) / (i - a);
    wbar_full(k) = mean(w);                       % mean weight over ADD~IMP
    wd = ((b:i) - a) / (i - a);
    wbar_down(k) = mean(wd);                      % mean weight over BST~IMP (downswing)
end

fprintf('\n===== [R2-2] (C) ΔD -> propagation into corrected trajectory error =====\n');
fprintf('the correction term is distributed linearly from ADD(0) to IMP(1), so dX_corr(t)/dD = w(t).\n');
fprintf('  at impact          : trajectory error = |ΔD|        (w = 1)\n');
fprintf('  ADD~IMP mean       : trajectory error = %.2f x |ΔD|\n', mean(wbar_full));
fprintf('  downswing mean     : trajectory error = %.2f x |ΔD|\n', mean(wbar_down));
fprintf('\nworked example (+-2 cm):\n');
fprintf('  club length mis-assumed by 2 cm -> |ΔD| = %.2f cm\n', mean(n2));
fprintf('  -> impact trajectory error +%.2f cm, downswing mean +%.2f cm\n', ...
    mean(n2), mean(n2)*mean(wbar_down));
fprintf('  (%.1f%% of the currently reported downswing error of 15.13 cm)\n', ...
    100*mean(n2)*mean(wbar_down)/15.13);

Srows = {'dDdl_perCm', mean(vecnorm(dDdl(ok,:),2,2)), std(vecnorm(dDdl(ok,:),2,2));
         sprintf('absDeltaD_l_plus%dcm_cm', DELTA_CM), mean(n2), std(n2);
         'absDeltaD_useTrueDistance_cm', mean(nt), std(nt);
         'meanWeight_ADDtoIMP', mean(wbar_full), std(wbar_full);
         'meanWeight_downswing', mean(wbar_down), std(wbar_down)};
S = cell2table(Srows, 'VariableNames', {'quantity','mean','sd'});
writetable(S, fullfile(OUT_DIR, 'R2_02_sensitivity.csv'));

%% figure
figure('Color','w','Position',[100 100 1000 380]);

subplot(1,3,1); hold on; grid on;
for si = 1:nS
    s = subjList(si); k = Msel.subj == s;
    scatter(repmat(si, sum(k), 1) - 0.15, Msel.L_add(k)/10, 14, [0.2 0.4 0.8], 'filled', 'MarkerFaceAlpha', 0.5);
    scatter(repmat(si, sum(k), 1) + 0.15, Msel.L_imp(k)/10, 14, [0.8 0.3 0.2], 'filled', 'MarkerFaceAlpha', 0.5);
    plot(si + [-0.3 0.3], [1 1]*club_length(s)/10, 'k-', 'LineWidth', 1.5);
end
set(gca, 'XTick', 1:nS, 'XTickLabel', cellstr(subjN(subjList)), 'XTickLabelRotation', 45);
ylabel('Ball-to-wrist distance (cm)');
title('Actual distance vs assumed club length');
legend({'ADD','IMP','club length'}, 'Location', 'best', 'FontSize', 8);

subplot(1,3,2); hold on; grid on;
histogram(d_impadd/10, 20, 'FaceColor', [0.4 0.4 0.7]);
xline(0, 'k--');
xlabel('L_{IMP} - L_{ADD} (cm)'); ylabel('trials');
title(sprintf('Effective distance change\nmean %.1f cm', mean(d_impadd)/10));

subplot(1,3,3); hold on; grid on;
histogram(vecnorm(dD_true(ok,:), 2, 2)/10, 20, 'FaceColor', [0.7 0.4 0.4]);
xlabel('|\DeltaD| (cm)'); ylabel('trials');
title(sprintf('D change if true distance used\nmean %.2f cm', mean(nt)));

exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_02_ball_wrist_distance.png'), 'Resolution', 300);
saveas(gcf, fullfile(OUT_DIR, 'fig_R2_02_ball_wrist_distance.svg'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_02_ball_wrist_distance.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_02_sensitivity.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_02_ball_wrist_distance.png'));

%% local functions
function [s, rhat] = local_ray(Tw, p)
    d = p - Tw;
    s = norm(d);
    rhat = d / s;
end

function dXdl = local_dXdl(Tw, rhat, l)
    b = 2*dot(rhat, Tw);
    c = dot(Tw, Tw) - l^2;
    Delta = b^2 - 4*c;
    dXdl = (2*l / sqrt(max(Delta, eps))) * rhat;
end

function q = local_solve(Tw, rhat, l, s_ref)
    b = 2*dot(rhat, Tw);
    c = dot(Tw, Tw) - l^2;
    Delta = b^2 - 4*c;
    if Delta < 0
        q = Tw + s_ref*rhat; return
    end
    s1 = (-b + sqrt(Delta))/2;
    s2 = (-b - sqrt(Delta))/2;
    cand = [s1 s2];
    cand = cand(cand > 0);
    if isempty(cand)
        q = Tw + s_ref*rhat; return
    end
    [~, ii] = min(abs(cand - s_ref));
    q = Tw + cand(ii)*rhat;
end
