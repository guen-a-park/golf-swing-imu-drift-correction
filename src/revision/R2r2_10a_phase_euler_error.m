%% [R2r2-10a] R2r2_10a_phase_euler_error.m
%  Roll, pitch and yaw components of the orientation error by segment, computed in the same way as the error at address.
%  Output : console

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI'); S = R2_07_ORI; n = numel(S);
SEG = {'Address','add','add'; 'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
sj = nan(n,1); A = nan(n,3,5);
for k = 1:n
    st = S(k); sj(k) = st.subj; N = size(st.Rinf,3);
    e = nan(N,3);
    for t = 1:N
        eul = rotm2eul(st.Rinf(:,:,t) * st.R2Lw(:,:,t)', 'ZYX');
        e(t,:) = abs(rad2deg([eul(3) eul(2) eul(1)]));
    end
    for q = 1:5
        A(k,:,q) = mean(e(st.(SEG{q,2}):st.(SEG{q,3}),:), 1);
    end
end
su = unique(sj);
fprintf('\n%-14s | trial mean roll pitch yaw | participant mean roll pitch yaw\n', 'segment');
for q = 1:5
    tr = mean(A(:,:,q), 1);
    sb = mean(cell2mat(arrayfun(@(x) mean(A(sj == x,:,q), 1), su, 'UniformOutput', false)), 1);
    fprintf('%-14s | %5.1f %5.1f %5.1f | %5.1f %5.1f %5.1f\n', SEG{q,1}, tr, sb);
end
