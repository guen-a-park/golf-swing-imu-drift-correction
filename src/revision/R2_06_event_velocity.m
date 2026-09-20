%% [R2-6] R2_06_event_velocity.m
%  Reviewer 2, Comment R2-6 response
%  ------------------------------------------------------------------------
%  "zero velocity constraint" was pointed out as an imprecise expression, so
%  the actual motion capture wrist velocity at ADD / BST / FIN is measured and reported.
%  (the manuscript wording will be revised to "approximate zero-velocity assumption")
%
%  Prerequisite : R2_common_mocap_extract.m
%  Output      : revision/results/R2_06_event_velocity.csv
%
%  2026-08-28
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT_DIR = fullfile(thisDir, 'results');
load(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M');

CLUB_SEL = 1;                 % 1 = driver (target of the original analysis)
m = M.club == CLUB_SEL;
Msel = M(m, :);

events = {'ADD', 'BST', 'FIN'};
comps  = {'x', 'y', 'z', 'norm'};

%% ===== participant-level aggregation (reflects the repeated-measures structure, R2-10 direction) =====
subjList = unique(Msel.subj);
nS = numel(subjList);

rows = {};
for e = 1:numel(events)
    for c = 1:numel(comps)
        col = sprintf('v%s_%s', events{e}, comps{c});
        v   = Msel.(col) / 1000;                 % mm/s -> m/s

        % trial level
        tr_mean = mean(v, 'omitnan');
        tr_sd   = std(v, 'omitnan');

        % participant level (per-participant mean -> between-participant mean ± SD)
        sm = nan(nS, 1);
        for s = 1:nS
            sm(s) = mean(v(Msel.subj == subjList(s)), 'omitnan');
        end
        sj_mean = mean(sm, 'omitnan');
        sj_sd   = std(sm, 'omitnan');

        % magnitude-based summary (prevents sign cancellation)
        abs_mean = mean(abs(v), 'omitnan');
        abs_max  = max(abs(v));

        rows(end+1,:) = {events{e}, comps{c}, tr_mean, tr_sd, sj_mean, sj_sd, ...
            abs_mean, abs_max, numel(v), nS}; %#ok<SAGROW>
    end
end

T = cell2table(rows, 'VariableNames', {'event', 'component', ...
    'trial_mean', 'trial_sd', 'subj_mean', 'subj_sd', ...
    'mean_abs', 'max_abs', 'nTrial', 'nSubj'});
writetable(T, fullfile(OUT_DIR, 'R2_06_event_velocity.csv'));

%% ===== console output =====
fprintf('\n============ [R2-6] Wrist velocity at swing events (m/s) ============\n');
fprintf('driver, %d trials / %d subjects, motion capture, 5-point derivative + 15 Hz LPF\n\n', ...
    height(Msel), nS);
fprintf('%-6s %-6s %18s %18s %10s %10s\n', 'Event', 'Comp', ...
    'trial-level m±SD', 'subject-level m±SD', 'mean|v|', 'max|v|');
for r = 1:height(T)
    fprintf('%-6s %-6s %8.3f ± %-7.3f %8.3f ± %-7.3f %10.3f %10.3f\n', ...
        T.event{r}, T.component{r}, T.trial_mean(r), T.trial_sd(r), ...
        T.subj_mean(r), T.subj_sd(r), T.mean_abs(r), T.max_abs(r));
end

%% ===== reference : velocity at impact (for scale comparison with a non-zero instant) =====
vimp = Msel.vIMP_norm / 1000;
fprintf('\n[Ref] |v| at IMP : %.2f ± %.2f m/s (max %.2f)\n', ...
    mean(vimp, 'omitnan'), std(vimp, 'omitnan'), max(vimp));
fprintf('       ADD/BST/FIN |v| is %.1f%% / %.1f%% / %.1f%% of that at impact\n', ...
    100*mean(Msel.vADD_norm, 'omitnan')/mean(Msel.vIMP_norm, 'omitnan'), ...
    100*mean(Msel.vBST_norm, 'omitnan')/mean(Msel.vIMP_norm, 'omitnan'), ...
    100*mean(Msel.vFIN_norm, 'omitnan')/mean(Msel.vIMP_norm, 'omitnan'));

fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_06_event_velocity.csv'));
fprintf('=====================================================================\n');
