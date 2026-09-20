%% [R2-7] R2_07_filter_verify.m
%  verification version of the complementary filter comparison.
%    (1) Kp = 0 control : whether the filter becomes exactly the same as gyro integration
%    (2) both signs of the feedback cross product
%    (3) including the gyro bias estimation term (Ki)
%
%  Run first : R2_07_orifilter_store.m
%  Output    : revision/results/R2_07_filter_verify.csv
%
%  2026-09-04
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
addpath(genpath(fullfile(fileparts(fileparts(thisDir)), 'GolfSwing_0424')));

load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI; n = numel(S);
fprintf('orientation store: %d trials\n', n);

GRAV = 9.81; ACCT = 0.10;
SEG  = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
        'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

% {label, Kp, Ki, sign}  sign +1 : vMeas x vHat,  -1 : vHat x vMeas
COND = { ...
    'Kp=0 (control)',         0.0,  0.0,  +1; ...
    'Kp=0.5 sign +',          0.5,  0.0,  +1; ...
    'Kp=0.5 sign -',          0.5,  0.0,  -1; ...
    'Kp=2.0 sign -',          2.0,  0.0,  -1; ...
    'Kp=0.5 Ki=0.01 sign +',  0.5,  0.01, +1; ...
    'Kp=0.5 Ki=0.01 sign -',  0.5,  0.01, -1};
nC = size(COND,1);

sj = nan(n,1);
eG = nan(n,4); aG = nan(n,1); iG = nan(n,1);
eC = nan(n,4,nC); aC = nan(n,nC); iC = nan(n,nC);
maxDiff0 = nan(n,1);          % maximum angle difference between the Kp=0 condition and the manuscript orientation

for k = 1:n
    st = S(k); sj(k) = st.subj;
    add = st.add; imp = st.imp;

    errG = local_angle_error(st.Rinf, st.R2Lw);
    for q = 1:4
        eG(k,q) = mean(errG(st.(SEG{q,2}):st.(SEG{q,3})));
    end
    aG(k) = errG(add); iG(k) = errG(imp);

    for c = 1:nC
        Rf = local_mahony(st.time, st.acc/GRAV, st.gyro, add, st.R2tri, ...
                          COND{c,2}, COND{c,3}, COND{c,4}, ACCT);
        errF = local_angle_error(Rf, st.R2Lw);
        for q = 1:4
            eC(k,q,c) = mean(errF(st.(SEG{q,2}):st.(SEG{q,3})));
        end
        aC(k,c) = errF(add); iC(k,c) = errF(imp);
        if c == 1
            maxDiff0(k) = max(local_angle_error(Rf, st.Rinf));
        end
    end
end

%% ===== output =====
NL = char(10);
fprintf([NL '===== [R2-7] complementary filter verification (deg) =====' NL]);
fprintf(['(1) maximum angle difference between the Kp=0 condition and the manuscript orientation : %.4f deg (should be 0)' NL NL], ...
    max(maxDiff0));

fprintf(['%-24s %9s %9s %9s %9s %9s %9s' NL], 'condition', ...
    'address','backswing','downswing','follow-through','overall','impact');
vG = arrayfun(@(q) local_agg(eG(:,q), sj), 1:4);
fprintf(['%-24s %9.2f %9.2f %9.2f %9.2f %9.2f %9.2f' NL], 'gyro integration (manuscript)', ...
    local_agg(aG,sj), vG, local_agg(iG,sj));

rows = {{'GyroOnly', local_agg(aG,sj), vG(1), vG(2), vG(3), vG(4), local_agg(iG,sj)}};
for c = 1:nC
    vC = arrayfun(@(q) local_agg(eC(:,q,c), sj), 1:4);
    fprintf(['%-24s %9.2f %9.2f %9.2f %9.2f %9.2f %9.2f' NL], COND{c,1}, ...
        local_agg(aC(:,c),sj), vC, local_agg(iC(:,c),sj));
    rows{end+1} = {COND{c,1}, local_agg(aC(:,c),sj), vC(1), vC(2), vC(3), vC(4), ...
        local_agg(iC(:,c),sj)}; %#ok<SAGROW>
end

T = cell2table(vertcat(rows{:}), 'VariableNames', ...
    {'condition','Address','Backswing','Downswing','FollowThrough','EntireSwing','Impact'});
writetable(T, fullfile(RES, 'R2_07_filter_verify.csv'));
fprintf([NL 'saved: results/R2_07_filter_verify.csv' NL]);

%% ===== helper functions =====
function e = local_angle_error(Ra, Rb)
    N = size(Ra,3); e = nan(N,1);
    for t = 1:N
        c = (trace(Ra(:,:,t)' * Rb(:,:,t)) - 1)/2;
        e(t) = acosd(min(1, max(-1, c)));
    end
end

function Rinf = local_mahony(time, a, w, ind, Rini, Kp, Ki, sgn, accTol)
    N = numel(time);
    Rinf = zeros(3,3,N);
    R = Rini;
    for t = 1:ind, Rinf(:,:,t) = R; end
    bias = [0;0;0];
    gW = [0 0 1]';
    for t = ind+1:N
        dt = time(t) - time(t-1);
        wc = w(t,:)' - bias;
        an = norm(a(t,:));
        if Kp > 0 && abs(an - 1) < accTol && an > 0
            vHat  = Rinf(:,:,t-1)' * gW;
            vMeas = a(t,:)' / an;
            if sgn > 0, err = cross(vMeas, vHat); else, err = cross(vHat, vMeas); end
            wc = wc + Kp * err;
            if Ki > 0, bias = bias - Ki * err * dt; end
        end
        tt = (dt * wc)';
        Rinf(:,:,t) = Rinf(:,:,t-1) * (eye(3) + skew(tt) + 0.5*skew(tt)^2 + 1/6*skew(tt)^3);
        Rinf(:,:,t) = orthogonalization(Rinf(:,:,t));
    end
end

function m = local_agg(v, subj)
    s = unique(subj(isfinite(subj)));
    sm = arrayfun(@(x) mean(v(subj == x), 'omitnan'), s);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
