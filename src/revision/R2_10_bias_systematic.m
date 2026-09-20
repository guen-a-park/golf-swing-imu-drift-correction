%% [R2-10] R2_10_bias_systematic.m
%  Determines whether the constraint error of the two methods is a systematic bias or an error varying by participant.
%
%  The error e = D_est - D_ref is decomposed into three components.
%     (1) common bias   : the same value for every participant
%     (2) participant part : how far the per-participant mean deviates from the common bias
%     (3) trial part: the part varying by trial within a participant
%
%  If it is a systematic bias, (1) dominates and its sign is consistent across participants, and once the cause is known
%  it can be removed. If the error varies by participant, (2) is large, which distorts between-participant comparison
%  and cannot be removed without knowing the reference value.
%
%  Target : 99 trials of the driver test set
%  Output : revision/results/R2_10_bias_systematic.csv
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
axName = {'X (ant-post)','Y (med-lat)','Z (vertical)'};

rows = {};
for nm = {'D_Vision', 'D_AGFormer'}
    est = vid; if strcmp(nm{1}, 'D_AGFormer'), est = ag; end
    fprintf([NL '===== %s =====' NL], nm{1});
    fprintf(['%-10s %8s %8s %8s   %10s %10s %10s   %s' NL], 'Axis', ...
            'Common', 'Participant', 'Trial', 'Common %', 'Particip. %', 'Trial %', 'Sign match');
    for d = 1:3
        e  = est(:,d) - ref(:,d);
        b0 = mean(e);                                   % (1) common bias
        ms = arrayfun(@(x) mean(e(s==x)), u);           % per-participant mean
        sS = std(ms - b0, 1);                           % (2)
        sT = mean(arrayfun(@(x) std(e(s==x), 1), u));   % (3)
        tot = b0^2 + sS^2 + sT^2;
        nsign = max(sum(ms > 0), sum(ms < 0));
        fprintf('%-10s %+8.1f %8.1f %8.1f   %9.0f%% %9.0f%% %9.0f%%   %d/%d%s', ...
                axName{d}, b0, sS, sT, 100*b0^2/tot, 100*sS^2/tot, 100*sT^2/tot, ...
                nsign, numel(u), NL);
        rows = [rows; {nm{1}, axName{d}, b0, sS, sT, ...
                       100*b0^2/tot, 100*sS^2/tot, 100*sT^2/tot, nsign}]; %#ok<AGROW>
    end
    % how much the 3D error decreases when the common bias is removed
    e3  = est - ref;
    r0  = mean(vecnorm(e3, 2, 2));
    r1  = mean(vecnorm(e3 - mean(e3, 1), 2, 2));
    fprintf(['%-10s 3D error %.1f cm -> %.1f cm after removing the common bias (%.0f%% reduction)' NL], ...
            '', r0, r1, 100*(r0-r1)/r0);
end

T = cell2table(rows, 'VariableNames', {'method','axis','common_cm','subject_sd_cm', ...
    'trial_sd_cm','common_pct','subject_pct','trial_pct','sign_agree'});
writetable(T, fullfile(OUT, 'R2_10_bias_systematic.csv'));
fprintf([NL 'saved: results/R2_10_bias_systematic.csv' NL]);
