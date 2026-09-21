%% [R2-10] R2_10_table_figure3.m
%  Figure 3 : builds the corresponding manuscript table.
%  Output : revision/results/R2_10_table_figure3.csv

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
axName = {'X (anteroposterior)','Y (mediolateral)','Z (vertical)'};

fprintf([NL '%-16s %-22s %10s %10s %18s %20s' NL], ...
        'Method', 'Axis', 'MAE', 'Bias', 'LoA', 'ICC [95% CI]');
rows = {};
for nm = {'Proposed','MotionAGFormer'}
    est = vid; if strcmp(nm{1}, 'MotionAGFormer'), est = ag; end
    for d = 1:3
        e   = est(:,d) - ref(:,d);
        mae = arrayfun(@(x) mean(abs(e(s==x))), u);
        bi  = arrayfun(@(x) mean(e(s==x)),      u);
        lo  = mean(bi) - 1.96*std(bi);  hi = mean(bi) + 1.96*std(bi);
        a   = arrayfun(@(x) mean(ref(s==x,d)), u);
        b   = arrayfun(@(x) mean(est(s==x,d)), u);
        [ic, cl, ch, p] = local_icc(a, b);
        fprintf('%-16s %-22s %6.1f±%3.1f %+10.1f %8.1f to %5.1f %8.2f [%.2f, %.2f]%s%s', ...
                nm{1}, axName{d}, mean(mae), std(mae), mean(bi), lo, hi, ...
                ic, cl, ch, local_star(p), NL);
        rows = [rows; {nm{1}, axName{d}, mean(mae), std(mae), mean(bi), lo, hi, ic, cl, ch, p}]; %#ok<AGROW>
    end
end

T = cell2table(rows, 'VariableNames', {'method','axis','MAE','MAE_sd','bias', ...
    'LoA_lo','LoA_hi','ICC','ICC_lo','ICC_hi','ICC_p'});
writetable(T, fullfile(OUT, 'R2_10_table_figure3.csv'));
fprintf([NL '* p < 0.05   ** p < 0.01' NL 'saved: results/R2_10_table_figure3.csv' NL]);

%% helper functions
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
    if p < 0.001, s = '***'; elseif p < 0.01, s = '**'; elseif p < 0.05, s = '*'; else, s = ''; end
end
