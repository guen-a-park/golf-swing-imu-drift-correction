%% [R2r2-10a] R2r2_10a_filter_grid_marg_wide.m
%  Same as R2r2_10a_filter_grid_marg.m over a wider gain range, because the first optimum lay on the boundary of the grid.
%  Output : revision/results/R2r2_10a_filter_grid_marg_wide.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results'); baseDir = fileparts(thisDir);
addpath(genpath(fullfile(fileparts(baseDir), 'GolfSwing_0424')));
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI'); S = R2_07_ORI; n = numel(S);
D = load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'));
fn = fieldnames(D); SW = D.(fn{1});
MAG = cell(n,1); bad = 0;
for k = 1:n
    g = SW(S(k).subj).clubN(1).trialN(S(k).trial);
    MAG{k} = g.apdm(:,7:9);
    if size(g.apdm,1) ~= size(S(k).acc,1) || max(abs(g.apdm(:,1:3) - S(k).acc), [], 'all') > 1e-9
        bad = bad + 1;
    end
end
fprintf('magnetometer alignment check : mismatched %d / %d\n', bad, n);
clear D SW

GRAV = 9.81;
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; 'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
[a1,a2,a3,a4,a5] = ndgrid([0 0.5 1 2 5 10], [0 2 5 10 20 50 100], [0 0.01], [Inf], [0.1 Inf]);
C = [a1(:) a2(:) a3(:) a4(:) a5(:)];
C(C(:,1) == 0, 4) = Inf; C(C(:,2) == 0, 5) = Inf;
C = unique(C, 'rows', 'stable');
C = C(~(C(:,1) == 0 & C(:,2) == 0 & C(:,3) > 0), :);
i0 = find(all(C(:,1:3) == 0, 2), 1); C = C([i0, setdiff(1:size(C,1), i0)], :);
nC = size(C,1); fprintf('%d settings\n', nC);

sj = arrayfun(@(s) s.subj, S(:));
E = nan(n,4,nC); Y = nan(n,4,nC);
for k = 1:n
    st = S(k); m = MAG{k};
    mA = m(st.add,:)'; mref = st.R2tri * (mA / norm(mA));
    u = mref(1:2) / norm(mref(1:2)); mAn = norm(mA);
    Ek = nan(4,nC); Yk = nan(4,nC);
    for c = 1:nC
        R = local_marg(st.time, st.acc/GRAV, st.gyro, m, st.add, st.R2tri, C(c,:), u, mAn);
        [e, y] = local_err(R, st.R2Lw);
        for q = 1:4
            ii = st.(SEG{q,2}):st.(SEG{q,3});
            Ek(q,c) = mean(e(ii)); Yk(q,c) = mean(y(ii));
        end
    end
    E(k,:,:) = reshape(Ek,1,4,nC); Y(k,:,:) = reshape(Yk,1,4,nC);
    if mod(k,10) == 0, fprintf('%d/%d\n', k, n); end
end

su = unique(sj);
bys = @(v) arrayfun(@(x) mean(v(sj == x), 'omitnan'), su);
M = nan(nC,4); MY = nan(nC,4);
for c = 1:nC, for q = 1:4, M(c,q) = mean(bys(E(:,q,c))); MY(c,q) = mean(bys(Y(:,q,c))); end, end
fprintf('\ngyroscope only : %s  (yaw %s)\n', sprintf('%5.2f ', M(1,:)), sprintf('%5.2f ', MY(1,:)));
for q = 1:4
    [mv, cb] = min(M(2:end,q)); cb = cb + 1;
    [~, p] = ttest(bys(E(:,q,1)), bys(E(:,q,cb)));
    fprintf('%-13s %5.2f -> %5.2f (Kp %g Km %g Ki %g accTol %g magTol %g) p = %.3f\n', SEG{q,1}, M(1,q), mv, C(cb,:), p);
    fprintf('              all segments %s | yaw %s\n', sprintf('%5.2f ', M(cb,:)), sprintf('%5.2f ', MY(cb,:)));
end
fprintf('magnetometer feedback settings (Km>0) with a lower whole-swing error than the manuscript : %d / %d\n', ...
    sum(M(C(:,2) > 0, 4) < M(1,4)), sum(C(:,2) > 0));
writetable(array2table([C M MY], 'VariableNames', {'Kp','Km','Ki','accTol','magTol', ...
    'Backswing','Downswing','FollowThrough','EntireSwing','yawBS','yawDS','yawFT','yawES'}), ...
    fullfile(RES, 'R2r2_10a_filter_grid_marg_wide.csv'));

function [e, y] = local_err(Ra, Rb)
    N = size(Ra,3); e = nan(N,1); y = nan(N,1);
    for t = 1:N
        Rd = Ra(:,:,t) * Rb(:,:,t)';
        e(t) = acosd(min(1, max(-1, (trace(Rd) - 1)/2)));
        eul = rotm2eul(Rd, 'ZYX'); y(t) = abs(rad2deg(eul(1)));
    end
end

function R = local_marg(time, a, w, m, ind, Rini, P, u, mAn)
    Kp = P(1); Km = P(2); Ki = P(3); accTol = P(4); magTol = P(5);
    N = numel(time); R = zeros(3,3,N);
    for t = 1:ind, R(:,:,t) = Rini; end
    bias = [0;0;0]; gW = [0 0 1]';
    for t = ind+1:N
        dt = time(t) - time(t-1);
        Rp = R(:,:,t-1); err = [0;0;0];
        an = norm(a(t,:));
        if Kp > 0 && abs(an - 1) < accTol && an > 0
            err = err + Kp * cross(a(t,:)' / an, Rp' * gW);
        end
        mn = norm(m(t,:));
        if Km > 0 && abs(mn/mAn - 1) < magTol && mn > 0
            mv = m(t,:)' / mn; h = Rp * mv;
            b = [norm(h(1:2)) * u; h(3)];
            err = err + Km * cross(mv, Rp' * b);
        end
        if Ki > 0, bias = bias - Ki * err * dt; end
        wc = w(t,:)' - bias + err;
        th = norm(wc) * dt;
        if th > 0
            K = skew(wc / norm(wc)); dR = eye(3) + sin(th)*K + (1-cos(th))*(K*K);
        else
            dR = eye(3);
        end
        R(:,:,t) = orthogonalization(Rp * dR);
    end
end
