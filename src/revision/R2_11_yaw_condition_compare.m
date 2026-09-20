%% [R2-11] R2_11_yaw_condition_compare.m
%  Compares how the consistency analysis results change when the initial yaw reference is changed.
%
%  Before : preferred uses magnetometer heading, fast uses motion capture heading (mismatched reference)
%  After  : both conditions use motion capture heading (matched reference)
%
%  fast condition wore a second device on the same wrist, which disturbed the magnetometer, so
%  no magnetometer heading is available. Aligning the preferred condition that forms the band to the same reference
%  is the way to compare the two groups in the same frame.
%
%  Compared    : band width, reconstruction error, agreement rate and its correlation (intraclass / within-participant)
%  Output      : revision/results/R2_11_yaw_condition_compare.csv
%
%  2026-09-07
%% ========================================================================

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
NL  = char(10);

FILES = {'R2_11_trajectory_store.mat', 'R2_11_trajectory_store_yawmocap.mat'};
NAME  = {'before (band magnetometer / fast mocap)', 'after (both mocap yaw) yaw)'};
NSIG = 2;  WIN = [-280 0];
rows = {};

for f = 1:2
    L = load(fullfile(OUT, FILES{f}), 'R2_11_store');
    S = L.R2_11_store;
    subj = []; aR = []; aE = [];
    bM = []; bE = []; re_ = []; bs = [];
    for s = 1:numel(S)
        st = S(s);
        if isempty(st) || isempty(st.ref) || isempty(st.ref_fast), continue; end
        imp = round(mean(double(st.imp)));
        idx = max(1, imp + WIN(1)) : min(size(st.ref,1), imp + WIN(2));
        refP = st.ref * 0.1;  estP = st.prop * 0.1;
        refF = st.ref_fast * 0.1;  estF = st.prop_fast * 0.1;

        mR = mean(refP(idx,:,:), 3);  sR = std(refP(idx,:,:), 0, 3);
        mE = mean(estP(idx,:,:), 3);  sE = std(estP(idx,:,:), 0, 3);

        for d = 1:3
            bM(end+1,1) = mean(2*NSIG*sR(:,d));  %#ok<SAGROW>
            bE(end+1,1) = mean(2*NSIG*sE(:,d));  %#ok<SAGROW>
            re_(end+1,1) = sqrt(mean(mean((refP(idx,d,:) - estP(idx,d,:)).^2))); %#ok<SAGROW>
            bs(end+1,1) = d;                      %#ok<SAGROW>
        end
        for t = 1:size(refF,3)
            iR = zeros(1,3); iE = zeros(1,3);
            for d = 1:3
                iR(d) = mean(abs(refF(idx,d,t) - mR(:,d)) <= NSIG*sR(:,d));
                iE(d) = mean(abs(estF(idx,d,t) - mE(:,d)) <= NSIG*sE(:,d));
            end
            subj(end+1,1) = st.subj;             %#ok<SAGROW>
            aR(end+1,1) = mean(iR)*100;          %#ok<SAGROW>
            aE(end+1,1) = mean(iE)*100;          %#ok<SAGROW>
        end
    end

    u = unique(subj);
    x = arrayfun(@(v) mean(aR(subj==v)), u);
    y = arrayfun(@(v) mean(aE(subj==v)), u);
    [ic, lo, hi, pi_] = local_icc(x, y);
    [Rw, Pw] = local_within(aR, aE, subj);
    [~, pb] = ttest(x, y);

    fprintf([NL '===== %s =====' NL], NAME{f});
    ax = {'X','Y','Z'};
    for d = 1:3
        fprintf('  %s  motion capture band %5.1f   IMU band %5.1f   ratio %.1f   recon err %5.1f%s', ...
                ax{d}, mean(bM(bs==d)), mean(bE(bs==d)), ...
                mean(bE(bs==d))/mean(bM(bs==d)), mean(re_(bs==d)), NL);
    end
    fprintf('  agreement   motion capture %.1f %%   IMU %.1f %%   diff %+.1f %%p (p = %.3f)%s', ...
            mean(x), mean(y), mean(y)-mean(x), pb, NL);
    fprintf('  intraclass corr %.2f [%.2f, %.2f] (p = %.4g)   within-participant corr %.2f (p = %.4g)%s', ...
            ic, lo, hi, pi_, Rw, Pw, NL);
    rows = [rows; {NAME{f}, mean(x), mean(y), mean(y)-mean(x), pb, ic, lo, hi, pi_, Rw, Pw}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'condition','agree_mocap','agree_imu','bias', ...
    'p_bias','ICC','ICC_lo','ICC_hi','p_ICC','within_r','p_within'});
writetable(T, fullfile(OUT, 'R2_11_yaw_condition_compare.csv'));
fprintf([NL 'saved: results/R2_11_yaw_condition_compare.csv' NL]);

%% ===== helper functions =====
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
function [Rw, Pw] = local_within(x, y, s)
    u = unique(s); cx = x; cy = y;
    for k = 1:numel(u)
        m = s == u(k);
        cx(m) = cx(m) - mean(cx(m));
        cy(m) = cy(m) - mean(cy(m));
    end
    df = numel(x) - numel(u) - 1;
    Rw = sum(cx.*cy) / sqrt(sum(cx.^2)*sum(cy.^2));
    tw = Rw * sqrt(df / (1 - Rw^2));
    Pw = 2 * (1 - tcdf(abs(tw), df));
end
