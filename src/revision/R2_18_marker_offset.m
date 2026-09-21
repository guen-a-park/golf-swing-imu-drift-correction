%% [R2-18] R2_18_marker_offset.m
%  The component left in D~Vision~ by the difference in definition between the motion capture reference point and the video wrist detection point.
%  Output      : revision/results/R2_18_marker_offset.csv

clc; clear; close all;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
OUT = fullfile(thisDir, 'results');
load(fullfile(OUT, 'R2_07_orifilter_store.mat'), 'R2_07_ORI');
S = R2_07_ORI;
NL = char(10);

RNORM = [3 4];                 % assumed offset magnitude (cm)
subj = []; dth = []; resid = [];   % resid : [nTrial x 3axis x 2rnorm]

for k = 1:numel(S)
    st = S(k);
    Ra = squeeze(st.R2Lw(:,:,st.add));
    Ri = squeeze(st.R2Lw(:,:,st.imp));
    if any(~isfinite(Ra(:))) || any(~isfinite(Ri(:))), continue; end

    dR = Ra' * Ri;
    ct = (trace(dR) - 1) / 2;
    th = acosd(min(1, max(-1, ct)));       % address -> impact wrist orientation change

    subj(end+1,1) = st.subj;               %#ok<SAGROW>
    dth(end+1,1)  = th;                    %#ok<SAGROW>

    for a = 1:3
        e = zeros(3,1); e(a) = 1;
        v = (dR - eye(3)) * e;             % residual for a unit offset
        for q = 1:numel(RNORM)
            resid(numel(subj), a, q) = RNORM(q) * norm(v);  %#ok<SAGROW>
        end
    end
end

%% average per participant first, then summarize across participants
u = unique(subj);
mDth = arrayfun(@(x) mean(dth(subj==x)), u);
fprintf([NL 'address -> impact wrist orientation change' NL]);
fprintf('  %.1f +/- %.1f deg  (%d participants, %d trials)%s', ...
        mean(mDth), std(mDth), numel(u), numel(dth), NL);

fprintf([NL 'contribution the offset leaves in D (mean of participant means +/- SD, cm)' NL]);
rows = {};
axName = {'sensor x','sensor y','sensor z'};
for q = 1:numel(RNORM)
    for a = 1:3
        v = arrayfun(@(x) mean(resid(subj==x, a, q)), u);
        fprintf('  |r| = %d cm, %s : %.1f +/- %.1f%s', ...
                RNORM(q), axName{a}, mean(v), std(v), NL);
        rows = [rows; {RNORM(q), axName{a}, mean(v), std(v)}]; %#ok<AGROW>
    end
    vmax = arrayfun(@(x) mean(2*RNORM(q)*sind(dth(subj==x)/2)), u);
    fprintf('  |r| = %d cm, upper bound (perpendicular to rotation axis) : %.1f +/- %.1f%s', ...
            RNORM(q), mean(vmax), std(vmax), NL);
    rows = [rows; {RNORM(q), 'upper bound (perpendicular to rotation axis)', mean(vmax), std(vmax)}]; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'r_cm','direction','mean_cm','sd_cm'});
writetable(T, fullfile(OUT, 'R2_18_marker_offset.csv'));
fprintf([NL 'saved: results/R2_18_marker_offset.csv' NL]);
