%% [R2-7] R2_07_orientation_only.m
%  directly compares the integrated trajectory without the D correction (imu_trajCal) against mocap for the four orientation conditions.
%  Output : results/R2_07_orientation_only.csv

clc; clear;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

ORI = [7 8 1 0];
LBL = {'ori7 magnetometer heading', 'ori8 mocap yaw only', 'ori1 mocap initial orientation 3 axes', 'ori0 mocap whole interval'};
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};

rows = {};
for mode = 1:2      % 1 = no D correction, 2 = D_Vision correction
    if mode == 1
        fprintf('\n===== no D correction (velocity correction only) : effect of the orientation condition alone =====\n');
    else
        fprintf('\n===== D_Vision correction applied =====\n');
    end
    fprintf('%-24s %10s %10s %10s %10s %10s\n', 'condition', 'backswing', 'downswing', 'follow-through', 'overall', 'impact');
    for oi = 1:numel(ORI)
        f = fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', ORI(oi)));
        if ~isfile(f), fprintf('%-24s  (no store)\n', LBL{oi}); continue; end
        L = load(f, 'R2_03_store'); S = L.R2_03_store;

        n = numel(S); e = nan(n,4); ie = nan(n,1); sj = nan(n,1);
        for k = 1:n
            st = S(k); sj(k) = st.subj;
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
            for r2 = 1:4
                i0 = st.(SEG{r2,2}); i1 = st.(SEG{r2,3});
                e(k,r2) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
            end
            ie(k) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:))/10;
        end
        v  = arrayfun(@(c) local_subj(e(:,c), sj), 1:4);
        im = local_subj(ie, sj);
        fprintf('%-24s %10.1f %10.1f %10.1f %10.1f %10.1f\n', LBL{oi}, v, im);
        rows(end+1,:) = {mode, ORI(oi), LBL{oi}, v(1), v(2), v(3), v(4), im}; %#ok<SAGROW>
    end
end

writetable(cell2table(rows, 'VariableNames', {'mode','ori','label','Backswing', ...
    'Downswing','FollowThrough','EntireSwing','Impact'}), ...
    fullfile(RES, 'R2_07_orientation_only.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_07_orientation_only.csv'));

function m = local_subj(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
