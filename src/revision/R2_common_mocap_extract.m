%% [shared] R2_common_mocap_extract.m
%  extracts and stores, in a single loop, the motion capture based metrics commonly needed for the revision.
%  Output : revision/results/R2_common_mocap_metrics.mat  (+ .csv)

clc; clear; close all;

%% paths
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
baseDir = fileparts(thisDir);
OUT_DIR = fullfile(thisDir, 'results');
if ~isfolder(OUT_DIR), mkdir(OUT_DIR); end

%% settings
subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN = ["driver","iron","fast"];
CLUBS  = [1 3];
NTRIAL = [30 30 10];

apdm_rate = 200;
ts        = 1/apdm_rate;
cut_freq  = 15;                      % same as the original analysis (swing1127_withml_3d_0304.m)
[bf, af]  = butter(4, cut_freq/(apdm_rate/2));

club_length      = [1135 1125 1100 1120 1107 1125 1087 1130 1125 1102];
club_length_iron = [ 954  922  910  935  907  932  922  927  918  912];

EXCLUDED = [ 5 3  5; 9 3  8; 8 1 30; 2 1 10; 6 1  3];
TEST_TRIALS = containers.Map({1, 3}, {21:30, 1:10});

%% data loading
fprintf('Loading swing data...\n');
load(fullfile(baseDir, 'swingData_2508_aftercal_imp+1_est.mat'), 'swingData_2508');

%% trial loop
rows = {};
for subj = 1:10
    for club = CLUBS
        for trial = 1:NTRIAL(club)
            if any(all(EXCLUDED == [subj club trial], 2)), continue; end

            g = swingData_2508(subj).clubN(club).trialN(trial);
            if isempty(g) || isempty(g.marker), continue; end

            add = double(g.add); bst = double(g.bst);
            imp = double(g.imp); fin = min(double(g.fin), 900);

            WristU = g.marker(:,13:15);
            WristL = g.marker(:, 7: 9);
            abs_wrist = (WristU + WristL) ./ 2;          % [900 x 3], mm, ball = origin

            n = size(abs_wrist, 1);
            vel = zeros(n, 3);
            for d = 1:3
                vel(:,d) = local_deriv5(abs_wrist(:,d), ts);
            end
            vel = filtfilt(bf, af, vel);                 % mm/s

            L_add = norm(abs_wrist(add,:));
            L_bst = norm(abs_wrist(bst,:));
            L_imp = norm(abs_wrist(imp,:));
            if club == 2, L_assumed = club_length_iron(subj);
            else,         L_assumed = club_length(subj);
            end

            if size(g.dl, 2) >= 3
                com      = (g.marker(:,1:3) + g.marker(:,4:6)) ./ 2;
                motionag = g.dl(:,1:3) + com;
                D_ag = motionag(imp,:) - motionag(add,:);
            else
                D_ag = [NaN NaN NaN];
            end

            D_ref = abs_wrist(imp,:) - abs_wrist(add,:);            % mm
            if isfield(g, 'add_est') && isfield(g, 'imp_est') && ...
               all(isfinite(g.add_est)) && all(isfinite(g.imp_est))
                D_vid    = g.imp_est - g.add_est;
                addEst   = g.add_est;
                impEst   = g.imp_est;
            else
                D_vid = [NaN NaN NaN]; addEst = [NaN NaN NaN]; impEst = [NaN NaN NaN];
            end

            isTest = ismember(trial, TEST_TRIALS(club));

            rows(end+1,:) = { subj, string(subjN(subj)), club, string(clubN(club)), trial, isTest, ...
                add, bst, imp, fin, ...
                L_assumed, L_add, L_bst, L_imp, ...
                abs_wrist(add,1), abs_wrist(add,2), abs_wrist(add,3), ...
                abs_wrist(imp,1), abs_wrist(imp,2), abs_wrist(imp,3), ...
                vel(add,1), vel(add,2), vel(add,3), norm(vel(add,:)), ...
                vel(bst,1), vel(bst,2), vel(bst,3), norm(vel(bst,:)), ...
                vel(imp,1), vel(imp,2), vel(imp,3), norm(vel(imp,:)), ...
                vel(fin,1), vel(fin,2), vel(fin,3), norm(vel(fin,:)), ...
                D_ref(1), D_ref(2), D_ref(3), D_ag(1), D_ag(2), D_ag(3), ...
                D_vid(1), D_vid(2), D_vid(3), ...
                addEst(1), addEst(2), addEst(3), impEst(1), impEst(2), impEst(3) }; %#ok<SAGROW>
        end
    end
    fprintf('  subject %d done\n', subj);
end

M = cell2table(rows, 'VariableNames', { ...
    'subj','subjName','club','clubName','trial','isTest', ...
    'idxADD','idxBST','idxIMP','idxFIN', ...
    'L_assumed','L_add','L_bst','L_imp', ...
    'wristADD_x','wristADD_y','wristADD_z', ...
    'wristIMP_x','wristIMP_y','wristIMP_z', ...
    'vADD_x','vADD_y','vADD_z','vADD_norm', ...
    'vBST_x','vBST_y','vBST_z','vBST_norm', ...
    'vIMP_x','vIMP_y','vIMP_z','vIMP_norm', ...
    'vFIN_x','vFIN_y','vFIN_z','vFIN_norm', ...
    'Dref_x','Dref_y','Dref_z','Dag_x','Dag_y','Dag_z', ...
    'Dvid_x','Dvid_y','Dvid_z', ...
    'addEst_x','addEst_y','addEst_z','impEst_x','impEst_y','impEst_z'});

writetable(M, fullfile(OUT_DIR, 'R2_common_mocap_metrics.csv'));
meta = struct('unit_position', 'mm', 'unit_velocity', 'mm/s', ...
    'cutoff_Hz', cut_freq, 'fs_Hz', apdm_rate, ...
    'note', 'ball at origin; wrist = midpoint of upper/lower wrist markers');
save(fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'), 'M', 'meta', ...
    'club_length', 'club_length_iron');

fprintf('\n%d trials extracted (driver %d, fast %d)\n', height(M), ...
    sum(M.club == 1), sum(M.club == 3));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_common_mocap_metrics.csv'));
fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_common_mocap_metrics.mat'));

%% local functions
function xdot = local_deriv5(x, h)
    x = x(:);
    n = numel(x);
    xdot = zeros(n, 1);
    xdot(1)   = (-3*x(5) + 16*x(4) - 36*x(3) + 48*x(2) - 25*x(1)) / (12*h);
    xdot(2)   = ( x(5) - 6*x(4) + 18*x(3) - 10*x(2) - 3*x(1)) / (12*h);
    xdot(n)   = ( 3*x(n) + 10*x(n-1) - 18*x(n-2) + 6*x(n-3) - x(n-4)) / (12*h);
    xdot(n-1) = (25*x(n) - 48*x(n-1) + 36*x(n-2) - 16*x(n-3) + 3*x(n-4)) / (12*h);
    for i = 3:n-2
        xdot(i) = (-x(i+2) + 8*x(i+1) - 8*x(i-1) + x(i-2)) / (12*h);
    end
end
