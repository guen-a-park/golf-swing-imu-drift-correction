%% [R2-7] R2_07_mtraj_lag.m
%  Checks the temporal alignment between the mocap reference trajectory (Mtraj) and the IMU integrated trajectory.
%  Output : results/R2_07_mtraj_lag.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
KS  = -4:4;
rows = {};

for oi = [7 8]
    f = fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', oi));
    if ~isfile(f), continue; end
    L = load(f, 'R2_03_store'); S = L.R2_03_store;

    for mode = 1:2      % 1 = no D correction, 2 = D_Vision correction
        if mode == 1
            fprintf('\n===== ori%d, no D correction =====\n', oi);
        else
            fprintf('\n===== ori%d, D_Vision correction applied =====\n', oi);
        end
        fprintf('%6s %11s %11s %11s %11s\n', 'shift', 'backswing', 'downswing', 'follow-through', 'total');
        for ki = 1:numel(KS)
            k = KS(ki);
            n = numel(S); e = nan(n,4); sj = nan(n,1);
            for q = 1:n
                st = S(q); sj(q) = st.subj;
                traj = st.imu_trajCal;
                if mode == 2
                    r = M(M.subj == st.subj & M.trial == st.trial, :);
                    if isempty(r), continue; end
                    D  = [r.Dvid_x(1) r.Dvid_y(1) r.Dvid_z(1)];
                    dm = st.imu_trajCal(st.imp,:) - D;
                    for kk = st.add:st.fin
                        w = (kk - st.add)/(st.imp - st.add);
                        traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
                    end
                end
                Mt = st.Mtraj; T = size(Mt,1);
                for r2 = 1:4
                    i0 = st.(SEG{r2,2}); i1 = st.(SEG{r2,3});
                    idx = i0:i1; jdx = idx + k;
                    ok = jdx >= 1 & jdx <= T;
                    e(q,r2) = mean(vecnorm(Mt(jdx(ok),:) - traj(idx(ok),:), 2, 2))/10;
                end
            end
            v = arrayfun(@(c) local_subj(e(:,c), sj), 1:4);
            fprintf('%6d %11.1f %11.1f %11.1f %11.1f\n', k, v);
            rows(end+1,:) = {oi, mode, k, v(1), v(2), v(3), v(4)}; %#ok<SAGROW>
        end
    end
end

writetable(cell2table(rows, 'VariableNames', {'ori','mode','shift', ...
    'Backswing','Downswing','FollowThrough','EntireSwing'}), ...
    fullfile(RES, 'R2_07_mtraj_lag.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_07_mtraj_lag.csv'));

function m = local_subj(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
