%% [R2-7] R2_07_residual_bias.m
%  The gyro reading in the static address phase = residual bias after Ferraris correction.
%  Computes how much it contributes to the orientation error when integrated over the swing duration.
%
%  Reviewer R2-7 : Caruso et al. reported that the bias changes even within one measurement
%  (up to 0.17 deg/s within one minute). This study obtains the bias from a separate calibration,
%  so the between-measurement difference may be larger -> measure its size directly in our data.
%
%  Prerequisite : R2_07_orifilter_store.m
%  Output      : revision/results/R2_07_residual_bias.csv
%
%  2026-09-04
%% ========================================================================

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI; n = numel(S);

WIN = 100;                      % 0.5 s just before address (200 Hz)
R2D = 180/pi;

sj = nan(n,1); bx = nan(n,3); bn = nan(n,1);
dur = nan(n,1); contrib = nan(n,1); gyroSd = nan(n,1); qwin = nan(n,1);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    % find the quietest WIN-length segment in the whole trial (the truly static segment)
    gn = vecnorm(st.gyro, 2, 2);
    N = numel(gn); best = inf; i0 = 1;
    for a = 1:(N - WIN)
        m = max(gn(a:a+WIN));
        if m < best, best = m; i0 = a; end
    end
    i1 = i0 + WIN;
    qwin(k) = best * R2D;                          % max angular velocity in that segment

    b = mean(st.gyro(i0:i1,:), 1) * R2D;          % deg/s
    bx(k,:) = b; bn(k) = norm(b);
    gyroSd(k) = mean(std(st.gyro(i0:i1,:), 0, 1)) * R2D;

    dur(k) = st.time(st.fin) - st.time(st.add);   % s
    contrib(k) = bn(k) * dur(k);                  % deg
end

%% ===== output =====
NL = char(10);
fprintf([NL '===== [R2-7] residual gyro bias in the static address phase =====' NL]);
fprintf(['Driver test set %d trials / %d participants. Quietest %.1f s segment within each trial' NL NL], ...
    n, numel(unique(sj)), WIN/200);

fprintf(['Residual bias magnitude      : %.3f deg/s (participant-level mean)' NL], local_agg(bn, sj));
fprintf(['  per axis                : %.3f, %.3f, %.3f deg/s' NL], ...
    local_agg(bx(:,1),sj), local_agg(bx(:,2),sj), local_agg(bx(:,3),sj));
fprintf(['Static-phase gyro SD : %.3f deg/s (measurement noise level)' NL], local_agg(gyroSd, sj));
fprintf(['Static-phase max ang. vel.    : %.3f deg/s (stationarity check)' NL], local_agg(qwin, sj));
fprintf(['Swing duration (ADD-FIN)     : %.2f s' NL], local_agg(dur, sj));
fprintf(['Integrated orientation error contribution   : %.2f deg' NL], local_agg(contrib, sj));
fprintf(['  Range per participant        : %.2f - %.2f deg' NL], ...
    min(local_bysubj(contrib, sj)), max(local_bysubj(contrib, sj)));
fprintf([NL 'Note: Caruso et al. 2021 reported a bias change of up to 0.17 deg/s within one minute' NL]);
fprintf(['      -> corresponds to %.2f deg over the same swing duration' NL], 0.17 * local_agg(dur, sj));

T = table((1:numel(local_bysubj(bn,sj)))', local_bysubj(bn,sj), local_bysubj(contrib,sj), ...
    'VariableNames', {'subj','bias_deg_s','contrib_deg'});
writetable(T, fullfile(RES, 'R2_07_residual_bias.csv'));
fprintf([NL 'saved: results/R2_07_residual_bias.csv' NL]);

%% ===== Helper functions =====
function v = local_bysubj(x, subj)
    s = unique(subj(isfinite(subj)));
    v = arrayfun(@(q) mean(x(subj == q), 'omitnan'), s);
end

function m = local_agg(x, subj)
    v = local_bysubj(x, subj);
    m = mean(v(isfinite(v)));
end
