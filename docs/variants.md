# Script variants

Several analyses were run by copying a pipeline script and changing a few
configuration lines. Only the base script of each family is kept here. The
exact difference of every variant is recorded below, so any variant can be
reproduced by applying the listed changes to its base script.

## `src/imu/swing1127_withml_3d_0304.m`

Wrist trajectory reconstruction pipeline: orientation estimation, velocity correction under the approximate zero-velocity assumption, displacement correction with the inferred constraint, and evaluation against motion capture.

5900 lines. 19 variant(s):

<details><summary><code>src/revision/R2_07_misalignment.m</code> — 218 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_misalignment.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_MIS = [];   % [subj trial angle_deg rms_ratio]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +199 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +306 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +428 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -779,0 +816,17 @@
+            % ---- [R2-7] sensor-to-segment fixed rotation estimate (Wahba) ----
+            %   solves for the R_off satisfying gyro ~ R_off * gL_wrist by least squares over the swing.
+            R2_07_seg = g.add:g.fin;
+            R2_07_a = gL_wrist(R2_07_seg,:);      % marker-based local angular velocity
+            R2_07_b = gyro_data(R2_07_seg,:);     % gyroscope (sensor frame)
+            if all(isfinite(R2_07_a(:))) && all(isfinite(R2_07_b(:)))
+                R2_07_B = R2_07_b' * R2_07_a;
+                [R2_07_U, ~, R2_07_V] = svd(R2_07_B);
+                R2_07_R = R2_07_U * diag([1 1 det(R2_07_U*R2_07_V')]) * R2_07_V';
+                R2_07_ang = real(acosd(max(-1, min(1, (trace(R2_07_R)-1)/2))));
+                R2_07_res = R2_07_b' - R2_07_R * R2_07_a';
+                R2_07_rms = norm(R2_07_res, 'fro') / max(norm(R2_07_b', 'fro'), eps);
+                R2_07_MIS(end+1,:) = [subj trial R2_07_ang R2_07_rms]; %#ok<AGROW>
+            end
+            % ---- [R2-7] end ----
+
+
@@ -852 +905 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +982,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1479,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1631 @@
+            % Myeongseop's code
@@ -1601 +1695 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1911 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2111,71 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_03_traj_store_ori%d.mat', OrientationMethod)), 'R2_03_store', '-v7.3');
+
+%% [R2-7] save the sensor-to-segment misalignment result
+if ~isempty(R2_07_MIS)
+    R2_07_T = array2table(R2_07_MIS, 'VariableNames', {'subj','trial','angle_deg','rms_ratio'});
+    writetable(R2_07_T, fullfile(R2_08_res, 'R2_07_misalignment.csv'));
+    fprintf('\n===== [R2-7] sensor-to-segment fixed rotation (marker angular velocity -> gyroscope) =====\n');
+    fprintf('%-6s %14s %14s %8s\n', 'subj', 'rot. angle (deg)', 'residual ratio', 'n');
+    for R2_07_su = 1:10
+        R2_07_m = R2_07_MIS(:,1) == R2_07_su;
+        if ~any(R2_07_m), continue; end
+        fprintf('P%-5d %14.1f %14.3f %8d\n', R2_07_su, ...
+            mean(R2_07_MIS(R2_07_m,3)), mean(R2_07_MIS(R2_07_m,4)), sum(R2_07_m));
+    end
+    fprintf('saved: %s\n', fullfile(R2_08_res, 'R2_07_misalignment.csv'));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +4016,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_orifilter_store.m</code> — 225 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_orifilter_store.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_MIS = [];   % [subj trial angle_deg rms_ratio]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,15 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 7;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});
+R2_07_ORI = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'time',{},'acc',{},'gyro',{},'R2Lw',{},'Rinf',{},'R2tri',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +200 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +307 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +429 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -779,0 +817,17 @@
+            % ---- [R2-7] sensor-to-segment fixed rotation estimate (Wahba) ----
+            %   solves for the R_off satisfying gyro ~ R_off * gL_wrist by least squares over the swing.
+            R2_07_seg = g.add:g.fin;
+            R2_07_a = gL_wrist(R2_07_seg,:);      % marker-based local angular velocity
+            R2_07_b = gyro_data(R2_07_seg,:);     % gyroscope (sensor frame)
+            if all(isfinite(R2_07_a(:))) && all(isfinite(R2_07_b(:)))
+                R2_07_B = R2_07_b' * R2_07_a;
+                [R2_07_U, ~, R2_07_V] = svd(R2_07_B);
+                R2_07_R = R2_07_U * diag([1 1 det(R2_07_U*R2_07_V')]) * R2_07_V';
+                R2_07_ang = real(acosd(max(-1, min(1, (trace(R2_07_R)-1)/2))));
+                R2_07_res = R2_07_b' - R2_07_R * R2_07_a';
+                R2_07_rms = norm(R2_07_res, 'fro') / max(norm(R2_07_b', 'fro'), eps);
+                R2_07_MIS(end+1,:) = [subj trial R2_07_ang R2_07_rms]; %#ok<AGROW>
+            end
+            % ---- [R2-7] end ----
+
+
@@ -852 +906 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +983,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -996,0 +1059,6 @@
+                    if club == 1 && trial >= 21
+                        R2_07_ORI(end+1) = struct('subj', subj, 'trial', trial, ...
+                            'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                            'time', time, 'acc', acc_data, 'gyro', gyro_data, ...
+                            'R2Lw', R2Lw, 'Rinf', Rinf, 'R2tri', R2tri); %#ok<SAGROW>
+                    end
@@ -1417,0 +1486,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1638 @@
+            % Myeongseop's code
@@ -1601 +1702 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1918 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2118,71 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, 'R2_07_orifilter_store.mat'), 'R2_07_ORI', '-v7.3');
+
+%% [R2-7] save the sensor-to-segment misalignment result
+if ~isempty(R2_07_MIS)
+    R2_07_T = array2table(R2_07_MIS, 'VariableNames', {'subj','trial','angle_deg','rms_ratio'});
+    writetable(R2_07_T, fullfile(R2_08_res, 'R2_07_misalignment.csv'));
+    fprintf('\n===== [R2-7] sensor-to-segment fixed rotation (marker angular velocity -> gyroscope) =====\n');
+    fprintf('%-6s %14s %14s %8s\n', 'subj', 'rot. angle (deg)', 'residual ratio', 'n');
+    for R2_07_su = 1:10
+        R2_07_m = R2_07_MIS(:,1) == R2_07_su;
+        if ~any(R2_07_m), continue; end
+        fprintf('P%-5d %14.1f %14.3f %8d\n', R2_07_su, ...
+            mean(R2_07_MIS(R2_07_m,3)), mean(R2_07_MIS(R2_07_m,4)), sum(R2_07_m));
+    end
+    fprintf('saved: %s\n', fullfile(R2_08_res, 'R2_07_misalignment.csv'));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +4023,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_swing1127_ori0.m</code> — 88 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_swing1127_ori0.m
@@ -2 +2,14 @@
-clc; clear all; close all;
+%% [R2-7] R2_07_swing1127_ori0.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori0.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +17,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +48,9 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+OrientationMethod=0;   % [R2-7] markers throughout (0) / reference initial orientation + gyro integration (1)
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -270 +285 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +407 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +867 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +944,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1537,0 +1561 @@
+            % Myeongseop's code
@@ -1601 +1625 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1841 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2041,13 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori0.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3888,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori0.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_swing1127_ori1.m</code> — 88 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_swing1127_ori1.m
@@ -2 +2,14 @@
-clc; clear all; close all;
+%% [R2-7] R2_07_swing1127_ori1.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori1.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +17,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +48,9 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+OrientationMethod=1;   % [R2-7] markers throughout (0) / reference initial orientation + gyro integration (1)
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -270 +285 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +407 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +867 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +944,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1537,0 +1561 @@
+            % Myeongseop's code
@@ -1601 +1625 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1841 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2041,13 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori1.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3888,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori1.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_m1.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_m1.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by -1 sample ----
+            R2Lw = circshift(R2Lw, -1, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift-1');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift-1.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_m2.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_m2.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by -2 samples ----
+            R2Lw = circshift(R2Lw, -2, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift-2');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift-2.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_m3.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_m3.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by -3 samples ----
+            R2Lw = circshift(R2Lw, -3, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift-3');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift-3.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_p1.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_p1.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by +1 sample ----
+            R2Lw = circshift(R2Lw, 1, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift+1');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift+1.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_p2.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_p2.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by +2 samples ----
+            R2Lw = circshift(R2Lw, 2, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift+2');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift+2.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_sync_p3.m</code> — 183 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_sync_p3.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -757,0 +793,3 @@
+            % ---- [R2-7] shift the marker orientation by +3 samples ----
+            R2Lw = circshift(R2Lw, 3, 3);
+            % ---- [R2-7] end ----
@@ -852 +890 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +967,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1464,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1616 @@
+            % Myeongseop's code
@@ -1601 +1680 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1896 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2096,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori0_shift+3');
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_07_sync_store_shift+3.mat')), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3985,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_traj_ori0.m</code> — 184 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_traj_ori0.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori0_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +305 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +427 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +887 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +964,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1461,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1613 @@
+            % Myeongseop's code
@@ -1601 +1677 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1893 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2093,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_03_traj_store_ori%d.mat', OrientationMethod)), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3982,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_traj_ori1.m</code> — 184 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_traj_ori1.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 1;                      %% [R2-7] markers throughout (0) / reference initial orientation (1)
+R2_08_mlTag  = 'seed1';
+R2_08_mlRun  = 'R2_07_ori1_seed1';
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +305 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +427 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +887 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +964,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1461,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1613 @@
+            % Myeongseop's code
@@ -1601 +1677 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1893 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2093,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_03_traj_store_ori%d.mat', OrientationMethod)), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3982,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_vel_ori0.m</code> — 196 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_vel_ori0.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_VEL = [];   % [subj trial |v(add)| |v(bst)| |v(fin)|]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 0;                      %% <<< set to 7 or 8 and run
+R2_08_mlTag  = 'seed3';                %% tag used in the result file name
+R2_08_mlRun  = 'R2_07_ori0_seed1';  %% ML result folder (without the runs_ prefix)
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +199 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +306 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +428 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +888 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +965,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1298,0 +1343,5 @@
+            % ---- [R2-7] integrated velocity before correction (m/s) ----
+            R2_07_VEL(end+1,:) = [subj trial ...
+                norm(imu_vel(g.add,:))/1000, norm(imu_vel(g.bst,:))/1000, ...
+                norm(imu_vel(g.fin,:))/1000]; %#ok<AGROW>
+            % ---- [R2-7] end ----
@@ -1416,0 +1466,32 @@
+
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
@@ -1537,0 +1619 @@
+            % Myeongseop's code
@@ -1601 +1683 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1899 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2099,61 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+if ~isempty(R2_07_VEL)
+    writetable(array2table(R2_07_VEL, 'VariableNames', {'subj','trial','v_add','v_bst','v_fin'}), ...
+        fullfile(R2_08_res, sprintf('R2_07_vel_ori%d.csv', OrientationMethod)));
+    fprintf('\n[R2-7] ori%d integrated velocity before correction (m/s) : add %.2f  bst %.2f  fin %.2f\n', ...
+        OrientationMethod, mean(R2_07_VEL(:,3)), mean(R2_07_VEL(:,4)), mean(R2_07_VEL(:,5)));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3994,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_vel_ori1.m</code> — 196 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_vel_ori1.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_VEL = [];   % [subj trial |v(add)| |v(bst)| |v(fin)|]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 1;                      %% <<< set to 7 or 8 and run
+R2_08_mlTag  = 'seed3';                %% tag used in the result file name
+R2_08_mlRun  = 'R2_07_ori1_seed1';  %% ML result folder (without the runs_ prefix)
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +199 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +306 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +428 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +888 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +965,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1298,0 +1343,5 @@
+            % ---- [R2-7] integrated velocity before correction (m/s) ----
+            R2_07_VEL(end+1,:) = [subj trial ...
+                norm(imu_vel(g.add,:))/1000, norm(imu_vel(g.bst,:))/1000, ...
+                norm(imu_vel(g.fin,:))/1000]; %#ok<AGROW>
+            % ---- [R2-7] end ----
@@ -1416,0 +1466,32 @@
+
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
@@ -1537,0 +1619 @@
+            % Myeongseop's code
@@ -1601 +1683 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1899 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2099,61 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+if ~isempty(R2_07_VEL)
+    writetable(array2table(R2_07_VEL, 'VariableNames', {'subj','trial','v_add','v_bst','v_fin'}), ...
+        fullfile(R2_08_res, sprintf('R2_07_vel_ori%d.csv', OrientationMethod)));
+    fprintf('\n[R2-7] ori%d integrated velocity before correction (m/s) : add %.2f  bst %.2f  fin %.2f\n', ...
+        OrientationMethod, mean(R2_07_VEL(:,3)), mean(R2_07_VEL(:,4)), mean(R2_07_VEL(:,5)));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3994,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_vel_ori7.m</code> — 196 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_vel_ori7.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_VEL = [];   % [subj trial |v(add)| |v(bst)| |v(fin)|]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 7;                      %% <<< set to 7 or 8 and run
+R2_08_mlTag  = 'seed3';                %% tag used in the result file name
+R2_08_mlRun  = 'R2_03_calib20_seed3';  %% ML result folder (without the runs_ prefix)
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +199 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +306 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +428 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +888 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +965,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1298,0 +1343,5 @@
+            % ---- [R2-7] integrated velocity before correction (m/s) ----
+            R2_07_VEL(end+1,:) = [subj trial ...
+                norm(imu_vel(g.add,:))/1000, norm(imu_vel(g.bst,:))/1000, ...
+                norm(imu_vel(g.fin,:))/1000]; %#ok<AGROW>
+            % ---- [R2-7] end ----
@@ -1416,0 +1466,32 @@
+
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
@@ -1537,0 +1619 @@
+            % Myeongseop's code
@@ -1601 +1683 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1899 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2099,61 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+if ~isempty(R2_07_VEL)
+    writetable(array2table(R2_07_VEL, 'VariableNames', {'subj','trial','v_add','v_bst','v_fin'}), ...
+        fullfile(R2_08_res, sprintf('R2_07_vel_ori%d.csv', OrientationMethod)));
+    fprintf('\n[R2-7] ori%d integrated velocity before correction (m/s) : add %.2f  bst %.2f  fin %.2f\n', ...
+        OrientationMethod, mean(R2_07_VEL(:,3)), mean(R2_07_VEL(:,4)), mean(R2_07_VEL(:,5)));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3994,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_07_vel_ori8.m</code> — 196 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_07_vel_ori8.m
@@ -2 +2,30 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
+R2_07_VEL = [];   % [subj trial |v(add)| |v(bst)| |v(fin)|]
@@ -3,0 +33,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +64,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 8;                      %% <<< set to 7 or 8 and run
+R2_08_mlTag  = 'seed3';                %% tag used in the result file name
+R2_08_mlRun  = 'R2_08_ori8_seed5';  %% ML result folder (without the runs_ prefix)
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +199 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +306 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +428 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +888 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +965,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1298,0 +1343,5 @@
+            % ---- [R2-7] integrated velocity before correction (m/s) ----
+            R2_07_VEL(end+1,:) = [subj trial ...
+                norm(imu_vel(g.add,:))/1000, norm(imu_vel(g.bst,:))/1000, ...
+                norm(imu_vel(g.fin,:))/1000]; %#ok<AGROW>
+            % ---- [R2-7] end ----
@@ -1416,0 +1466,32 @@
+
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
@@ -1537,0 +1619 @@
+            % Myeongseop's code
@@ -1601 +1683 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1899 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2099,61 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+if ~isempty(R2_07_VEL)
+    writetable(array2table(R2_07_VEL, 'VariableNames', {'subj','trial','v_add','v_bst','v_fin'}), ...
+        fullfile(R2_08_res, sprintf('R2_07_vel_ori%d.csv', OrientationMethod)));
+    fprintf('\n[R2-7] ori%d integrated velocity before correction (m/s) : add %.2f  bst %.2f  fin %.2f\n', ...
+        OrientationMethod, mean(R2_07_VEL(:,3)), mean(R2_07_VEL(:,4)), mean(R2_07_VEL(:,5)));
+end
+
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3994,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_08_swing1127_ori8.m</code> — 88 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_08_swing1127_ori8.m
@@ -2 +2,14 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_swing1127_ori8.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +17,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +48,9 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+OrientationMethod=8;   % [R2-8] heading (yaw) alignment condition
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -270 +285 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +407 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +867 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +944,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1537,0 +1561 @@
+            % Myeongseop's code
@@ -1601 +1625 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1841 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2041,13 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori8.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3888,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori8.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_08_trajectory_error.m</code> — 184 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_08_trajectory_error.m
@@ -2 +2,29 @@
-clc; clear all; close all;
+%% [R2-8] R2_08_trajectory_error.m
+%  trajectory error, heading-aligned condition (ori8) against the reference condition (ori7)
+%  ------------------------------------------------------------------------
+%  runs the swing1127 pipeline as is and computes the error of the proposed trajectory
+%  (traj_lin_subj, corrected with the ML-inferred D) against motion capture, by phase and by event,
+%
+%  in the same format as Tables 2 and 3. change only the two constants below per condition.
+%    R2_08_ORI   : 7 (magnetometer heading) or 8 (motion capture heading alignment)
+%    mldataDir   : the run folder trained under that condition
+%
+%  output : revision/results/R2_08_traj_error_{seg,evt}_ori{N}_{tag}.csv
+%
+%  2026-08-28
+%
+%  --- below is based on the original swing1127_withml_3d_0304.m ---
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +32,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +63,14 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+R2_08_ORI    = 7;                      %% <<< set to 7 or 8 and run
+R2_08_mlTag  = 'seed3';                %% tag used in the result file name
+R2_08_mlRun  = 'R2_03_calib20_seed3';  %% ML result folder (without the runs_ prefix)
+OrientationMethod = R2_08_ORI;
+R2_08_err = {}; R2_08_evt = {};   %% buffers accumulating the trajectory error
+R2_03_store = struct('subj',{},'trial',{},'add',{},'bst',{},'imp',{},'fin',{},'imu_trajCal',{},'Mtraj',{});   %% [R2-3] condition-independent material
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -163 +198 @@
-mldataDir = fullfile(runsRoot(), 'runs_0112_accgyro_400800_ori7traj2'); %use run 2 for now
+mldataDir = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ['runs_' R2_08_mlRun]);   % [R2-8] run folder for this condition
@@ -270 +305 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +427 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +887 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +964,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1417,0 +1461,32 @@
+            %% ===== [R2-3] save condition-independent trajectory material =====
+            %  since traj_lin_subj = imu_trajCal - w(t)*(imu_trajCal(IMP) - D_ml),
+            %  with imu_trajCal and Mtraj alone the trajectory error for any D_ml is immediate.
+            %  (no need to rerun the pipeline for each condition)
+            if club == 1 && trial >= 21
+                R2_03_store(end+1) = struct('subj', subj, 'trial', trial, ...
+                    'add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900), ...
+                    'imu_trajCal', imu_trajCal, 'Mtraj', Mtraj); %#ok<SAGROW>
+            end
+
+            %% ===== [R2-8] accumulate trajectory error (test set only) =====
+            if club == 1 && trial >= 21
+                R2_08_pts = struct('add', g.add, 'bst', g.bst, 'imp', g.imp, 'fin', min(g.fin,900));
+                R2_08_rng = {'Backswing','add','bst'; 'Downswing','bst','imp'; ...
+                             'FollowThrough','imp','fin'; 'EntireSwing','add','fin'};
+                for rr = 1:size(R2_08_rng,1)
+                    i0 = R2_08_pts.(R2_08_rng{rr,2});
+                    i1 = R2_08_pts.(R2_08_rng{rr,3});
+                    e  = Mtraj(i0:i1,:) - traj_lin_subj(i0:i1,:);      % proposed trajectory (ML-inferred D)
+                    R2_08_err(end+1,:) = { subj, trial, R2_08_rng{rr,1}, ...
+                        mean(vecnorm(e,2,2))/10, mean(abs(e(:,1)))/10, ...
+                        mean(abs(e(:,2)))/10, mean(abs(e(:,3)))/10 }; %#ok<SAGROW>
+                end
+                for pn = {'add','bst','imp','fin'}
+                    ii = R2_08_pts.(pn{1});
+                    ep = Mtraj(ii,:) - traj_lin_subj(ii,:);
+                    R2_08_evt(end+1,:) = { subj, trial, upper(pn{1}), norm(ep)/10, ...
+                        abs(ep(1))/10, abs(ep(2))/10, abs(ep(3))/10 }; %#ok<SAGROW>
+                end
+            end
+
+
@@ -1537,0 +1613 @@
+            % Myeongseop's code
@@ -1601 +1677 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1893 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2093,55 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+
+%% ===== [R2-8] aggregate and save the trajectory error =====
+E = cell2table(R2_08_err, 'VariableNames', ...
+    {'subj','trial','segment','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+V = cell2table(R2_08_evt, 'VariableNames', ...
+    {'subj','trial','event','err_norm_cm','err_x_cm','err_y_cm','err_z_cm'});
+
+R2_08_res = fullfile(R2_08_thisDir, 'results');
+if ~isfolder(R2_08_res), mkdir(R2_08_res); end
+R2_08_tag = sprintf('ori%d_%s', OrientationMethod, R2_08_mlTag);
+writetable(E, fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+save(fullfile(R2_08_res, sprintf('R2_03_traj_store_ori%d.mat', OrientationMethod)), 'R2_03_store', '-v7.3');
+writetable(V, fullfile(R2_08_res, ['R2_08_traj_error_evt_' R2_08_tag '.csv']));
+
+% aggregation per participant (the same way as in the manuscript)
+fprintf('\n===== [R2-8] trajectory error (%s), driver test set, per-participant mean ± SD (cm) =====\n', R2_08_tag);
+segs = {'Backswing','Downswing','FollowThrough','EntireSwing'};
+for s = 1:numel(segs)
+    k = strcmp(E.segment, segs{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & E.subj == su;
+        if any(m2), sm(su) = mean(E.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  %-15s %6.2f ± %-6.2f  (n=%d subj)\n', segs{s}, mean(sm), std(sm), numel(sm));
+end
+evts = {'ADD','BST','IMP','FIN'};
+fprintf('  --- event instants ---\n');
+for s = 1:numel(evts)
+    k = strcmp(V.event, evts{s});
+    sm = nan(10,1);
+    for su = 1:10
+        m2 = k & V.subj == su;
+        if any(m2), sm(su) = mean(V.err_norm_cm(m2)); end
+    end
+    sm = sm(~isnan(sm));
+    fprintf('  @%-14s %6.2f ± %-6.2f\n', evts{s}, mean(sm), std(sm));
+end
+fprintf('\nsaved: %s\n', fullfile(R2_08_res, ['R2_08_traj_error_seg_' R2_08_tag '.csv']));
+return
+
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3982,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>

<details><summary><code>src/revision/R2_common_swing1127_ori7.m</code> — 88 changed lines</summary>

```diff
--- src/imu/swing1127_withml_3d_0304.m
+++ src/revision/R2_common_swing1127_ori7.m
@@ -2 +2,14 @@
-clc; clear all; close all;
+%% [shared] R2_common_swing1127_ori7.m
+%  copy of swing1127_withml_3d_0304.m. it differs from the original only in the four points below.
+%    (1) OrientationMethod = 8 (new). identical to case 7 except that the initial yaw (heading) is
+%        aligned to motion capture instead of the magnetometer. roll/pitch stay accelerometer-based.
+%        -> group the switch into `case {7, 8}` and branch only on psi
+%    (2) extended to club = [1 3], trial = 1:30 (needed to build the mat for ML training)
+%    (3) runs from revision/, so the parent folder is added to the path
+%    (4) finally the ML training mat is saved as multimodal/swingData_2508_forML_ori8.mat
+%
+%  note: the saved variable must stay named swingData_2508 (python reads that key).
+%
+%  2026-08-28
+
+clc; clear all; close all; %#ok<CLALL>
@@ -3,0 +17,6 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_08_thisDir = fileparts(mfilename('fullpath'));
+R2_08_baseDir = fileparts(R2_08_thisDir);
+addpath(R2_08_baseDir);
+addpath(genpath(fullfile(fileparts(R2_08_baseDir), 'GolfSwing_0424')));
@@ -29,13 +48,9 @@
-OrientationMethod=7;
-
-% method 0: imu only (no correction)
-% method 1: imu_trajCal   velocity correction
-% method 2: imu_trajCalL  velocity + circular trajectory
-% method 3: imu_trajCalI  velocity + marker impact coordinates  <-- not usable in this script.
-%           imu_trajCalI is the trajectory re-integrated after removing the accelerometer bias
-%           back-solved so that it matches mocap at impact, and that computation (imu_biasImp, sumRI)
-%           exists only in draw_figure1.m, not here. Selecting it raises an error below.
-% method 4: apdm_trajCalV velocity + video estimate (D_Vision correction)
-% method 5: traj_lin_subj velocity + IMU inference  (D_Infer correction)  <-- proposed method of the manuscript
-% method 6: ml_traj_check direct ML trajectory output
-mae_method =5;   % Tables 2/3 of the manuscript were produced under this setting
+OrientationMethod=7;   % the reference condition used in the manuscript (for regeneration)
+
+% method 0: imu only
+% method 1: apdm_trajCal velocity correction
+% method 2: apdm_trajCalL velocity + circular trajectory
+% method 3: apdm_trajCalI velocity + marker imp coordinates
+% method 4: apdm_trajCalV velocity + video estimate
+% 5-> imu with cal // 6-> ml
+mae_method =0;
@@ -270 +285 @@
-    for club = 1
+    for club = [1 3]
@@ -392 +407 @@
-        for trial = 21:30
+        for trial = 1:30
@@ -852 +867 @@
-                case 7  % extract roll,pitch using the pilot-data formula % comes out well
+                case {7, 8}  % roll and pitch from the pilot-data formulation % works well
@@ -929 +944,9 @@
-
+                    %% [R2-8] case 8 : initial heading alignment
+                    %  roll and pitch are estimated from the accelerometer as in case 7
+                    %  only yaw (heading) is aligned to motion capture instead of the magnetometer.
+                    %  what reviewer R2-8 asked for, "realigning ... reference frames at the
+                    %  beginning of the trial" refers to heading (yaw) alignment in context,
+                    %  so that the roll/pitch error stays at the usual IMU level.
+                    if OrientationMethod == 8
+                        psi = deg2rad(yaw_marker);
+                    end
@@ -1537,0 +1561 @@
+            % Myeongseop's code
@@ -1601 +1625 @@
-                % angle error about each axis (radians converted to degrees)imu_trajCalI
+                % angle error about each axis (radians converted to degrees)
@@ -1817,3 +1841 @@
-                    % imu_trajCalI is not computed in this script (see draw_figure1.m).
-                    error(['mae_method=3 (imu_trajCalI) is not supported in this script. ', ...
-                           'Use draw_figure1.m or set mae_method to 4 or 5.']);
+                    test_drift = imu_trajCalI; % should probably be changed to project onto the actual marker
@@ -2018,0 +2041,13 @@
+%% ===== [R2-8] save the mat for ML training, then stop =====
+%  the only purpose of this copy is to build the ML training dataset for the ori8 condition.
+%  the statistics and figure code below is hard-coded for the test set (99 trials),
+%  so they are not run in this script, which is extended to trial 1:30 x club [1 3].
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+return
+
+
@@ -3852,0 +3888,9 @@
+
+%% ===== [R2-8] save the mat for ML training =====
+%  the variable name must stay swingData_2508 (python reads md['swingData_2508'])
+R2_08_outMat = fullfile(fileparts(fileparts(R2_08_baseDir)), 'multimodal', ...
+                        'swingData_2508_forML_ori7.mat');
+fprintf('\n[R2-8] saving ML dataset -> %s\n', R2_08_outMat);
+save(R2_08_outMat, 'swingData_2508', '-v7');   % compatible with scipy.io.loadmat (v7.3 cannot be read)
+fprintf('[R2-8] done.\n');
+
```

</details>


## `src/figures/draw_figure5.m`

Figure 5 of the manuscript.

5667 lines. 2 variant(s):

<details><summary><code>src/revision/R2_11_draw_figure5_copy.m</code> — 117 changed lines</summary>

```diff
--- src/figures/draw_figure5.m
+++ src/revision/R2_11_draw_figure5_copy.m
@@ -3,3 +3,10 @@
-%% Fig4&5 to be organised here
-
-clc; clear all; close all;
+%% [R2-11] copy of draw_figure5.m
+%  original: 250819_golf/draw_figure5.m
+%  there are only two changes; everything else is identical to the original.
+%    (1) fixes the deriv5 return-orientation problem : [dot1 dot2 dot3] -> [dot1(:) dot2(:) dot3(:)]
+%        (the path held two deriv5 variants, 5-point row and 3-point column, which made runs inconsistent)
+%    (2) collects the per-participant trajectory arrays into R2_11_store and saves them to results/ (for the R2-11 band-width analysis)
+%
+%  Figures 4 and 5 are produced here
+
+clc; clear all; close all; %#ok<CLALL>
@@ -6,0 +14,5 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_11_thisDir = fileparts(mfilename('fullpath'));
+addpath(fileparts(R2_11_thisDir));
+addpath(genpath(fullfile(fileparts(fileparts(R2_11_thisDir)), 'GolfSwing_0424')));
@@ -54 +66 @@
-% 7: derive roll pitch from IMU values only, take yaw as the mean -> extended to also work with magnetometer
+% 7:derive roll pitch from imu values only, yaw from the mean -> extended to also allow magnetometer
@@ -91,2 +103,2 @@
-% must be changed to the number of trials, store per-axis error
-% could this not just be removed?
+% must be changed to the number of trials, stores per-axis error
+% could this just be removed?
@@ -102,2 +114,2 @@
-% not sure whether the way add is detected is a problem
-% subj4 day2 add is odd
+% maybe the way add is detected is the problem
+% subj4 day2 add looks wrong
@@ -107 +119 @@
-% change the event timings
+% change the event point
@@ -130 +142 @@
-dL_vidimu_list = [];   % video+IMU based radial velocity*dt = L_delta_vid
+dL_vidimu_list = [];   % video+IMU-based radial velocity*dt = L_delta_vid
@@ -176 +188 @@
-% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %2 for now ->20.25
+% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %use run 2 for now ->20.25
@@ -179 +191 @@
-% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %2 for now ->19.55
+% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %use run 2 for now ->19.55
@@ -196 +208 @@
-clubs_ml   = {'driver','iron','fast'};      % middle token of the filename
+clubs_ml   = {'driver','iron','fast'};      % middle token of the file name
@@ -202 +214 @@
-% ===== initialise result arrays: 10x3x10 =====
+% ===== initialize result arrays: 10x3x10 =====
@@ -603,2 +615,2 @@
-                Cwdot=[dot1 dot2 dot3];
-                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
+                Cwdot=[dot1(:) dot2(:) dot3(:)];
+                Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; % this is the wrist velocity
@@ -612,2 +624,2 @@
-                WristMdot=[dot1 dot2 dot3];
-                WristMddot=[ddot1 ddot2 ddot3];
+                WristMdot=[dot1(:) dot2(:) dot3(:)];
+                WristMddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -618,2 +630,2 @@
-                WristUdot=[dot1 dot2 dot3];
-                WristUddot=[ddot1 ddot2 ddot3];
+                WristUdot=[dot1(:) dot2(:) dot3(:)];
+                WristUddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -948 +960 @@
-                abs_wrist_dot=[dot1 dot2 dot3];
+                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
@@ -1057 +1069 @@
-                imu_accelCal=[dot1 dot2 dot3];         % global
+                imu_accelCal=[dot1(:) dot2(:) dot3(:)];         % global
@@ -1279,0 +1292 @@
+                % Myeongseop's code
@@ -1517,0 +1531,10 @@
+    %% [R2-11] save preferred swing trajectories (just before the cm conversion, in mm)
+    %  note: the fast loop below overwrites plot_ds_prop, so it must be captured here.
+    R2_11_store(subj_fast).subj  = subj_fast;
+    R2_11_store(subj_fast).nTr   = size(plot_ds_ref, 3);
+    R2_11_store(subj_fast).ref    = plot_ds_ref;     % preferred, motion capture (mm)
+    R2_11_store(subj_fast).propV  = plot_ds_prop;    % preferred, corrected with D_Vision (apdm_trajCalV, mm)
+    R2_11_store(subj_fast).prop   = plot_ds_driver;  % preferred, corrected with D_Infer (traj_lin_subj, mm)
+    %  the Fig. 6 consistency band uses plot_ds_driver (= traj_lin_subj, corrected with the ML-inferred D).
+    %  apdm_trajCalV is the training target corrected with the video-based D, so it is not analysed here.
+
@@ -2063,2 +2086,2 @@
-                Cwdot=[dot1 dot2 dot3];
-                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
+                Cwdot=[dot1(:) dot2(:) dot3(:)];
+                Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; % this is the wrist velocity
@@ -2072,2 +2095,2 @@
-                WristMdot=[dot1 dot2 dot3];
-                WristMddot=[ddot1 ddot2 ddot3];
+                WristMdot=[dot1(:) dot2(:) dot3(:)];
+                WristMddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -2078,2 +2101,2 @@
-                WristUdot=[dot1 dot2 dot3];
-                WristUddot=[ddot1 ddot2 ddot3];
+                WristUdot=[dot1(:) dot2(:) dot3(:)];
+                WristUddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -2393 +2416 @@
-                abs_wrist_dot=[dot1 dot2 dot3];
+                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
@@ -2621 +2644 @@
-                imu_accelCal=[dot1 dot2 dot3];         % global
+                imu_accelCal=[dot1(:) dot2(:) dot3(:)];         % global
@@ -2844,0 +2868 @@
+                % Myeongseop's code
@@ -3006 +3030,9 @@
-
+
+    %% [R2-11] save fast swing trajectories and events (just before the cm conversion, in mm)
+    R2_11_store(subj_fast).nTrFast  = z-1;
+    R2_11_store(subj_fast).ref_fast = plot_ds_ref_fast(:,:,1:z-1);   % fast, motion capture (mm)
+    R2_11_store(subj_fast).prop_fast= plot_ds_fast(:,:,1:z-1);       % fast, proposed corrected trajectory (mm)
+    R2_11_store(subj_fast).add   = event_add_fast(1:z-1);
+    R2_11_store(subj_fast).bst   = event_bst_fast(1:z-1);
+    R2_11_store(subj_fast).imp   = event_imp_fast(1:z-1);
+    R2_11_store(subj_fast).fin   = event_fin_fast(1:z-1);
@@ -5374,0 +5407,9 @@
+%% ===== [R2-11] save material for the band-width analysis =====
+if exist('R2_11_store', 'var')
+    outDir = fullfile(fileparts(mfilename('fullpath')), 'results');
+    if ~isfolder(outDir), mkdir(outDir); end
+    save(fullfile(outDir, 'R2_11_trajectory_store.mat'), 'R2_11_store', '-v7.3');
+    fprintf('\n[R2-11] saved: %s\n', fullfile(outDir, 'R2_11_trajectory_store.mat'));
+end
+
+
@@ -5511 +5552 @@
-% A, B: N×D (numbers such as errors) — A is assumed to be 'proposed', B the 'baseline'
+% A, B: N×D (values such as errors) — assumes A is 'proposed' and B is 'baseline'
@@ -5532 +5573 @@
-    % common mask for removing NaN
+    % common mask for NaN removal
@@ -5585 +5626 @@
-            % Wilcoxon signed-rank (for small n it is exact → no z)
+            % Wilcoxon signed-rank (exact for small n → no z)
@@ -5587 +5628 @@
-            n_eff = sum(A~=B);                         % effective n with zero differences excluded
+            n_eff = sum(A~=B);                         % effective n excluding zero differences
@@ -5606 +5647 @@
-        % independent-samples comparison
+        % independent-sample comparison
@@ -5616 +5657 @@
-            % Mann-Whitney U (for small n it is exact → no z)
+            % Mann-Whitney U (exact for small n → no z)
@@ -5645 +5686 @@
-                useT = ~h;                 % normality retained → t-test
+                useT = ~h;                 % normality holds → t-test
```

</details>

<details><summary><code>src/revision/R2_11_draw_figure5_yawmocap.m</code> — 125 changed lines</summary>

```diff
--- src/figures/draw_figure5.m
+++ src/revision/R2_11_draw_figure5_yawmocap.m
@@ -3,3 +3,10 @@
-%% Fig4&5 to be organised here
-
-clc; clear all; close all;
+%% [R2-11] copy of draw_figure5.m
+%  original: 250819_golf/draw_figure5.m
+%  there are only two changes; everything else is identical to the original.
+%    (1) fixes the deriv5 return-orientation problem : [dot1 dot2 dot3] -> [dot1(:) dot2(:) dot3(:)]
+%        (the path held two deriv5 variants, 5-point row and 3-point column, which made runs inconsistent)
+%    (2) collects the per-participant trajectory arrays into R2_11_store and saves them to results/ (for the R2-11 band-width analysis)
+%
+%  Figures 4 and 5 are produced here
+
+clc; clear all; close all; %#ok<CLALL>
@@ -6,0 +14,5 @@
+
+% this copy runs from revision/, so add the original folder to the path
+R2_11_thisDir = fileparts(mfilename('fullpath'));
+addpath(fileparts(R2_11_thisDir));
+addpath(genpath(fullfile(fileparts(fileparts(R2_11_thisDir)), 'GolfSwing_0424')));
@@ -54 +66 @@
-% 7: derive roll pitch from IMU values only, take yaw as the mean -> extended to also work with magnetometer
+% 7:derive roll pitch from imu values only, yaw from the mean -> extended to also allow magnetometer
@@ -91,2 +103,2 @@
-% must be changed to the number of trials, store per-axis error
-% could this not just be removed?
+% must be changed to the number of trials, stores per-axis error
+% could this just be removed?
@@ -102,2 +114,2 @@
-% not sure whether the way add is detected is a problem
-% subj4 day2 add is odd
+% maybe the way add is detected is the problem
+% subj4 day2 add looks wrong
@@ -107 +119 @@
-% change the event timings
+% change the event point
@@ -130 +142 @@
-dL_vidimu_list = [];   % video+IMU based radial velocity*dt = L_delta_vid
+dL_vidimu_list = [];   % video+IMU-based radial velocity*dt = L_delta_vid
@@ -176 +188 @@
-% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %2 for now ->20.25
+% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_imuphase5'; %use run 2 for now ->20.25
@@ -179 +191 @@
-% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %2 for now ->19.55
+% mldataDir = '<RUNS_ROOT>\runs_0112_accgyro_400800_ori7traj_ag_imuphase2'; %use run 2 for now ->19.55
@@ -196 +208 @@
-clubs_ml   = {'driver','iron','fast'};      % middle token of the filename
+clubs_ml   = {'driver','iron','fast'};      % middle token of the file name
@@ -202 +214 @@
-% ===== initialise result arrays: 10x3x10 =====
+% ===== initialize result arrays: 10x3x10 =====
@@ -603,2 +615,2 @@
-                Cwdot=[dot1 dot2 dot3];
-                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
+                Cwdot=[dot1(:) dot2(:) dot3(:)];
+                Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; % this is the wrist velocity
@@ -612,2 +624,2 @@
-                WristMdot=[dot1 dot2 dot3];
-                WristMddot=[ddot1 ddot2 ddot3];
+                WristMdot=[dot1(:) dot2(:) dot3(:)];
+                WristMddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -618,2 +630,2 @@
-                WristUdot=[dot1 dot2 dot3];
-                WristUddot=[ddot1 ddot2 ddot3];
+                WristUdot=[dot1(:) dot2(:) dot3(:)];
+                WristUddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -816,0 +829,4 @@
+                        % [changed] uses the motion capture yaw, as in the fast condition.
+                        % in the fast condition a second device disturbed the magnetometer, so no
+                        % magnetometer heading is available; the preferred condition that forms the band
+                        % is therefore put on the same reference.
@@ -818 +834 @@
-                        alpha_deg = rad2deg(atan2(myh, mxh)); % mean error 7.16 deg
+                        alpha_deg = rad2deg(atan2(myh, mxh));
@@ -820 +836 @@
-                        yaw_imu_deg = psi0_deg - alpha_deg;
+                        yaw_imu_deg = yaw_marker;   % [changed] motion capture reference
@@ -948 +964 @@
-                abs_wrist_dot=[dot1 dot2 dot3];
+                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
@@ -1057 +1073 @@
-                imu_accelCal=[dot1 dot2 dot3];         % global
+                imu_accelCal=[dot1(:) dot2(:) dot3(:)];         % global
@@ -1279,0 +1296 @@
+                % Myeongseop's code
@@ -1517,0 +1535,10 @@
+    %% [R2-11] save preferred swing trajectories (just before the cm conversion, in mm)
+    %  note: the fast loop below overwrites plot_ds_prop, so it must be captured here.
+    R2_11_store(subj_fast).subj  = subj_fast;
+    R2_11_store(subj_fast).nTr   = size(plot_ds_ref, 3);
+    R2_11_store(subj_fast).ref    = plot_ds_ref;     % preferred, motion capture (mm)
+    R2_11_store(subj_fast).propV  = plot_ds_prop;    % preferred, corrected with D_Vision (apdm_trajCalV, mm)
+    R2_11_store(subj_fast).prop   = plot_ds_driver;  % preferred, corrected with D_Infer (traj_lin_subj, mm)
+    %  the Fig. 6 consistency band uses plot_ds_driver (= traj_lin_subj, corrected with the ML-inferred D).
+    %  apdm_trajCalV is the training target corrected with the video-based D, so it is not analysed here.
+
@@ -2063,2 +2090,2 @@
-                Cwdot=[dot1 dot2 dot3];
-                Cwddot=[ddot1 ddot2 ddot3]; %this is the wrist velocity
+                Cwdot=[dot1(:) dot2(:) dot3(:)];
+                Cwddot=[ddot1(:) ddot2(:) ddot3(:)]; % this is the wrist velocity
@@ -2072,2 +2099,2 @@
-                WristMdot=[dot1 dot2 dot3];
-                WristMddot=[ddot1 ddot2 ddot3];
+                WristMdot=[dot1(:) dot2(:) dot3(:)];
+                WristMddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -2078,2 +2105,2 @@
-                WristUdot=[dot1 dot2 dot3];
-                WristUddot=[ddot1 ddot2 ddot3];
+                WristUdot=[dot1(:) dot2(:) dot3(:)];
+                WristUddot=[ddot1(:) ddot2(:) ddot3(:)];
@@ -2393 +2420 @@
-                abs_wrist_dot=[dot1 dot2 dot3];
+                abs_wrist_dot=[dot1(:) dot2(:) dot3(:)];
@@ -2621 +2648 @@
-                imu_accelCal=[dot1 dot2 dot3];         % global
+                imu_accelCal=[dot1(:) dot2(:) dot3(:)];         % global
@@ -2844,0 +2872 @@
+                % Myeongseop's code
@@ -3006 +3034,9 @@
-
+
+    %% [R2-11] save fast swing trajectories and events (just before the cm conversion, in mm)
+    R2_11_store(subj_fast).nTrFast  = z-1;
+    R2_11_store(subj_fast).ref_fast = plot_ds_ref_fast(:,:,1:z-1);   % fast, motion capture (mm)
+    R2_11_store(subj_fast).prop_fast= plot_ds_fast(:,:,1:z-1);       % fast, proposed corrected trajectory (mm)
+    R2_11_store(subj_fast).add   = event_add_fast(1:z-1);
+    R2_11_store(subj_fast).bst   = event_bst_fast(1:z-1);
+    R2_11_store(subj_fast).imp   = event_imp_fast(1:z-1);
+    R2_11_store(subj_fast).fin   = event_fin_fast(1:z-1);
@@ -5374,0 +5411,9 @@
+%% ===== [R2-11] save material for the band-width analysis =====
+if exist('R2_11_store', 'var')
+    outDir = fullfile(fileparts(mfilename('fullpath')), 'results');
+    if ~isfolder(outDir), mkdir(outDir); end
+    save(fullfile(outDir, 'R2_11_trajectory_store_yawmocap.mat'), 'R2_11_store', '-v7.3');
+    fprintf('\n[R2-11] saved: %s\n', fullfile(outDir, 'R2_11_trajectory_store_yawmocap.mat'));
+end
+
+
@@ -5511 +5556 @@
-% A, B: N×D (numbers such as errors) — A is assumed to be 'proposed', B the 'baseline'
+% A, B: N×D (values such as errors) — assumes A is 'proposed' and B is 'baseline'
@@ -5532 +5577 @@
-    % common mask for removing NaN
+    % common mask for NaN removal
@@ -5585 +5630 @@
-            % Wilcoxon signed-rank (for small n it is exact → no z)
+            % Wilcoxon signed-rank (exact for small n → no z)
@@ -5587 +5632 @@
-            n_eff = sum(A~=B);                         % effective n with zero differences excluded
+            n_eff = sum(A~=B);                         % effective n excluding zero differences
@@ -5606 +5651 @@
-        % independent-samples comparison
+        % independent-sample comparison
@@ -5616 +5661 @@
-            % Mann-Whitney U (for small n it is exact → no z)
+            % Mann-Whitney U (exact for small n → no z)
@@ -5645 +5690 @@
-                useT = ~h;                 % normality retained → t-test
+                useT = ~h;                 % normality holds → t-test
```

</details>


## `src/revision/R2_01_input_sensitivity.m`

139 lines. 1 variant(s):

<details><summary><code>src/revision/R2_01_input_sensitivity_test.m</code> — 4 changed lines</summary>

```diff
--- src/revision/R2_01_input_sensitivity.m
+++ src/revision/R2_01_input_sensitivity_test.m
@@ -16 +16 @@
-CLUB = 1; TRIALS = 1:30;
+CLUB = 1; TRIALS = 21:30;   % driver evaluation set only, as in the propagation table
@@ -110 +110 @@
-    fullfile(thisDir, 'results', 'R2_01_input_sensitivity.csv'));
+    fullfile(thisDir, 'results', 'R2_01_input_sensitivity_test.csv'));
```

</details>


## `src/revision/R2_10_statistics.m`

262 lines. 1 variant(s):

<details><summary><code>src/revision/R2_10_statistics_test.m</code> — 32 changed lines</summary>

```diff
--- src/revision/R2_10_statistics.m
+++ src/revision/R2_10_statistics_test.m
@@ -1 +1 @@
-%% [R2-10] R2_10_statistics.m
+%% [R2-10] R2_10_test_statistics.m
@@ -20,4 +20,4 @@
-%  Output       : revision/results/R2_10_figure3_accuracy.csv
-%              revision/results/R2_10_correlation_methods.csv
-%              revision/results/R2_10_welch_prior_study.csv
-%              revision/results/fig_R2_10_blandaltman.png/.svg
+%  output    : revision/results/R2_10_test_figure3_accuracy.csv
+%              revision/results/R2_10_test_correlation_methods.csv
+%              revision/results/R2_10_test_welch_prior_study.csv
+%              revision/results/fig_R2_10_test_blandaltman.png/.svg
@@ -41 +41 @@
-Msel = M(M.club == 1, :);                                  % driver
+Msel = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);   % driver evaluation set
@@ -115,2 +115,2 @@
-writetable(Tcor, fullfile(OUT_DIR, 'R2_10_correlation_methods.csv'));
-writetable(Tacc, fullfile(OUT_DIR, 'R2_10_figure3_accuracy.csv'));
+writetable(Tcor, fullfile(OUT_DIR, 'R2_10_test_correlation_methods.csv'));
+writetable(Tacc, fullfile(OUT_DIR, 'R2_10_test_figure3_accuracy.csv'));
@@ -158,2 +158,2 @@
-exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_10_blandaltman.png'), 'Resolution', 300);
-saveas(gcf, fullfile(OUT_DIR, 'fig_R2_10_blandaltman.svg'));
+exportgraphics(gcf, fullfile(OUT_DIR, 'fig_R2_10_test_blandaltman.png'), 'Resolution', 300);
+saveas(gcf, fullfile(OUT_DIR, 'fig_R2_10_test_blandaltman.svg'));
@@ -222,6 +222,6 @@
-writetable(W, fullfile(OUT_DIR, 'R2_10_welch_prior_study.csv'));
-
-fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_10_correlation_methods.csv'));
-fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_figure3_accuracy.csv'));
-fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_welch_prior_study.csv'));
-fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_10_blandaltman.png'));
+writetable(W, fullfile(OUT_DIR, 'R2_10_test_welch_prior_study.csv'));
+
+fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_10_test_correlation_methods.csv'));
+fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_test_figure3_accuracy.csv'));
+fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_10_test_welch_prior_study.csv'));
+fprintf('saved: %s\n', fullfile(OUT_DIR, 'fig_R2_10_test_blandaltman.png'));
```

</details>


## `src/revision/R2_28_motionagformer_comparison.m`

149 lines. 1 variant(s):

<details><summary><code>src/revision/R2_28_motionag_test.m</code> — 16 changed lines</summary>

```diff
--- src/revision/R2_28_motionagformer_comparison.m
+++ src/revision/R2_28_motionag_test.m
@@ -1 +1 @@
-%% [R2-28] R2_28_motionagformer_comparison.m
+%% [R2-28] R2_28_test_motionagformer_comparison.m
@@ -19,2 +19,2 @@
-%  Output       : revision/results/R2_28_method_comparison.csv
-%              revision/results/R2_28_hotelling_williams.csv
+%  output    : revision/results/R2_28_test_method_comparison.csv
+%              revision/results/R2_28_test_hotelling_williams.csv
@@ -34 +34 @@
-Msel = M(M.club == 1, :);                                    % driver
+Msel = M(M.club == 1 & M.trial >= 21 & M.trial <= 30, :);   % driver evaluation set
@@ -77 +77 @@
-writetable(T, fullfile(OUT_DIR, 'R2_28_method_comparison.csv'));
+writetable(T, fullfile(OUT_DIR, 'R2_28_test_method_comparison.csv'));
@@ -81 +81 @@
-writetable(H, fullfile(OUT_DIR, 'R2_28_hotelling_williams.csv'));
+writetable(H, fullfile(OUT_DIR, 'R2_28_test_hotelling_williams.csv'));
@@ -111,2 +111,2 @@
-fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_28_method_comparison.csv'));
-fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_28_hotelling_williams.csv'));
+fprintf('\nsaved: %s\n', fullfile(OUT_DIR, 'R2_28_test_method_comparison.csv'));
+fprintf('saved: %s\n', fullfile(OUT_DIR, 'R2_28_test_hotelling_williams.csv'));
```

</details>

