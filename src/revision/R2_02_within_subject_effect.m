%% [R2-2] R2_02_within_subject_effect.m
%  directly measures how much the within-participant between-trial D variation actually affects the corrected trajectory.
%  Output : results/R2_02_within_subject_effect.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

su = unique(M.subj);
Dbar = containers.Map('KeyType','double','ValueType','any');
for s = su(:)'
    k = M.subj == s;
    Dbar(s) = [mean(M.Dref_x(k)) mean(M.Dref_y(k)) mean(M.Dref_z(k))];
end

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
n = numel(S);
sj = nan(n,1); eA = nan(n,4); eB = nan(n,4); iA = nan(n,1); iB = nan(n,1); dv = nan(n,1);

for k = 1:n
    st = S(k); sj(k) = st.subj;
    r = M(M.subj == st.subj & M.trial == st.trial, :);
    if isempty(r), continue; end
    Dtrial = [r.Dref_x(1) r.Dref_y(1) r.Dref_z(1)];
    Dmean  = Dbar(st.subj);
    dv(k)  = norm(Dtrial - Dmean)/10;          % magnitude of that trial's variation

    tA = local_correct(st, Dtrial);
    tB = local_correct(st, Dmean);
    for q = 1:4
        i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
        eA(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - tA(i0:i1,:), 2, 2))/10;
        eB(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - tB(i0:i1,:), 2, 2))/10;
    end
    iA(k) = norm(st.Mtraj(st.imp,:) - tA(st.imp,:))/10;
    iB(k) = norm(st.Mtraj(st.imp,:) - tB(st.imp,:))/10;
end

fprintf('\nbetween-trial D variation magnitude : mean %.2f cm\n', local_agg(dv, sj));
fprintf('\n%-22s %10s %10s %10s %10s %10s\n', 'condition', 'backswing', 'downswing', 'follow-through', 'overall', 'impact');
vA = arrayfun(@(q) local_agg(eA(:,q), sj), 1:4);
vB = arrayfun(@(q) local_agg(eB(:,q), sj), 1:4);
fprintf('%-22s %10.1f %10.1f %10.1f %10.1f %10.1f\n', 'per-trial mocap D', vA, local_agg(iA, sj));
fprintf('%-22s %10.1f %10.1f %10.1f %10.1f %10.1f\n', 'participant-mean mocap D', vB, local_agg(iB, sj));
fprintf('%-22s %10.1f %10.1f %10.1f %10.1f %10.1f\n', 'difference', vB-vA, local_agg(iB,sj)-local_agg(iA,sj));

writetable(cell2table({ 'per-trial mocap D', vA(1), vA(2), vA(3), vA(4), local_agg(iA,sj);
                        'participant-mean mocap D', vB(1), vB(2), vB(3), vB(4), local_agg(iB,sj) }, ...
    'VariableNames', {'condition','Backswing','Downswing','FollowThrough','EntireSwing','Impact'}), ...
    fullfile(RES, 'R2_02_within_subject_effect.csv'));
fprintf('\nsaved: results/R2_02_within_subject_effect.csv\n');

function traj = local_correct(st, D)
    traj = st.imu_trajCal;
    dm = st.imu_trajCal(st.imp,:) - D;
    for kk = st.add:st.fin
        w = (kk - st.add)/(st.imp - st.add);
        traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
    end
end
function m = local_agg(v, subj)
    s = unique(subj(isfinite(subj)));
    sm = arrayfun(@(x) mean(v(subj == x), 'omitnan'), s);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
