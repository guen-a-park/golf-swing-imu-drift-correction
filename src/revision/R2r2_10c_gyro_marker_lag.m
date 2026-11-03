%% [R2r2-10c] R2r2_10c_gyro_marker_lag.m
%  Time lag between the gyroscope angular speed and the angular speed differentiated from the motion capture marker orientation.
%  Output : revision/results/R2r2_10c_gyro_marker_lag.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI; n = numel(S);
FS = 200; UP = 10; MAXL = 8*UP;
sj = nan(n,1); lag = nan(n,1); rmax = nan(n,1); amp = nan(n,1);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    N = size(st.R2Lw,3);
    wm = nan(N,3);
    for t = 2:N-1
        dR = st.R2Lw(:,:,t)' * (st.R2Lw(:,:,t+1) - st.R2Lw(:,:,t-1)) * FS/2;
        wm(t,:) = [dR(3,2) dR(1,3) dR(2,1)];
    end
    i0 = st.bst; i1 = min(st.imp + 20, N-1);
    g = vecnorm(st.gyro(i0:i1,:), 2, 2);
    m = vecnorm(wm(i0:i1,:), 2, 2);
    if any(~isfinite([g; m])) || numel(g) < 10, continue; end
    tq = (1:1/UP:numel(g))';
    gu = interp1(g, tq, 'spline'); mu = interp1(m, tq, 'spline');
    [c, L] = xcorr(gu - mean(gu), mu - mean(mu), MAXL, 'coeff');
    [rmax(k), ix] = max(c);
    lag(k) = L(ix) / UP / FS * 1000;
    amp(k) = max(g) / max(m);
end

su = unique(sj(isfinite(sj)));
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);
L = bys(lag);
[~, p] = ttest(L);
fprintf('\ntime lag between gyroscope and mocap angular velocity (downswing to impact + 0.1 s)\n');
fprintf('  participant mean %.1f ms (SD %.1f, range %.1f to %.1f), difference from 0 p = %.2g, n = %d\n', ...
    mean(L), std(L), min(L), max(L), p, numel(L));
fprintf('  maximum correlation %.3f, peak magnitude ratio (gyroscope/mocap) %.2f\n', mean(bys(rmax)), mean(bys(amp)));
fprintf('  trials with lag > 0 : %.0f %%\n', 100*mean(lag > 0, 'omitnan'));
writetable(table(su, L, bys(rmax), bys(amp), 'VariableNames', ...
    {'subj','lag_ms','rmax','peak_ratio'}), fullfile(RES, 'R2r2_10c_gyro_marker_lag.csv'));
