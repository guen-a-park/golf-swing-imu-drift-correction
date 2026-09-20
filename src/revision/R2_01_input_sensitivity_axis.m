%% [R2-1] R2_01_input_sensitivity_axis.m
%  Examines along which axis D_Vision moves when the inputs are perturbed.
%  R2_01_input_sensitivity_test.m : same computation, but reports the 3-axis components instead of the norm.
%  For each perturbation, one input component (u/v, cx/cy, fx/fy, Tx/Ty/Tz) is perturbed at a time, and,
%  the result of the component with the largest norm is used as that perturbation's representative value.
%
%  Output : results/R2_01_input_sensitivity_axis.csv
%  2026-09-03
%% ========================================================================
clc; clear;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);

CLUB = 1; TRIALS = 21:30;                % driver evaluation set, same as the propagation table
EXCLUDED = [2 1 10; 6 1 3; 8 1 30];
fx = 1195.360; fy = 1190.848; cx = 732.411; cy = 531.828;

R2w_0819 = [-0.00993943 -0.04524376 -0.99892653;
             0.99994787  0.00188487 -0.01003496;
             0.00233687 -0.9989742   0.04522267];
R2w_0821 = [-0.00688193, -0.04392766, -0.99901101;
             0.99992209,  0.01010223, -0.00733241;
             0.01041433, -0.99898364,  0.04385471];
R2w_0822 = [ 0.00180867, -0.04664263, -0.99891;
             0.99989627,  0.01435758,  0.00114005;
             0.01428876, -0.99880845,  0.04666376];
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
club_length = [1135 1125 1100 1120 1107 1125 1087 1130 1125 1102];

load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');

PERT = { '2D wrist detection, both instants shifted by 1 px', 'uv_common', 1
         '2D wrist detection, the two instants shifted oppositely by 1 px', 'uv_opp',    1
         'principal point 1 px',                                    'pp',        1
         'focal length 1 %',                                 'f',         0.01
         'camera position 10 mm',                            'T',         10
         'club length 10 mm',                              'L',         10 };
NP = size(PERT,1);

sj = []; DD = [];
for subj = 1:10
    if     ismember(subj,[1 2 3]), R2w = R2w_0819;
    elseif ismember(subj,[4 5 6]), R2w = R2w_0821;
    else,                          R2w = R2w_0822; end
    Tw = T_CAM(subj,:)'; L = club_length(subj);

    for trial = TRIALS
        if any(all(EXCLUDED == [subj CLUB trial], 2)), continue; end
        g = swingData_2508(subj).clubN(CLUB).trialN(trial);
        if isempty(g) || isempty(g.dl), continue; end
        add = double(g.add); imp = double(g.imp);
        pa = g.dl(add,4:5); pi = g.dl(imp,4:5);
        if any(~isfinite([pa pi])), continue; end

        K = struct('fx',fx,'fy',fy,'cx',cx,'cy',cy);
        D0 = local_D(pa, pi, R2w, Tw, L, K);
        if any(~isfinite(D0)), continue; end

        row = nan(NP,3);
        for k = 1:NP
            e = PERT{k,3}; d = nan(3,3);
            switch PERT{k,2}
                case 'uv_common'
                    d(1,:) = local_d(pa+[e 0], pi+[e 0], R2w, Tw, L, K, D0);
                    d(2,:) = local_d(pa+[0 e], pi+[0 e], R2w, Tw, L, K, D0);
                case 'uv_opp'
                    d(1,:) = local_d(pa+[e 0], pi-[e 0], R2w, Tw, L, K, D0);
                    d(2,:) = local_d(pa+[0 e], pi-[0 e], R2w, Tw, L, K, D0);
                case 'pp'
                    K2 = K; K2.cx = K.cx + e; d(1,:) = local_d(pa, pi, R2w, Tw, L, K2, D0);
                    K2 = K; K2.cy = K.cy + e; d(2,:) = local_d(pa, pi, R2w, Tw, L, K2, D0);
                case 'f'
                    K2 = K; K2.fx = K.fx*(1+e); d(1,:) = local_d(pa, pi, R2w, Tw, L, K2, D0);
                    K2 = K; K2.fy = K.fy*(1+e); d(2,:) = local_d(pa, pi, R2w, Tw, L, K2, D0);
                case 'T'
                    for ax = 1:3
                        T2 = Tw; T2(ax) = T2(ax) + e;
                        d(ax,:) = local_d(pa, pi, R2w, T2, L, K, D0);
                    end
                case 'L'
                    d(1,:) = local_d(pa, pi, R2w, Tw, L+e, K, D0);
            end
            n = vecnorm(d, 2, 2);
            [~, bi] = max(n);                 % input component with the largest norm
            row(k,:) = d(bi,:);
        end
        sj(end+1,1) = subj; %#ok<AGROW>
        DD(end+1,:,:) = reshape(row, 1, NP, 3); %#ok<AGROW>
    end
end

fprintf('\n%d trials\n\n%-40s %10s %10s %10s %10s\n', numel(sj), ...
    'perturbation', 'dX fore-aft', 'dY lateral', 'dZ vertical', 'magnitude');
rows = {};
for k = 1:NP
    v = nan(1,3);
    for a = 1:3, v(a) = local_subj(DD(:,k,a), sj)/10; end
    fprintf('%-40s %10.2f %10.2f %10.2f %10.2f\n', PERT{k,1}, v, norm(v));
    rows(end+1,:) = {PERT{k,1}, v(1), v(2), v(3), norm(v)}; %#ok<SAGROW>
end
writetable(cell2table(rows, 'VariableNames', {'perturbation','dX','dY','dZ','magnitude'}), ...
    fullfile(thisDir, 'results', 'R2_01_input_sensitivity_axis.csv'));
fprintf('\nsaved: results/R2_01_input_sensitivity_axis.csv\n');


function D = local_D(pa, pi, R2w, Tw, L, K)
    D = local_rec(pi, R2w, Tw, L, K) - local_rec(pa, R2w, Tw, L, K);
end
function v = local_d(pa, pi, R2w, Tw, L, K, D0)
    D = local_D(pa, pi, R2w, Tw, L, K);
    if any(~isfinite(D)), v = [NaN NaN NaN]; else, v = D - D0; end
end
function Xw = local_rec(pix, R2w, Tw, L, K)
    rc = [(pix(1)-K.cx)/K.fx; (pix(2)-K.cy)/K.fy; 1];
    rw = R2w * rc;
    a = dot(rw,rw); b = 2*dot(rw,Tw); c = dot(Tw,Tw) - L^2;
    disc = b^2 - 4*a*c;
    if disc < 0, Xw = [NaN;NaN;NaN]; return; end
    s = [(-b+sqrt(disc))/(2*a), (-b-sqrt(disc))/(2*a)];
    s = s(s > 0);
    if isempty(s), Xw = [NaN;NaN;NaN]; return; end
    Xw = (Tw + max(s)*rw)';
end
function m = local_subj(v, subj)
    su = unique(subj(isfinite(subj)));
    sm = arrayfun(@(s) mean(v(subj==s), 'omitnan'), su);
    sm = sm(isfinite(sm));
    if isempty(sm), m = NaN; else, m = mean(sm); end
end
