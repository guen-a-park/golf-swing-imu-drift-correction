%% [R2-10] R2_10_discriminability.m
%  Tests "does the estimate discriminate between participants" with standard metrics.
%
%  The between-participant Pearson correlation rests on only 10 participant means, so it is weak evidence.
%  The following two are reported together for the same question.
%
%   (1) intraclass correlation coefficient ICC(C,1) : between-participant agreement of estimate and reference value.
%       It ignores a constant bias and looks only at relative order and spacing. Since the constraint is meant
%       to discriminate between participants, the consistency form is appropriate.
%
%   (2) F from one-way ANOVA : is the estimate itself separated by participant.
%       It checks whether the between-participant variance is large relative to trial noise. Without separation,
%       whatever is estimated cannot serve as a participant-specific constraint.
%
%  Target : driver evaluation set, 99 trials
%  Output : revision/results/R2_10_discriminability.csv
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

fprintf([NL '(1) ICC(C,1) : between-participant agreement of estimate and reference value (%d participant means)' NL], numel(u));
fprintf(['%-10s %22s %22s' NL], 'axis', 'proposed method', 'MotionAGFormer');
rows = {};
for d = 1:3
    a = arrayfun(@(x) mean(ref(s==x,d)), u);
    b = arrayfun(@(x) mean(vid(s==x,d)), u);
    c = arrayfun(@(x) mean(ag (s==x,d)), u);
    [i1, l1, h1, p1] = local_icc(a, b);
    [i2, l2, h2, p2] = local_icc(a, c);
    fprintf('%-10s  %.2f [%.2f, %.2f] p=%.3f   %.2f [%.2f, %.2f] p=%.3f%s', ...
            axName{d}, i1, l1, h1, p1, i2, l2, h2, p2, NL);
    rows = [rows; {'ICC', axName{d}, i1, p1, i2, p2}]; %#ok<AGROW>
end

fprintf([NL '(2) one-way ANOVA : is the estimate separated by participant' NL]);
fprintf(['%-10s %26s %26s' NL], 'axis', 'proposed method', 'MotionAGFormer');
for d = 1:3
    [f1, q1, e1] = local_anova(vid(:,d), s);
    [f2, q2, e2] = local_anova(ag (:,d), s);
    fprintf('%-10s  F=%6.2f p=%.2g eta2=%.2f    F=%6.2f p=%.2g eta2=%.2f%s', ...
            axName{d}, f1, q1, e1, f2, q2, e2, NL);
    rows = [rows; {'ANOVA', axName{d}, f1, q1, f2, q2}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'index','axis','prop','p_prop','ag','p_ag'});
writetable(T, fullfile(OUT, 'R2_10_discriminability.csv'));
fprintf([NL 'saved: results/R2_10_discriminability.csv' NL]);

%% ===== helper functions =====
function [icc, lo, hi, p] = local_icc(x, y)
% ICC(C,1) : two-way mixed, consistency, single measure
    Y = [x(:) y(:)]; [n, k] = size(Y);
    gm = mean(Y(:));
    MSR = k * sum((mean(Y,2) - gm).^2) / (n-1);            % rows (participants)
    MSC = n * sum((mean(Y,1) - gm).^2) / (k-1);            % columns (measurements)
    MSE = (sum((Y(:) - gm).^2) - (n-1)*MSR - (k-1)*MSC) / ((n-1)*(k-1));
    icc = (MSR - MSE) / (MSR + (k-1)*MSE);
    F   = MSR / MSE;  df1 = n-1;  df2 = (n-1)*(k-1);
    p   = 1 - fcdf(F, df1, df2);
    fL  = F / finv(0.975, df1, df2);  fU = F * finv(0.975, df2, df1);
    lo  = (fL - 1) / (fL + k - 1);    hi = (fU - 1) / (fU + k - 1);
end
function [F, p, eta2] = local_anova(v, s)
    u = unique(s); gm = mean(v);
    ssb = sum(arrayfun(@(x) sum(s==x) * (mean(v(s==x)) - gm)^2, u));
    ssw = sum(arrayfun(@(x) sum((v(s==x) - mean(v(s==x))).^2), u));
    df1 = numel(u) - 1;  df2 = numel(v) - numel(u);
    F = (ssb/df1) / (ssw/df2);
    p = 1 - fcdf(F, df1, df2);
    eta2 = ssb / (ssb + ssw);
end
