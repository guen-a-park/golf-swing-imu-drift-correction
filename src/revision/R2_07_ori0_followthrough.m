%% [R2-7] R2_07_ori0_followthrough.m
%  checks whether the ori0 follow-through error appears in every participant and how many drive it up.
%  compares integrated trajectories without the D correction to exclude the learning effect.
%
%  Output : results/R2_07_ori0_followthrough.csv
%  2026-09-01
%% ========================================================================
clc; clear;
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');

ORI = [7 8 1 0];
SEG = {'Downswing','bst','imp'; 'FollowThrough','imp','fin'};

P = nan(10, numel(ORI), 2);      % participant x condition x phase
FINV = nan(10, numel(ORI));      % error at the finish
for oi = 1:numel(ORI)
    L = load(fullfile(RES, sprintf('R2_03_traj_store_ori%d.mat', ORI(oi))), 'R2_03_store');
    S = L.R2_03_store;
    n = numel(S); e = nan(n,2); fe = nan(n,1); sj = nan(n,1);
    for k = 1:n
        st = S(k); sj(k) = st.subj;
        for r = 1:2
            i0 = st.(SEG{r,2}); i1 = st.(SEG{r,3});
            e(k,r) = mean(vecnorm(st.Mtraj(i0:i1,:) - st.imu_trajCal(i0:i1,:), 2, 2))/10;
        end
        fe(k) = norm(st.Mtraj(st.fin,:) - st.imu_trajCal(st.fin,:))/10;
    end
    for su = 1:10
        m = sj == su;
        P(su,oi,1) = mean(e(m,1), 'omitnan');
        P(su,oi,2) = mean(e(m,2), 'omitnan');
        FINV(su,oi) = mean(fe(m), 'omitnan');
    end
end

fprintf('\nfollow-through error per participant (cm), no D correction\n');
fprintf('%-6s %9s %9s %9s %9s %12s\n', 'subject', 'ori7', 'ori8', 'ori1', 'ori0', 'ori0-ori1');
for su = 1:10
    fprintf('P%-5d %9.1f %9.1f %9.1f %9.1f %12.1f\n', su, P(su,1,2), P(su,2,2), P(su,3,2), P(su,4,2), P(su,4,2)-P(su,3,2));
end
fprintf('%-6s %9.1f %9.1f %9.1f %9.1f %12.1f\n', 'mean', mean(P(:,1,2)), mean(P(:,2,2)), mean(P(:,3,2)), mean(P(:,4,2)), mean(P(:,4,2)-P(:,3,2)));
fprintf('participants where ori0 is worse than ori1 : %d / 10\n', sum(P(:,4,2) > P(:,3,2)));

fprintf('\ndownswing error per participant (cm), for control\n');
fprintf('%-6s %9s %9s %9s %9s %12s\n', 'subject', 'ori7', 'ori8', 'ori1', 'ori0', 'ori0-ori1');
for su = 1:10
    fprintf('P%-5d %9.1f %9.1f %9.1f %9.1f %12.1f\n', su, P(su,1,1), P(su,2,1), P(su,3,1), P(su,4,1), P(su,4,1)-P(su,3,1));
end
fprintf('participants where ori0 is worse than ori1 : %d / 10\n', sum(P(:,4,1) > P(:,3,1)));

fprintf('\nposition error at the finish (cm)\n');
fprintf('%-6s %9s %9s %9s %9s\n', 'subject', 'ori7', 'ori8', 'ori1', 'ori0');
for su = 1:10
    fprintf('P%-5d %9.1f %9.1f %9.1f %9.1f\n', su, FINV(su,1), FINV(su,2), FINV(su,3), FINV(su,4));
end
fprintf('%-6s %9.1f %9.1f %9.1f %9.1f\n', 'mean', mean(FINV(:,1)), mean(FINV(:,2)), mean(FINV(:,3)), mean(FINV(:,4)));

rows = {};
for su = 1:10
    rows(end+1,:) = {su, P(su,1,1), P(su,2,1), P(su,3,1), P(su,4,1), ...
                         P(su,1,2), P(su,2,2), P(su,3,2), P(su,4,2), ...
                         FINV(su,1), FINV(su,2), FINV(su,3), FINV(su,4)}; %#ok<SAGROW>
end
writetable(cell2table(rows, 'VariableNames', {'subj', ...
    'down_ori7','down_ori8','down_ori1','down_ori0', ...
    'foll_ori7','foll_ori8','foll_ori1','foll_ori0', ...
    'fin_ori7','fin_ori8','fin_ori1','fin_ori0'}), ...
    fullfile(RES, 'R2_07_ori0_followthrough.csv'));
fprintf('\nsaved: %s\n', fullfile(RES, 'R2_07_ori0_followthrough.csv'));
