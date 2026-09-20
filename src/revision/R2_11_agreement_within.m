%% [R2-10 / R2-11] R2_11_agreement_within.m
%  recomputes the agreement-rate correlation of Figure 6D while respecting the repeated measures structure.
%
%  the manuscript pooled all participants and trials and reported R = 0.86. This has the same structure as
%  the issue raised about the constraint estimate in [A10], so the per-trial agreement rate is recomputed
%  and both the pooled correlation and the within-participant correlation are calculated.
%
%  agreement rate : the proportion of fast swing trajectory points that fall inside the mean +/- 2 SD band of the preferred swing.
%           averaged over the X, Y, Z axes. As in the manuscript, the interval from -1.4 s relative to impact up to impact.
%
%  Run first : R2_11_draw_figure5_copy.m  (results/R2_11_trajectory_store.mat)
%  Output    : revision/results/R2_11_agreement_within.csv
%
%  2026-09-05
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
load(fullfile(OUT, 'R2_11_trajectory_store.mat'), 'R2_11_store');

NSIGMA = 2;
WIN    = [-280 0];          % the same evaluation interval as Figure 6 of the manuscript
NL     = char(10);

subj = []; agrRef = []; agrEst = [];

for s = 1:numel(R2_11_store)
    st = R2_11_store(s);
    if isempty(st) || isempty(st.ref) || isempty(st.ref_fast), continue; end

    ref  = st.ref  * 0.1;  prop  = st.prop  * 0.1;      % preferred, cm
    refF = st.ref_fast * 0.1;  propF = st.prop_fast * 0.1;   % fast, cm

    imp = round(mean(double(st.imp)));
    idx = max(1, imp + WIN(1)) : min(size(ref,1), imp + WIN(2));

    % build the per-axis band from the preferred swing (for the reference and for the estimate separately)
    mRef = mean(ref (idx,:,:), 3);  sRef = std(ref (idx,:,:), 0, 3);
    mEst = mean(prop(idx,:,:), 3);  sEst = std(prop(idx,:,:), 0, 3);

    for t = 1:size(refF, 3)
        inRef = zeros(1,3); inEst = zeros(1,3);
        for d = 1:3
            xR = refF (idx,d,t);  xE = propF(idx,d,t);
            inRef(d) = mean(abs(xR - mRef(:,d)) <= NSIGMA * sRef(:,d));
            inEst(d) = mean(abs(xE - mEst(:,d)) <= NSIGMA * sEst(:,d));
        end
        subj(end+1,1)   = st.subj;           %#ok<SAGROW>
        agrRef(end+1,1) = mean(inRef) * 100; %#ok<SAGROW>
        agrEst(end+1,1) = mean(inEst) * 100; %#ok<SAGROW>
    end
end

%% ===== pooled correlation =====
[Rp, Pp] = corr(agrRef, agrEst);
fprintf([NL 'pooled correlation (%d trials, %d participants)' NL], numel(subj), numel(unique(subj)));
fprintf('  R = %.2f, p = %.4g%s', Rp, Pp, NL);

%% ===== within-participant correlation (correlation after subtracting each participant's mean) =====
u = unique(subj);
cRef = agrRef; cEst = agrEst;
for k = 1:numel(u)
    m = subj == u(k);
    cRef(m) = cRef(m) - mean(cRef(m));
    cEst(m) = cEst(m) - mean(cEst(m));
end
df = numel(subj) - numel(u) - 1;
Rw = sum(cRef .* cEst) / sqrt(sum(cRef.^2) * sum(cEst.^2));
tw = Rw * sqrt(df / (1 - Rw^2));
Pw = 2 * (1 - tcdf(abs(tw), df));
fprintf([NL 'within-participant correlation (repeated measures correlation)' NL]);
fprintf('  R = %.2f, p = %.4g, df = %d%s', Rw, Pw, df, NL);

%% ===== correlation between participant means (between-participant component) =====
mRefS = arrayfun(@(x) mean(agrRef(subj==x)), u);
mEstS = arrayfun(@(x) mean(agrEst(subj==x)), u);
[Rb, Pb] = corr(mRefS, mEstS);
fprintf([NL 'between-participant correlation (%d participant means)' NL], numel(u));
fprintf('  R = %.2f, p = %.4g%s', Rb, Pb, NL);

%% ===== save =====
T = table(subj, agrRef, agrEst, 'VariableNames', {'subj','agree_mocap','agree_est'});
writetable(T, fullfile(OUT, 'R2_11_agreement_within.csv'));
S = table({'pooled';'within';'between'}, [Rp;Rw;Rb], [Pp;Pw;Pb], ...
          'VariableNames', {'type','R','p'});
writetable(S, fullfile(OUT, 'R2_11_agreement_within_summary.csv'));
fprintf([NL 'saved: results/R2_11_agreement_within.csv' NL]);
