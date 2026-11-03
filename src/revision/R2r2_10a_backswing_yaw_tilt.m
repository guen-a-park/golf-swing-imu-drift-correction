%% [R2r2-10a] R2r2_10a_backswing_yaw_tilt.m
%  Splits the sample-wise orientation error into heading (yaw) and tilt components by swing-twist decomposition.
%  Output : console

clc; clear;
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
RES = fullfile(thisDir, 'results');
load(fullfile(RES, 'R2_07_orifilter_store.mat'), 'R2_07_ORI'); S = R2_07_ORI; n = numel(S);
SEG = {'Address','add','add'; 'Backswing','add','bst'; 'Downswing','bst','imp'; ...
       'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
sj = nan(n,1); TOT = nan(n,5); YAW = nan(n,5); TIL = nan(n,5);
z = [0 0 1]';
for k = 1:n
    st = S(k); sj(k) = st.subj; N = size(st.Rinf,3);
    tot = nan(N,1); yaw = nan(N,1); til = nan(N,1);
    for t = 1:N
        E = st.R2Lw(:,:,t) * st.Rinf(:,:,t)';
        tot(t) = acosd(min(1, max(-1, (trace(E) - 1)/2)));
        v = E * z;
        til(t) = acosd(min(1, max(-1, v(3))));
        ax = cross(z, v); s = norm(ax);
        if s > 1e-12
            ax = ax / s; th = atan2(s, v(3));
            K = [0 -ax(3) ax(2); ax(3) 0 -ax(1); -ax(2) ax(1) 0];
            Rsw = eye(3) + sin(th)*K + (1-cos(th))*K*K;
        else
            Rsw = eye(3);
        end
        Rtw = Rsw' * E;
        yaw(t) = abs(atan2d(Rtw(2,1), Rtw(1,1)));
    end
    for q = 1:5
        i0 = st.(SEG{q,2}); i1 = st.(SEG{q,3});
        TOT(k,q) = mean(tot(i0:i1)); YAW(k,q) = mean(yaw(i0:i1)); TIL(k,q) = mean(til(i0:i1));
    end
end
su = unique(sj);
agg = @(v) mean(arrayfun(@(x) mean(v(sj == x), 'omitnan'), su));
fprintf('\n%-14s %8s %8s %8s\n', 'segment', 'total', 'yaw', 'tilt');
for q = 1:5
    fprintf('%-14s %8.1f %8.1f %8.1f\n', SEG{q,1}, agg(TOT(:,q)), agg(YAW(:,q)), agg(TIL(:,q)));
end
