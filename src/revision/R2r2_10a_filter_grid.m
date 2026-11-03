%% [R2r2-10a] R2r2_10a_filter_grid.m
%  Grid search over the proportional gain, integral gain and accelerometer feedback criterion of a Mahony complementary filter that feeds back the gravity direction only.
%  Output : revision/results/R2r2_10a_filter_grid.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
addpath(genpath(fullfile(fileparts(fileparts(thisDir)), 'GolfSwing_0424')));
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI'); S = R2_07_ORI; n = numel(S);
GRAV = 9.81;
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; 'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

KP = [0.01 0.02 0.05 0.1 0.2 0.5 1 2 5]; KI = [0 0.001 0.01 0.1]; AT = [0.05 0.1 0.2 0.5 Inf];
[a1, a2, a3] = ndgrid(KP, KI, AT);
CFG = [0 0 0; a1(:) a2(:) a3(:)];
nC = size(CFG,1);
sj = arrayfun(@(s) s.subj, S(:));
E = nan(n, 4, nC); U = nan(n, nC);

parfor_ok = ~isempty(ver('parallel'));
for k = 1:n
    st = S(k);
    Ek = nan(4, nC); Uk = nan(1, nC);
    for c = 1:nC
        [Rf, fr] = local_mahony(st.time, st.acc/GRAV, st.gyro, st.add, st.R2tri, CFG(c,1), CFG(c,2), CFG(c,3));
        e = local_err(Rf, st.R2Lw);
        for q = 1:4, Ek(q,c) = mean(e(st.(SEG{q,2}):st.(SEG{q,3}))); end
        Uk(c) = fr;
    end
    E(k,:,:) = reshape(Ek, 1, 4, nC); U(k,:) = Uk;
    if mod(k, 10) == 0, fprintf('%d/%d\n', k, n); end
end

su = unique(sj);
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);
M = nan(nC, 4);
for c = 1:nC, for q = 1:4, M(c,q) = mean(bys(E(:,q,c))); end, end

fprintf('\ngyroscope integration (manuscript) : %s\n', sprintf('%6.2f ', M(1,:)));
fprintf('%d settings searched. best setting per segment (post hoc upper bound on the evaluation data)\n', nC - 1);
rows = {};
for q = 1:4
    [mv, cb] = min(M(2:end, q)); cb = cb + 1;
    [~, p] = ttest(bys(E(:,q,1)), bys(E(:,q,cb)));
    fprintf('  %-13s manuscript %5.2f -> best %5.2f (Kp %.3g, Ki %.3g, accTol %g, feedback %.1f%%)  difference %+.2f, p = %.3f\n', ...
        SEG{q,1}, M(1,q), mv, CFG(cb,1), CFG(cb,2), CFG(cb,3), 100*mean(U(:,cb)), mv - M(1,q), p);
    fprintf('                all segments with that setting : %s\n', sprintf('%6.2f ', M(cb,:)));
end
fprintf('\nsettings with a lower whole-swing error than the manuscript : %d / %d\n', sum(M(2:end,4) < M(1,4)), nC - 1);
fprintf('settings with a lower backswing error than the manuscript : %d / %d (largest improvement %.2f deg)\n', ...
    sum(M(2:end,1) < M(1,1)), nC - 1, M(1,1) - min(M(2:end,1)));
T = array2table([CFG M mean(U,1,'omitnan')'], 'VariableNames', ...
    {'Kp','Ki','accTol','Backswing','Downswing','FollowThrough','EntireSwing','fbFraction'});
writetable(T, fullfile(RES, 'R2r2_10a_filter_grid.csv'));

function e = local_err(Ra, Rb)
    N = size(Ra,3); e = nan(N,1);
    for t = 1:N
        e(t) = acosd(min(1, max(-1, (trace(Ra(:,:,t)' * Rb(:,:,t)) - 1)/2)));
    end
end

function [Rinf, frac] = local_mahony(time, a, w, ind, Rini, Kp, Ki, accTol)
    N = numel(time); Rinf = zeros(3,3,N);
    for t = 1:ind, Rinf(:,:,t) = Rini; end
    bias = [0;0;0]; gW = [0 0 1]'; used = 0;
    for t = ind+1:N
        dt = time(t) - time(t-1);
        wc = w(t,:)' - bias;
        an = norm(a(t,:));
        if Kp > 0 && abs(an - 1) < accTol && an > 0
            vHat = Rinf(:,:,t-1)' * gW; vMeas = a(t,:)' / an;
            err = cross(vMeas, vHat);
            wc = wc + Kp * err;
            if Ki > 0, bias = bias - Ki * err * dt; end
            used = used + 1;
        end
        th = norm(wc) * dt;
        if th > 0
            K = skew(wc / norm(wc));
            dR = eye(3) + sin(th) * K + (1 - cos(th)) * (K * K);
        else
            dR = eye(3);
        end
        Rinf(:,:,t) = orthogonalization(Rinf(:,:,t-1) * dR);
    end
    frac = used / max(N - ind, 1);
end
