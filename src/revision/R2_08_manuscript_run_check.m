%% [R2-8] R2_08_manuscript_run_check.m
%  Computes the per-event error with the model reported in the manuscript (runs_0112_accgyro_400800_ori7traj2)
%  Output      : revision/results/R2_08_manuscript_run_check.csv

clc; clear; close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
ML  = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');

load(fullfile(RES, 'R2_03_traj_store_ori7.mat'), 'R2_03_store'); S = R2_03_store;

RUNS = {'runs_0112_accgyro_400800_ori7traj2', 'Manuscript run'; ...
        'runs_R2_03_calib20_seed3',           'seed3'};

EVT = {'BST','bst'; 'IMP','imp'; 'FIN','fin'};
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
NL = char(10);
rows = {};

for ri = 1:size(RUNS,1)
    Dml = local_load_Dml(fullfile(ML, RUNS{ri,1}));
    if isempty(Dml) || all(isnan(Dml(:)))
        fprintf(['[skipped] %s' NL], RUNS{ri,1}); continue;
    end

    n = numel(S);
    sj = nan(n,1); ax = nan(n,3,3); nm = nan(n,3); sg = nan(n,4);
    for k = 1:n
        st = S(k); sj(k) = st.subj;
        D = squeeze(Dml(st.subj, st.trial - 20, :))';
        if any(isnan(D)), continue; end
        traj = local_correct(st.imu_trajCal, D, st.add, st.imp, st.fin);
        for e = 1:3
            idx = st.(EVT{e,2});
            d = st.Mtraj(idx,:) - traj(idx,:);
            ax(k,:,e) = abs(d)/10;            % per-axis absolute error (cm)
            nm(k,e)   = norm(d)/10;           % 3D magnitude (cm)
        end
        for q = 1:4
            i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
            sg(k,q) = mean(vecnorm(st.Mtraj(i0:i1,:) - traj(i0:i1,:), 2, 2))/10;
        end
    end

    fprintf([NL '===== %s (%s) =====' NL], RUNS{ri,1}, RUNS{ri,2});
    fprintf(['%-6s %14s %14s %14s %12s' NL], 'Event', 'X', 'Y', 'Z', '3D magnitude');
    for e = 1:3
        fprintf(['%-6s %6.2f ± %-6.2f %6.2f ± %-6.2f %6.2f ± %-6.2f %12.2f' NL], EVT{e,1}, ...
            local_agg(ax(:,1,e),sj), local_sd(ax(:,1,e),sj), ...
            local_agg(ax(:,2,e),sj), local_sd(ax(:,2,e),sj), ...
            local_agg(ax(:,3,e),sj), local_sd(ax(:,3,e),sj), local_agg(nm(:,e),sj));
        rows(end+1,:) = {RUNS{ri,1}, EVT{e,1}, local_agg(ax(:,1,e),sj), local_agg(ax(:,2,e),sj), ...
            local_agg(ax(:,3,e),sj), local_agg(nm(:,e),sj)}; %#ok<AGROW>
    end
    fprintf(['phase-wise 3D magnitude : backswing %.1f, downswing %.1f, follow-through %.1f, entire %.1f' NL], ...
        arrayfun(@(q) local_agg(sg(:,q), sj), 1:4));
end

T = cell2table(rows, 'VariableNames', {'run','event','X','Y','Z','norm3d'});
writetable(T, fullfile(RES, 'R2_08_manuscript_run_check.csv'));
fprintf([NL 'saved: results/R2_08_manuscript_run_check.csv' NL]);

%% Helper functions
function traj = local_correct(traj0, D, add, imp, fin)
    traj = traj0; dm = traj0(imp,:) - D;
    for kk = add:fin
        traj(kk,:) = traj0(kk,:) - ((kk-add)/(imp-add))*dm;
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

function v = local_bysubj(x, subj)
    s = unique(subj(isfinite(subj)));
    v = arrayfun(@(q) mean(x(subj == q), 'omitnan'), s);
end
function m = local_agg(x, subj), v = local_bysubj(x, subj); m = mean(v(isfinite(v))); end
function m = local_sd(x, subj),  v = local_bysubj(x, subj); m = std(v(isfinite(v))); end
