%% [R2-10] R2_10_bias_paired.m
%  tests the difference in error structure at the participant level.
%
%  the variance decomposition computed earlier (72 % shared vs 6 %) was obtained by pooling trials, so
%  it does not respect the repeated measures structure. The same quantity is re-expressed as one value
%  per participant and tested with paired samples.
%
%     (a) how far each participant's bias deviates from the overall mean bias  |b_i - b|
%         -> the smaller this value, the more the error reproduces across participants
%     (b) standard deviation of the within-participant error  sd_i
%         -> the smaller this value, the more stable the error within a participant
%
%  both values give one number per participant, so a paired t test with n = 10 is possible.
%
%  Target : 99 trials of the driver evaluation set
%  Output : revision/results/R2_10_bias_paired.csv
%
%  2026-09-06
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
ref = [M.Dref_x M.Dref_y M.Dref_z] / 10;
vid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
ag  = [M.Dag_x  M.Dag_y  M.Dag_z ] / 10;
ok  = all(isfinite([ref vid ag]), 2);
ref = ref(ok,:); vid = vid(ok,:); ag = ag(ok,:); s = M.subj(ok); u = unique(s);
axName = {'X (fore-aft)','Y (left-right)','Z (up-down)'};

rows = {};
fprintf([NL 'participant-level error structure (n = %d, paired t test)' NL], numel(u));
for d = 1:3
    eV = vid(:,d) - ref(:,d);
    eA = ag (:,d) - ref(:,d);
    bV = arrayfun(@(x) mean(eV(s==x)), u);   % bias per participant
    bA = arrayfun(@(x) mean(eA(s==x)), u);
    dV = abs(bV - mean(eV));                 % (a) deviation from the overall bias
    dA = abs(bA - mean(eA));
    wV = arrayfun(@(x) std(eV(s==x)), u);    % (b) within-participant standard deviation
    wA = arrayfun(@(x) std(eA(s==x)), u);
    [~, pa] = ttest(dV, dA);
    [~, pb] = ttest(wV, wA);
    fprintf([NL '%s' NL], axName{d});
    fprintf('  per-participant bias deviation   proposed %.1f ± %.1f   AGFormer %.1f ± %.1f   p = %.4f%s', ...
            mean(dV), std(dV), mean(dA), std(dA), pa, NL);
    fprintf('  within-participant error SD      proposed %.1f ± %.1f   AGFormer %.1f ± %.1f   p = %.4f%s', ...
            mean(wV), std(wV), mean(wA), std(wA), pb, NL);
    fprintf('  bias sign agreement              proposed %d/%d   AGFormer %d/%d%s', ...
            max(sum(bV>0), sum(bV<0)), numel(u), ...
            max(sum(bA>0), sum(bA<0)), numel(u), NL);
    rows = [rows; {axName{d}, mean(dV), mean(dA), pa, mean(wV), mean(wA), pb, ...
                   max(sum(bV>0),sum(bV<0)), max(sum(bA>0),sum(bA<0))}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'axis','dev_prop','dev_ag','p_dev', ...
    'within_prop','within_ag','p_within','sign_prop','sign_ag'});
writetable(T, fullfile(OUT, 'R2_10_bias_paired.csv'));
fprintf([NL 'saved: results/R2_10_bias_paired.csv' NL]);
