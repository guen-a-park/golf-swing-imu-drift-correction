%% [R2r2-10c] R2r2_10c_gyro_scale.m
%  Ratio of the gyroscope to the motion capture angular speed during the downswing, excluding saturated trials.
%  Output : console

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI'); S = R2_07_ORI; n = numel(S);
load(fullfile(RES, 'gyro_saturation_mask.mat'), 'satFlag');
FS = 200; BIN = [0 5 10 15 20 25 40];
sj = nan(n,1); rInt = nan(n,1); rb = nan(n, numel(BIN)-1);
for k = 1:n
    st = S(k);
    if satFlag(st.subj).clubN(1).trialN(st.trial), continue; end
    sj(k) = st.subj; N = size(st.R2Lw,3); wm = nan(N,3);
    for t = 2:N-1
        dR = st.R2Lw(:,:,t)' * (st.R2Lw(:,:,t+1) - st.R2Lw(:,:,t-1)) * FS/2;
        wm(t,:) = [dR(3,2) dR(1,3) dR(2,1)];
    end
    ii = st.bst:(st.imp-5);
    g = vecnorm(st.gyro(ii,:),2,2); m = vecnorm(wm(ii,:),2,2);
    rInt(k) = sum(g)/sum(m);
    for b = 1:numel(BIN)-1
        s = m >= BIN(b) & m < BIN(b+1);
        if nnz(s) >= 3, rb(k,b) = sum(g(s))/sum(m(s)); end
    end
end
su = unique(sj(isfinite(sj)));
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);
R = bys(rInt); [~, p] = ttest(R - 1);
fprintf('%d non-saturated trials, %d participants\n', sum(isfinite(sj)), numel(su));
fprintf('downswing integrated angular velocity ratio (gyroscope/mocap) %.3f (SD %.3f), difference from 1 p = %.2g\n', mean(R), std(R), p);
for b = 1:numel(BIN)-1
    v = bys(rb(:,b)); v = v(isfinite(v));
    if numel(v) > 2, [~, pb] = ttest(v - 1); else, pb = NaN; end
    fprintf('  |w| %2d-%2d rad/s : %.3f (n=%d, p=%.2g)\n', BIN(b), BIN(b+1), mean(v), numel(v), pb);
end
