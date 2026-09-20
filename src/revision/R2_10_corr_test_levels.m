%% [R2-10] R2_10_corr_test_levels.m
%  Redoes the correlation test the manuscript used against MotionAGFormer, accounting for the repeated-measures structure.
%
%  The manuscript applied the Hotelling-Williams test to the pooled-trial correlation. That treats the several
%  trials from one participant as independent samples, so the degrees of freedom are inflated.
%  The same test is repeated on participant means and both results are presented together.
%
%  Data   : driver evaluation set (same test trials as the manuscript)
%  Output : revision/results/R2_10_corr_test_levels.csv
%
%  2026-09-05
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);
ref = [M.Dref_x M.Dref_y M.Dref_z] / 10;
ag  = [M.Dag_x  M.Dag_y  M.Dag_z ] / 10;
vid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
ok  = all(isfinite([ref ag vid]), 2);
ref = ref(ok,:); ag = ag(ok,:); vid = vid(ok,:);
s = M.subj(ok); u = unique(s);
ax = {'X (fore-aft)','Y (lateral)','Z (vertical)'};

fprintf([NL 'driver evaluation, %d trials, %d participants' NL], size(ref,1), numel(u));
fprintf([NL '                 pooled trials (manuscript)  participant mean' NL]);
fprintf(['axis          r_prop r_ag      t      p     r_prop r_ag      t      p' NL]);

rows = {};
for d = 1:3
    r12 = corr(ref(:,d), vid(:,d));
    r13 = corr(ref(:,d), ag (:,d));
    r23 = corr(vid(:,d), ag (:,d));
    [t1, p1] = local_hw(r12, r13, r23, size(ref,1));

    a = arrayfun(@(x) mean(ref(s==x,d)), u);
    b = arrayfun(@(x) mean(vid(s==x,d)), u);
    c = arrayfun(@(x) mean(ag (s==x,d)), u);
    q12 = corr(a,b); q13 = corr(a,c); q23 = corr(b,c);
    [t2, p2] = local_hw(q12, q13, q23, numel(u));

    fprintf('%-10s  %.2f  %.2f  %6.2f %6.4f     %.2f  %.2f  %6.2f %6.4f%s', ...
            ax{d}, r12, r13, t1, p1, q12, q13, t2, p2, NL);
    rows = [rows; {ax{d}, r12, r13, t1, p1, q12, q13, t2, p2}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'axis','r_prop_trial','r_ag_trial','t_trial', ...
    'p_trial','r_prop_subj','r_ag_subj','t_subj','p_subj'});
writetable(T, fullfile(OUT, 'R2_10_corr_test_levels.csv'));
fprintf([NL 'saved: results/R2_10_corr_test_levels.csv' NL]);

function [t, p] = local_hw(r12, r13, r23, n)
% Williams(1959) / Steiger(1980) : test of the difference between two correlations sharing a common variable
    R  = 1 - r12^2 - r13^2 - r23^2 + 2*r12*r13*r23;
    rb = (r12 + r13) / 2;
    df = n - 3;
    t  = (r12 - r13) * sqrt((n - 1) * (1 + r23)) / ...
         sqrt(2*(n-1)/(n-3) * R + rb^2 * (1 - r23)^3);
    p  = 2 * (1 - tcdf(abs(t), df));
end
