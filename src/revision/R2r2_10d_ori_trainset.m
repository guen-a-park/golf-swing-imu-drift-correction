%% [R2r2-10d] R2r2_10d_ori_trainset.m
%  The orientation substitution comparison recomputed on the training trials, corrected with d_video.
%  Output : console

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
ML = fullfile(fileparts(fileparts(fileparts(thisDir))), 'multimodal');
SEG = {'Backswing','add','bst'; 'Downswing','bst','imp'; 'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
ORI = [7 8 1 0]; NAME = {'ori7 manuscript', 'ori8 initial heading from mocap', 'ori1 initial 3-axis orientation from mocap', 'ori0 mocap orientation over the entire swing'};
V = cell(1,4); chk = nan(1,4);
for oi = 1:4
    L = load(fullfile(ML, sprintf('swingData_2508_forML_ori%d.mat', ORI(oi))));
    fn = fieldnames(L); SW = L.(fn{1});
    E = nan(10, 20, 4); dmax = 0;
    for su = 1:10
        for tr = 1:20
            g = SW(su).clubN(1).trialN(tr);
            if isempty(g) || ~isfield(g, 'traj_integration') || isempty(g.traj_integration), continue; end
            T = g.traj_integration; d = g.rel(1:3);
            if any(~isfinite(d)), continue; end
            cal = T(:,4:6); Mt = T(:,13:15); lab = T(:,10:12);
            add = g.add; imp = g.imp; fin = min(g.fin, size(T,1)); bst = g.bst;
            Tc = cal; dm = cal(imp,:) - d;
            for k = add:fin, Tc(k,:) = cal(k,:) - ((k-add)/(imp-add))*dm; end
            dmax = max(dmax, max(abs(Tc(add:imp,:) - lab(add:imp,:)), [], 'all'));
            ev = struct('add',add,'bst',bst,'imp',imp,'fin',fin);
            for q = 1:4
                ii = ev.(SEG{q,2}):ev.(SEG{q,3});
                E(su,tr,q) = mean(vecnorm(Mt(ii,:) - Tc(ii,:), 2, 2))/10;
            end
        end
    end
    V{oi} = squeeze(mean(E, 2, 'omitnan'));
    chk(oi) = dmax;
    fprintf('%-24s n=%d  %s   (largest difference from the label %.3g mm)\n', NAME{oi}, sum(isfinite(E(:,:,1)), 'all'), ...
        sprintf('%6.1f', mean(V{oi}, 1, 'omitnan')), dmax);
end
fprintf('\npaired t-test p against ori7 (participant means, n = 10)\n');
for oi = 2:4
    p = arrayfun(@(q) local_p(V{1}(:,q), V{oi}(:,q)), 1:4);
    fprintf('%-24s %s\n', NAME{oi}, sprintf('%7.3f', p));
end
function p = local_p(a, b)
    [~, p] = ttest(a, b);
end
