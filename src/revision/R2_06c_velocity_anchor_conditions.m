%% [R2-6c] R2_06c_velocity_anchor_conditions.m
%  For the condition using the approximate zero-velocity assumption and the condition using the
%  Output      : revision/results/R2_06c_velocity_anchor_conditions.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

fs = 200; ts = 1/fs;
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
DSET = {'MocapD','Dref'; 'VideoD','Dvid'; 'InferD','Dml'};

ML_DIR = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
Dml = local_load_Dml(fullfile(ML_DIR, 'runs_R2_03_calib20_seed3'));
if isempty(Dml), error('D_Infer run folder not found.'); end

n = numel(S);
sj = nan(n,1);
nD = size(DSET,1);
eZ = nan(n,4,nD); eMv = nan(n,4,nD);   % (trial, segment, D type)
iZ = nan(n,nD);  iMv = nan(n,nD);
shiftDS = nan(n,1);
nZ = nan(n,4); nMv = nan(n,4); nZi = nan(n,1); nMvi = nan(n,1);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    r = M(M.subj == st.subj & M.trial == st.trial, :);
    if isempty(r), continue; end

    add = st.add; bst = st.bst; imp = st.imp; fin = st.fin;
    vmBST = [r.vBST_x(1) r.vBST_y(1) r.vBST_z(1)];      % mm/s
    vmFIN = [r.vFIN_x(1) r.vFIN_y(1) r.vFIN_z(1)];

    nS = size(st.imu_trajCal, 1);
    d = zeros(nS, 3);
    i1 = add:bst;  w1 = (i1 - add)' / (bst - add);
    d(i1,:) = -w1 .* vmBST;
    i2 = bst:fin;  w2 = (i2 - bst)' / (fin - bst);
    d(i2,:) = -vmBST + w2 .* (vmBST - vmFIN);

    dx = cumtrapz(ts, d);
    dx = dx - dx(add,:);                                % mm

    trajZ  = st.imu_trajCal;                            % zero-velocity anchor (proposed method)
    trajMv = st.imu_trajCal - dx;                       % measured-velocity anchor (counterfactual)
    shiftDS(k) = mean(vecnorm(dx(bst:imp,:), 2, 2))/10;

    for p = 1:4
        i0 = st.(SEG{p,2}); i9 = st.(SEG{p,3});
        nZ(k,p)  = mean(vecnorm(st.Mtraj(i0:i9,:) - trajZ(i0:i9,:),  2, 2))/10;
        nMv(k,p) = mean(vecnorm(st.Mtraj(i0:i9,:) - trajMv(i0:i9,:), 2, 2))/10;
    end
    nZi(k)  = norm(st.Mtraj(imp,:) - trajZ(imp,:))/10;
    nMvi(k) = norm(st.Mtraj(imp,:) - trajMv(imp,:))/10;

    for q = 1:nD
        if strcmp(DSET{q,2}, 'Dml')
            D = squeeze(Dml(st.subj, st.trial - 20, :))';
            if any(isnan(D)), continue; end
        else
            D = [r.([DSET{q,2} '_x'])(1), r.([DSET{q,2} '_y'])(1), r.([DSET{q,2} '_z'])(1)];
        end
        cZ  = local_correct(trajZ,  D, add, imp, fin);
        cMv = local_correct(trajMv, D, add, imp, fin);
        for p = 1:4
            i0 = st.(SEG{p,2}); i9 = st.(SEG{p,3});
            eZ(k,p,q)  = mean(vecnorm(st.Mtraj(i0:i9,:) - cZ(i0:i9,:),  2, 2))/10;
            eMv(k,p,q) = mean(vecnorm(st.Mtraj(i0:i9,:) - cMv(i0:i9,:), 2, 2))/10;
        end
        iZ(k,q)  = norm(st.Mtraj(imp,:) - cZ(imp,:))/10;
        iMv(k,q) = norm(st.Mtraj(imp,:) - cMv(imp,:))/10;
    end
end

%% output
fprintf('\n===== [R2-6c] per-segment trajectory error by anchor velocity target (cm) =====\n');
fprintf('driver evaluation: %d trials / %d participants. participant-level mean\n', ...
    sum(isfinite(sj)), numel(unique(sj(isfinite(sj)))));
fprintf('downswing segment trajectory shift (difference between the two conditions) : %.2f cm\n\n', local_agg(shiftDS, sj));

NL = char(10);
fprintf(['--- no displacement constraint ---' NL]);
fprintf(['%-24s %10s %10s %10s %10s %10s' NL], 'anchor target', ...
    'backswing','downswing','follow-through','total','impact');
fprintf(['%-24s %10.1f %10.1f %10.1f %10.1f %10.1f' NL], '0 (approximate zero velocity)', ...
    arrayfun(@(p) local_agg(nZ(:,p), sj), 1:4), local_agg(nZi, sj));
fprintf(['%-24s %10.1f %10.1f %10.1f %10.1f %10.1f' NL NL], 'measured velocity', ...
    arrayfun(@(p) local_agg(nMv(:,p), sj), 1:4), local_agg(nMvi, sj));

rows = {};
for q = 1:nD
    fprintf('--- constraint = %s ---\n', DSET{q,1});
    fprintf('%-24s %10s %10s %10s %10s %10s\n', 'anchor target', ...
        'backswing', 'downswing', 'follow-through', 'total', 'impact');
    vZ  = arrayfun(@(p) local_agg(eZ(:,p,q),  sj), 1:4);
    vMv = arrayfun(@(p) local_agg(eMv(:,p,q), sj), 1:4);
    fprintf('%-24s %10.1f %10.1f %10.1f %10.1f %10.1f\n', '0 (approximate zero velocity)', ...
        vZ,  local_agg(iZ(:,q), sj));
    fprintf('%-24s %10.1f %10.1f %10.1f %10.1f %10.1f\n', 'measured velocity', ...
        vMv, local_agg(iMv(:,q), sj));
    fprintf('%-24s %10.1f %10.1f %10.1f %10.1f %10.1f\n\n', 'difference (measured - zero)', ...
        vMv - vZ, local_agg(iMv(:,q), sj) - local_agg(iZ(:,q), sj));
    rows = [rows; {DSET{q,1}, '0 (approximate zero velocity)', vZ(1), vZ(2), vZ(3), vZ(4), local_agg(iZ(:,q),sj)}]; %#ok<AGROW>
    rows = [rows; {DSET{q,1}, 'measured velocity',        vMv(1), vMv(2), vMv(3), vMv(4), local_agg(iMv(:,q),sj)}]; %#ok<AGROW>
end

writetable(cell2table(rows, 'VariableNames', ...
    {'constraint','anchor','Backswing','Downswing','FollowThrough','EntireSwing','Impact'}), ...
    fullfile(RES, 'R2_06c_velocity_anchor_conditions.csv'));
fprintf('saved: results/R2_06c_velocity_anchor_conditions.csv\n');

%% helper functions
function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0;
    dm = traj0(imp,:) - D;
    for kk = add:fin
        w = (kk - add)/(imp - add);
        traj(kk,:) = traj0(kk,:) - w*dm;
    end
end

function D = local_load_Dml(runDir)
    D = [];
    if ~isfolder(runDir), return; end
    D = nan(10, 10, 3);
    for su = 1:10
        f = fullfile(runDir, sprintf('subj%d_driver_test_est.csv', su));
        if ~isfile(f), continue; end
        T = readtable(f);
        m = min(height(T), 10);
        D(su, 1:m, :) = [T.pred_x(1:m), T.pred_y(1:m), T.pred_z(1:m)];
    end
end

function m = local_agg(v, subj)
    s = unique(subj(isfinite(subj)));
    sm = arrayfun(@(x) mean(v(subj == x), 'omitnan'), s);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
