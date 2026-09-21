%% [R2-2] R2_02_offset_variants.m
%  Comparison of the results depending on how the club length assumption is set.
%  Output : results/R2_02_offset_variants.csv

clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

T_CAM = [1944.24195587, -147.53836065, 1065.52214668;
         1946.26368487, -145.41073665, 1064.27866168;
         1941.23811087, -147.26589965, 1064.27767068;
         1966.736499  , -163.74432434, 1081.82660875;
         1967.165515  , -166.96142634, 1080.93007875;
         2102.062     , -175.03607234, 1081.19622275;
         2102.23739517, -178.74541095, 1095.93619444;
         2103.45266617, -187.32518295, 1074.79984244;
         2100.91714417, -175.84581295, 1072.13565044;
         2106.32278417, -184.96391595, 1074.71015144];

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store');  S = R2_03_store;
M = readtable(fullfile(RES, 'R2_common_mocap_metrics.csv'));
M = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);

dGlobal = mean(M.L_imp - M.L_add);
su = unique(M.subj);
dSubj = containers.Map('KeyType','double','ValueType','double');
for s = su(:)'
    k = M.subj == s;
    dSubj(s) = mean(M.L_imp(k) - M.L_add(k));
end
fprintf('impact - address measured distance difference : overall %.1f mm, per participant %.1f - %.1f mm\n', ...
    dGlobal, min(cell2mat(values(dSubj))), max(cell2mat(values(dSubj))));

SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
NAME = {'constant L (manuscript)','measured distance','fixed offset','per-participant offset'};

n = numel(S);
subj = nan(n,1); E = nan(n,4,4); I = nan(n,4); DD = nan(n,4);

for k = 1:n
    st = S(k); subj(k) = st.subj;
    row = M(M.subj == st.subj & M.trial == st.trial, :);
    if isempty(row), continue; end
    Tw = T_CAM(st.subj, :)';
    pa = [row.addEst_x; row.addEst_y; row.addEst_z];
    pi_= [row.impEst_x; row.impEst_y; row.impEst_z];
    La = row.L_assumed;

    R = { [La, La], [row.L_add, row.L_imp], [La, La + dGlobal], [La, La + dSubj(st.subj)] };
    Dref = [row.Dref_x, row.Dref_y, row.Dref_z];

    for c = 1:4
        qa = local_resolve(Tw, pa, R{c}(1));
        qi = local_resolve(Tw, pi_, R{c}(2));
        if any(~isfinite([qa; qi])), continue; end
        D = (qi - qa)';
        DD(k,c) = norm(D - Dref)/10;
        traj = local_correct(st, D);
        for r = 1:4
            i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
            E(k,r,c) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
        end
        I(k,c) = norm(st.Mtraj(st.imp,:) - traj(st.imp,:))/10;
    end
end

fprintf('\n%-18s %10s %10s %10s %10s %10s %10s\n', 'condition', 'D error', 'backswing', 'downswing', 'follow-through', 'total', 'impact');
rows = {};
for c = 1:4
    v = arrayfun(@(r) local_agg(E(:,r,c), subj), 1:4);
    fprintf('%-18s %10.1f %10.1f %10.1f %10.1f %10.1f %10.1f\n', NAME{c}, ...
        local_agg(DD(:,c), subj), v, local_agg(I(:,c), subj));
    rows(end+1,:) = {NAME{c}, local_agg(DD(:,c),subj), v(1), v(2), v(3), v(4), local_agg(I(:,c),subj)}; %#ok<SAGROW>
end
writetable(cell2table(rows, 'VariableNames', {'condition','D_err','Backswing','Downswing', ...
    'FollowThrough','EntireSwing','Impact'}), fullfile(RES, 'R2_02_offset_variants.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_02_offset_variants.csv'));

function q = local_resolve(Tw, p_ref, L)
    r = p_ref - Tw; r = r / norm(r);
    b = 2*dot(r, Tw); c = dot(Tw, Tw) - L^2;
    disc = b^2 - 4*c;
    if disc < 0, q = [NaN;NaN;NaN]; return; end
    s = [(-b + sqrt(disc))/2, (-b - sqrt(disc))/2];
    s = s(s > 0);
    if isempty(s), q = [NaN;NaN;NaN]; return; end
    q = Tw + max(s)*r;
end
function traj = local_correct(st, D)
    traj = st.imu_trajCal;
    dm = st.imu_trajCal(st.imp,:) - D;
    for kk = st.add:st.fin
        w = (kk - st.add)/(st.imp - st.add);
        traj(kk,:) = st.imu_trajCal(kk,:) - w*dm;
    end
end
function m = local_agg(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj == s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
