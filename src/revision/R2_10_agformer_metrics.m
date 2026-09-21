%% [R2-10] R2_10_agformer_metrics.m
%  Compares the accuracy of the video-based constraint with MotionAGFormer using the same metrics.
%  Output : revision/results/R2_10_agformer_metrics.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

M = readtable(fullfile(OUT, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

ref = [M.Dref_x M.Dref_y M.Dref_z] / 10;      % mm -> cm
ag  = [M.Dag_x  M.Dag_y  M.Dag_z ] / 10;
vid = [M.Dvid_x M.Dvid_y M.Dvid_z] / 10;
ok  = all(isfinite([ref ag vid]), 2);
ref = ref(ok,:); ag = ag(ok,:); vid = vid(ok,:); subj = M.subj(ok);
u = unique(subj);
axName = {'X (fore-aft)','Y (lateral)','Z (vertical)'};

fprintf([NL 'driver evaluation, %d trials, %d participants' NL], size(ref,1), numel(u));

rows = {};
for name = {'MotionAGFormer', 'proposed method'}
    est = ag; if strcmp(name{1}, 'proposed method'), est = vid; end
    fprintf([NL '===== %s =====' NL], name{1});
    for d = 1:3
        e = est(:,d) - ref(:,d);
        mae  = arrayfun(@(x) mean(abs(e(subj==x))), u);
        bias = arrayfun(@(x) mean(    e(subj==x) ), u);
        rmse = sqrt(mean(arrayfun(@(x) mean(e(subj==x).^2), u)));
        [Rp, Pp] = corr(ref(:,d), est(:,d));
        [Rw, Pw] = local_within(ref(:,d), est(:,d), subj);
        fprintf(['  %-9s MAE %4.1f +/- %3.1f   RMSE %4.1f   bias %+5.1f   ' ...
                 'pooled R %+.2f   within-subject R %+.2f (p = %.3f)' NL], ...
                axName{d}, mean(mae), std(mae), rmse, mean(bias), Rp, Rw, Pw);
        rows = [rows; {name{1}, axName{d}, mean(mae), std(mae), rmse, ...
                       mean(bias), Rp, Pp, Rw, Pw}]; %#ok<AGROW>
    end
    n3 = vecnorm(est - ref, 2, 2);
    m3 = arrayfun(@(x) mean(n3(subj==x)), u);
    fprintf(['  %-9s 3D magnitude %4.1f +/- %3.1f' NL], '', mean(m3), std(m3));
    rows = [rows; {name{1}, '3D magnitude', mean(m3), std(m3), NaN, NaN, NaN, NaN, NaN, NaN}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'method','axis','MAE','MAE_sd','RMSE', ...
                                       'bias','R_pooled','p_pooled','R_within','p_within'});
writetable(T, fullfile(OUT, 'R2_10_agformer_metrics.csv'));
fprintf([NL 'saved: results/R2_10_agformer_metrics.csv' NL]);

function [Rw, Pw] = local_within(x, y, subj)
    u = unique(subj); cx = x; cy = y;
    for k = 1:numel(u)
        m = subj == u(k);
        cx(m) = cx(m) - mean(cx(m));
        cy(m) = cy(m) - mean(cy(m));
    end
    df = numel(x) - numel(u) - 1;
    Rw = sum(cx .* cy) / sqrt(sum(cx.^2) * sum(cy.^2));
    tw = Rw * sqrt(df / (1 - Rw^2));
    Pw = 2 * (1 - tcdf(abs(tw), df));
end
