%% [R2-7] R2_07_filter_compare.m
%  Compares the current orientation estimate (static initialization + gyro integration)
%  Output      : revision/results/R2_07_filter_compare.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
addpath(genpath(fullfile(fileparts(fileparts(thisDir)), 'GolfSwing_0424')));

load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI;
n = numel(S);
fprintf('orientation store: %d trials\n', n);

KP   = [0.1 0.5 2.0];          % complementary filter gain
GRAV = 9.81;                   % acceleration unit is m/s^2
ACCT = 0.10;                   % feedback only when |a|/g is within this of 1
SEG  = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
        'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

sj  = nan(n,1);
eG  = nan(n,4);                % gyro integration only (current method)
eF  = nan(n,4,numel(KP));      % complementary filter
iG  = nan(n,1);  iF = nan(n,numel(KP));      % impact
aG  = nan(n,1);  aF = nan(n,numel(KP));      % address
usedFrac = nan(n,1);           % fraction of samples with accelerometer feedback on

for k = 1:n
    st = S(k); sj(k) = st.subj;
    add = st.add; imp = st.imp; fin = st.fin;

    errG = local_angle_error(st.Rinf, st.R2Lw);
    for q = 1:4
        i0 = st.(SEG{q,2}); i9 = st.(SEG{q,3});
        eG(k,q) = mean(errG(i0:i9));
    end
    iG(k) = errG(imp); aG(k) = errG(add);

    for gi = 1:numel(KP)
        [Rf, frac] = local_mahony(st.time, st.acc/GRAV, st.gyro, add, ...
                                  st.R2tri, KP(gi), ACCT);
        errF = local_angle_error(Rf, st.R2Lw);
        for q = 1:4
            i0 = st.(SEG{q,2}); i9 = st.(SEG{q,3});
            eF(k,q,gi) = mean(errF(i0:i9));
        end
        iF(k,gi) = errF(imp); aF(k,gi) = errF(add);
        if gi == 1, usedFrac(k) = frac; end
    end
end

%% output
NL = char(10);
fprintf([NL '===== [R2-7] gyro integration vs complementary filter, phase-wise orientation error (deg) =====' NL]);
fprintf(['Driver test set %d trials / %d participants. Participant-level mean' NL], ...
    sum(isfinite(sj)), numel(unique(sj(isfinite(sj)))));
fprintf(['Fraction of samples with accelerometer feedback on : %.1f %%' NL NL], 100*local_agg(usedFrac, sj));

fprintf(['%-22s %10s %10s %10s %10s %10s %10s' NL], 'Condition', ...
    'Address', 'Backswing', 'Downswing', 'Follow-through', 'Entire', 'Impact');
vG = arrayfun(@(q) local_agg(eG(:,q), sj), 1:4);
fprintf(['%-22s %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f' NL], 'Gyro integration (manuscript)', ...
    local_agg(aG, sj), vG, local_agg(iG, sj));

rows = {{'GyroOnly', local_agg(aG,sj), vG(1), vG(2), vG(3), vG(4), local_agg(iG,sj)}};
for gi = 1:numel(KP)
    vF = arrayfun(@(q) local_agg(eF(:,q,gi), sj), 1:4);
    fprintf(['%-22s %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f' NL], ...
        sprintf('Complementary filter Kp=%.1f', KP(gi)), local_agg(aF(:,gi), sj), vF, local_agg(iF(:,gi), sj));
    rows{end+1} = {sprintf('Mahony_Kp%.1f', KP(gi)), local_agg(aF(:,gi),sj), ...
        vF(1), vF(2), vF(3), vF(4), local_agg(iF(:,gi),sj)}; %#ok<SAGROW>
end

T = cell2table(vertcat(rows{:}), 'VariableNames', ...
    {'condition','Address','Backswing','Downswing','FollowThrough','EntireSwing','Impact'});
writetable(T, fullfile(RES, 'R2_07_filter_compare.csv'));
fprintf([NL 'saved: results/R2_07_filter_compare.csv' NL]);

%% Helper functions
function e = local_angle_error(Ra, Rb)
    N = size(Ra,3); e = nan(N,1);
    for t = 1:N
        Rr = Ra(:,:,t)' * Rb(:,:,t);
        c = (trace(Rr) - 1)/2;
        e(t) = acosd(min(1, max(-1, c)));
    end
end

function [Rinf, frac] = local_mahony(time, a, w, ind, Rini, Kp, accTol)
    N = numel(time);
    Rinf = zeros(3,3,N);
    R = Rini;
    for t = 1:ind, Rinf(:,:,t) = R; end
    used = 0; tot = 0;
    gW = [0 0 1]';                       % gravity direction in the world frame (Z up)
    for t = ind+1:N
        dt = time(t) - time(t-1);
        wc = w(t,:)';
        an = norm(a(t,:));
        tot = tot + 1;
        if abs(an - 1) < accTol && an > 0
            vHat = Rinf(:,:,t-1)' * gW;          % estimate
            vMeas = a(t,:)' / an;                % measurement
            wc = wc + Kp * cross(vMeas, vHat);
            used = used + 1;
        end
        tt = (dt * wc)';
        Rinf(:,:,t) = Rinf(:,:,t-1) * (eye(3) + skew(tt) + 0.5*skew(tt)^2 + 1/6*skew(tt)^3);
        Rinf(:,:,t) = orthogonalization(Rinf(:,:,t));
    end
    frac = used / max(tot,1);
end

function m = local_agg(v, subj)
    s = unique(subj(isfinite(subj)));
    sm = arrayfun(@(x) mean(v(subj == x), 'omitnan'), s);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
