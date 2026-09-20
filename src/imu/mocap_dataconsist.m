clc; clear all; close all;

swingData_2508_raw=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});
swingData_2508=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});

subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN = ["driver","iron","vc"];

apdm_rate = 200;
cut_freq = 15;

%clublength code computed separately
add_list = [];
bst_list = [];
imp_list = [];
fin_list = [];

ball = [838.596375	814.377136	91.952133 794.194824	592.358948	45.239159;
    836.574646	812.249512	93.195618 788.617065	585.387695	46.328335;
    841.60022	814.104675	93.196609 744.810059	577.830811	45.657181;
    846.030884	820.807739	88.19648 746.806702	584.185547	41.137775;
    845.601868	824.024841	89.09301 746.637817	578.424438	41.504715;
    710.705383	832.099487	88.826866 666.062561	575.6474	41.311615;
    722.651917	805.771729	71.482384 723.462891	572.73291	44.552494;
    721.436646	814.351501	92.618736 624.580688	564.091248	43.764008;
    723.972168	802.872131	95.282928 623.928528	574.946289	45.632282;
    718.566528	811.990234	92.708427 653.612244	564.491089	44.207191];

% 
for subj = 3 %some end frames have no data, so NaN may appear
% for subj = [1 3 5 8 9]
    % for club = 1:2
    for club = [1 3]

        % apdm_path = '<DATA_ROOT>\imu';
        % apdm_path = strjoin([apdm_path, "\", subjN(subj), "\", clubN(club)], '');
        % apdm_files = dir(fullfile(apdm_path, '*.h5'));
        % % sort by creation time (ascending - oldest first)
        % [~, idx] = sort([apdm_files.datenum]);
        % apdm_files = apdm_files(idx);

        mocap_path = fullfile(dataRoot(), 'mocap');
        mocap_path = strjoin([mocap_path, "\", subjN(subj), "\",clubN(club)], '');
        mocap_files = dir(fullfile(mocap_path, '*.csv'));
        [~, idx] = sort({mocap_files.name});  % sort file names in ascending order
        mocap_files = mocap_files(idx);
        
        % dl_path = '<DATA_ROOT>\video';
        % dl_path = strjoin([dl_path, "\", subjN(subj), "\", clubN(club)], '');
        % dl_files = dir(fullfile(dl_path, '*.csv'));
        % [~, idx] = sort({dl_files.name});
        % dl_files = dl_files(idx);

        for trial = 1:30
        %in club3, 1~5 are normal, 6~15 are fastshot %ignoring dl and apdm for now

        % for trial = 1
            % apdm_filePath = fullfile(apdm_path, apdm_files(trial).name);
            % [q_apdm, init_time] = load_APDM(apdm_filePath, apdm_rate, cut_freq);
            % apdm_data = [q_apdm.golf.rawacc.x, q_apdm.golf.rawacc.y, q_apdm.golf.rawacc.z q_apdm.golf.gyro.x, ...
            %     q_apdm.golf.gyro.y, q_apdm.golf.gyro.z, q_apdm.golf.magnet.x, q_apdm.golf.magnet.y, q_apdm.golf.magnet.z];
            % 
            % dl_filePath = fullfile(dl_path, dl_files(trial).name);
            % dataTable_dl= readmatrix(dl_filePath);
            % pose_est = dataTable_dl(:,1:12);

            mocap_filePath = fullfile(mocap_path, mocap_files(trial).name);
            dataTable_mocap= readmatrix(mocap_filePath);

            % the start point can differ per csv
            if dataTable_mocap(2,1)==200
                start_index = dataTable_mocap(6,1);
                marker = dataTable_mocap(6:end,[3:20 24:26]);
            else
                start_index = dataTable_mocap(4,1);
                marker = dataTable_mocap(4:end,[3:20 24:26]);
            end
            % % case where the nexus start frame was adjusted
            % if start_index ~=1
            %     apdm_data = apdm_data(start_index:end,:);
            % end

            % % marker data filtering
            cut_freq = 15; %the smaller the number, the blunter it gets
            [b, a] = butter(4, cut_freq/(200/2));
            marker = filtfilt(b,a,marker);
    
            % define column index patterns
            cols_x = 1:3:size(marker, 2);  % 1, 4, 7, ...
            cols_y = 2:3:size(marker, 2);  % 2, 5, 8, ...
            cols_z = 3:3:size(marker, 2);  % 3, 6, 9, ...
            
            if club==3
                marker(:, cols_x) = marker(:, cols_x) - ball(subj,1);  % subtract ball's first value from the x coordinate
                marker(:, cols_y) = marker(:, cols_y) - ball(subj,2);  % subtract ball's second value from the y coordinate
                marker(:, cols_z) = marker(:, cols_z) - ball(subj,3);  % subtract ball's third value from the z coordinate
            else
                marker(:, cols_x) = marker(:, cols_x) - ball(subj,club*3-2);  % subtract ball's first value from the x coordinate
                marker(:, cols_y) = marker(:, cols_y) - ball(subj,club*3-1);  % subtract ball's second value from the y coordinate
                marker(:, cols_z) = marker(:, cols_z) - ball(subj,club*3);  % subtract ball's third value from the z coordinate
            end

            % define the wrist position as the midpoint of front and back
            mocap_lwrist = (marker(:,7:9)+marker(:,13:15))./2;

            % align axes with t5
            % temp = apdm_data;
            % apdm_data(:,1) = -temp(:,2);
            % apdm_data(:,2) = temp(:,1);
            % apdm_data(:,3) = temp(:,3);
            % % gyro direction
            % apdm_data(:,4) = -temp(:,5);
            % apdm_data(:,5) = temp(:,4);
            % apdm_data(:,6) = temp(:,6);
            % % magnet direction
            % apdm_data(:,7) = -temp(:,8);
            % apdm_data(:,8) = temp(:,7);
            % apdm_data(:,9) = temp(:,9);

            % figure(trial)
            % plot(apdm_data(:,4:6))

            %% calculate swing phase
            mocap_ch = marker(:,19:21);
            delta_t = 1/200;
            %Calculate the difference (derivative) for each XYZ component
            % diff_mocap_ch = diff(mocap_ch) / delta_t; % length decreases by one
            [dot1,ddot1] = deriv5(mocap_ch(1:end,1),delta_t);
            [dot2,ddot2] = deriv5(mocap_ch(1:end,2),delta_t);
            [dot3,ddot3] = deriv5(mocap_ch(1:end,3),delta_t);

            diff_mocap_ch = [dot1 dot2 dot3];
            % cut_freq = 15;
            % % data filtering
            % [b, a] = butter(4, cut_freq/(200/2));
            % diff_mocap_ch = filtfilt(b, a, diff_mocap_ch);
            % t9_data = filtfilt(b,a,t9_data);
            chs = sqrt(sum(diff_mocap_ch.^2, 2));


            % figure(trial+1000)
            % plot(chs)

            threshold = 100;
            min_distance = 100;
            time_data = 1:length(mocap_ch);

            % find local maxima
            [pks_max, locs_max] = findpeaks(chs, 'MinPeakHeight', threshold);  % find maxima

            % invert the data to find local minima
            [pks_min, locs_min] = findpeaks(-chs, 'MinPeakDistance', min_distance);  % find minima
            pks_min = -pks_min;  % convert local minima back to the original values

            % merge local maxima and local minima into one list
            pks = [pks_max; pks_min];  % combine local maxima and local minima
            locs = [locs_max; locs_min];  % combine the positions of local maxima and local minima

            % sort by position
            [locs, sort_idx] = sort(locs);  % sort by locs_combined
            pks = pks(sort_idx);  % sort pks_combined to match the sorted order

            % 1. define impact (IMP) as the location of the maximum peak
            [~, imp_idx] = max(pks);
            imp_time = time_data(locs(imp_idx));

            % 2. define the top of the backswing (BST) as the location of the minimum before IMP
            bst_idx = find(locs < locs(imp_idx), 1, 'last');
            bst_time = time_data(locs(bst_idx));
            %% if the gap between the two is within 20, drop one; it catches a double peak
            if (imp_time-bst_time)<20
                bst_idx = bst_idx-1;
            end
            bst_time = time_data(locs(bst_idx));

            % % 4. define address (ADD) as the data start or the onset of change (here using the minimum location

            
            % it catches the slight lift of the club, so subtract 300 from bst
            % correcting with the add value this way does not seem good
            % if subj==3
            %     add_threshold=10;
            %     % find all indices below a given index whose value is <= threshold_value
            %     add_indexes = find(chs(1:bst_time) <= add_threshold);
            %     add_time = add_indexes(end);
            %     % check the condition and update
            %     while apdm_data(add_time, 2) < -9.8
            %         % check add_indexes one by one from the end
            %         add_indexes(end) = []; % remove the last index
            %         if isempty(add_indexes)
            %             error('No index satisfying the condition was found.');
            %         end
            %         add_time = add_indexes(end); % set the new add_time
            %     end
            % elseif subj==2
            %     add_time = bst_time-400;
            % else
            %     add_time = bst_time-300;
            % end
            
            %% address method mine
            add_threshold=10;
            % find all indices below a given index whose value is <= threshold_value
            add_indexes = find(chs(1:bst_time) <= add_threshold);
            add_time = add_indexes(end);
            % check the condition and update
            % disp(apdm_data(add_time, 2)) % all wrong? 
            %apdm_data itself is correct; why does it differ after being moved.. maybe because 1 was not added
            % needs a full re-check

            % while apdm_data(add_time, 2) < -9.8
            %     % disp(apdm_data(add_time, 2))
            %     % check add_indexes one by one from the end
            %     add_indexes(end) = []; % remove the last index
            %     if isempty(add_indexes)
            %         error('No index satisfying the condition was found.');
            %     end
            %     add_time = add_indexes(end); % set the new add_time
            % end
            % 


            % %% address method ms
            % %%%% find the address time point
            % % cjs, kdc tended not to be detected well
            % 
            % add_time=find_address(chs ,bst_time);

    
            % 5. set finish (FIN) as the minimum after IMP
            fin_idx = find(locs(imp_idx)<locs, 1, 'first');
            fin_time = time_data(locs(fin_idx));
            % prevent catching a double peak; if the value is larger than 10000, add 1 to index
            if chs(fin_time) > 10000
                fin_idx = fin_idx+1;
            end
            fin_time = time_data(locs(fin_idx));

            % ms heuristic compare  %% the heuristic seems more accurate than filtering by chs
            % IMP = min_peak(s.T5wristGyro(:,2));
            % using imu gyro
            % IMP = min_peak(apdm_data(:,5));

            % check the segment for detecting imp from the markers
            % if bst_time>IMP
            %     data = mocap_ch(bst_time:bst_time+200, 2);
            % % elseif trial==21
            % %     data = mocap_ch(bst_time:IMP+100, 2);
            % 
            % else 
            %     data = mocap_ch(bst_time:IMP+10, 2); 
            % end

                            % check the segment for detecting imp from the markers
            % if bst_time>IMP
            %     data = mocap_ch(bst_time:bst_time+200, 2);
            % else
            %     data = mocap_ch(bst_time:IMP+10, 2);
            % end

            % detect the change along the global y axis: find where it switches from - to +
            % sign_change = diff(data > 0);  % find the point where the value changes from negative to positive
            % pos_ind = find(sign_change == 1);  % find the index of the values that turned positive % minus 1 makes it the negative point
            % % imp_marker = pos_ind(1)+bst_time;
            % imp_marker = pos_ind+bst_time; % plotting it directly, this seems more correct



            %just visualize the trajectory
            figure(10000)
            hold on;
            
            if club==1
                plot(mocap_lwrist(imp_time-350:imp_time+100,:),'k')
            else
                plot(mocap_lwrist(imp_time-350:imp_time+100,:),'m')
            end
            % 
            % figure(subj)
            % xlim([0 700])
            % hold on;
            % plot(mocap_lwrist(imp_time-500:imp_time+200,:))

            % hold on;
            % if club==3 && trial>5
            %     plot(mocap_lwrist(imp_time-400:imp_time+100,:),'r')
            % elseif club==1
            %     plot(mocap_lwrist(imp_time-400:imp_time+100,:),'k')
            % % else
            % %     plot(mocap_lwrist(imp_time-350:imp_time+100,:),'b')
            % end



            % % check the swing phase
            % figure(trial+100)
            % plot(chs)
            % % xline([ add_time bst_time imp_time IMP fin_time],'-',{'ADD','BST','IMP','imp imu','FIN'},'HandleVisibility','off');
            % xline([ add_time bst_time imp_marker imp_time IMP fin_time],'-',{'ADD','BST','imp marker','IMP','imp imu','FIN'},'HandleVisibility','off');
            % xlim([add_time-100 fin_time+100])
            % hold on;
            % 
            % swing_phase = [add_time bst_time imp_marker fin_time];
            % 
            % %% interpolation
            % % interpolation somehow worked up to this point..
            % 
            % fs1 = 200; % 200 Hz sampling rate
            % fs2 = 150;
            % 
            % % data size
            % data1_length = length(apdm_data);
            % data2_length = length(pose_est);
            % 
            % % create time vector
            % t1 = (0:data1_length-1) / fs1; % time vector of the 200Hz data
            % t2 = (0:data2_length-1) / fs2; % time vector of the 30Hz data
            % 
            % % new time vector for interpolation (same as the 200Hz time vector)
            % % t_new = t1;
            % t_new = 0 : 1/fs1 : t2(end);
            % pose_est_interp = interp1(t2, pose_est(:,1:12), t_new, 'linear', 'extrap');
            % 
            % cut_freq = 10; %the smaller the number, the blunter it gets
            % [b, a] = butter(4, cut_freq/(200/2));
            % pose_est_interp = filtfilt(b,a,pose_est_interp);
            % 
            % 
            % % figure(trial)
            % % hold on;
            % % plot(mocap_lwrist(:,3));
            % % plot(pose_est_interp(:,3));
            % 
            % 
            % 
            % % synchronize by the z maximum
            % % threshold = 100;
            % % [pks_mark, locs_mark] = findpeaks(mocap_lwrist(:,3), 'MinPeakHeight', threshold);  % find maxima
            % % [~, mark_idx] = max(pks_mark);
            % % mark_max = locs_mark(mark_idx);
            % % mark_start = mark_max-mark_max+1;
            % % 
            % % [pks_vid, locs_vid] = findpeaks(pose_est_interp(:,3), 'MinPeakHeight', threshold);
            % % [~, vid_idx] = max(pks_vid);
            % % vid_max = locs_vid(vid_idx);
            % % % usually the video recording is started first
            % 
            % 
            % % just align the synchronization to vid?
            % 
            % % synchronize by the y maximum %finding imp separately is ok, but add does not match with z max
            % threshold = 100;
            % [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
            % [~, mark_idx] = max(pks_mark);
            % mark_max = locs_mark(mark_idx);
            % mark_start = mark_max-mark_max+1;
            % 
            % [pks_vid, locs_vid] = findpeaks(-pose_est_interp(:,2), 'MinPeakHeight', threshold);
            % [~, vid_idx] = max(pks_vid);
            % vid_max = locs_vid(vid_idx);
            % 
            % 
            % if vid_max>mark_max
            %     vid_start = vid_max-mark_max+1;
            % else
            %     mark_start = mark_max -vid_max+1;
            %     vid_start = 1;
            %     disp('the video is shorter')
            % end
            % 
            % marker = marker(mark_start:end,:);
            % % pelvis = marker(:,31:33);
            % 
            % 
            % mocap_lwrist = mocap_lwrist(mark_start:end,:);
            % pose_est_interp = pose_est_interp(vid_start:end,:);
            % %handle the case where the video is shorter
            % apdm_data = apdm_data(mark_start:end,:);
            % swing_phase = swing_phase-mark_start;
            % 
            % 
            % % %0721 improved impact estimation from the video
            % % find the minimum in the data after bst_time
            % [min_value, min_idx_relative] = min(pose_est_interp(swing_phase(2):end,3));
            % % actual index in the full data
            % min_idx_absolute = min_idx_relative + swing_phase(2) - 1;
            % swing_phase(5) = min_idx_absolute;
            % 
            % % figure(trial+200)
            % % hold on;
            % % plot(mocap_lwrist(:,3));
            % % plot(pose_est_interp(:,3));
            % 
            % 
            % % check synchronization
            % for j = 1:3
            %     figure(trial*3+j)
            %     hold on;
            %     % plot(mocap_lwrist(:,j)-pelvis(:,j),'LineWidth', 1.5);
            %     plot(mocap_lwrist(:,j),'LineWidth', 1.5);
            %     plot(pose_est_interp(:,j),'LineWidth', 1.5);
            %     % plot(swing_phase(1),add_est(j)-pelvis(swing_phase(1),j), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r')
            %     % plot(swing_phase(3),imp_est(j)-pelvis(swing_phase(3),j), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r')
            %     % figure(trial*20+j)
            %     % hold on;
            %     % plot(apdm_data(:,j));
            %     xline(swing_phase,'-',{'ADD','BST','IMP','FIN','vid_imp'},'HandleVisibility','off');
            %     % xline([tpose_index,tpose_index+50,npose_index,npose_index+50],'-',{'t','t','n','n'},'HandleVisibility','off');
            % end
            % 
            % % 
            % % figure(10000)
            % % plot(pose_est_interp(:,4:5))
            % 
            % % figure(trial*100)
            % % plot(pose_est_interp(:,4:5));
            % % hold on;
            % % xline(swing_phase,'-',{'ADD','BST','IMP','FIN','vid_imp'},'HandleVisibility','off');
            % % xline([tpose_index,tpose_index+50,npose_index,npose_index+50],'-',{'t','t','n','n'},'HandleVisibility','off');
            % 
            % 
            % trialData = struct('add', swing_phase(1), ...
            %     'bst', swing_phase(2), ...
            %     'imp', swing_phase(3), ...
            %     'fin', swing_phase(4), ...
            %     'vid_imp',swing_phase(5),...
            %     'marker', marker,...
            %     'apdm',apdm_data,'dl',pose_est_interp);
            % 
            % swingData_2508_raw(subj).clubN(club).trialN(trial) =trialData;
            % 
            % %process trialData along the time axis
            % fps = 200;
            % 
            % % Desired time window in seconds around old_imp
            % time_before = 3.5; % seconds before old_imp
            % time_after = 1;    % seconds after old_imp
            % 
            % % Calculate corresponding number of samples
            % samples_before = time_before * fps; % 3.5 s * 200 fps = 700 samples
            % samples_after = time_after * fps;   % 1 s * 200 fps = 200 samples
            % 
            % old_imp = trialData.imp;
            % % set the new imp value to 700
            % new_imp = 700;
            % 
            % % set the data segment (relative to old_imp)
            % start_idx = old_imp - samples_before;
            % end_idx = old_imp + samples_after;
            % 
            % 
            % trialData = struct('add', swing_phase(1), ...
            %     'bst', swing_phase(2), ...
            %     'imp', swing_phase(3), ...
            %     'fin', swing_phase(4), ...
            %     'vid_imp', swing_phase(5), ...
            %     'marker', marker,...
            %     'apdm',apdm_data,'dl',pose_est_interp);
            % 
            % % extract only the data in the selected segment for each data field
            % % 1104 what is this code? it seems to mean there is data after fin
            % fields = {'marker','apdm','dl'};
            % for j = 1:length(fields)
            %     fieldName = fields{j};
            %     data = trialData.(fieldName);
            % 
            %     % check whether the data is inside the segment and extract it
            %     % if the video is short, pad with the last value
            %     if start_idx > 0 && end_idx <= size(data, 1)
            %         trialData.(fieldName) = data(start_idx:end_idx-1, :);
            %     elseif end_idx > size(data, 1)
            %         additional_rows = end_idx - size(data, 1);
            %         last_row = data(end, :);
            %         padding = repmat(last_row, additional_rows, 1);
            %         extended_data = [data; padding];
            %         trialData.(fieldName) = extended_data(start_idx:end_idx-1, :);
            %     else
            %         disp('Warning: Data index out of bounds.');
            %     end
            % end
            % 
            % % proportionally adjust the other field values (add, bst, fin)
            % bst_offset = old_imp - trialData.bst;
            % add_offset = old_imp - trialData.add;
            % if trialData.vid_imp <old_imp
            %     vid_offset = old_imp - trialData.vid_imp;
            % else
            %     vid_offset = trialData.vid_imp-old_imp;
            % end
            % fin_offset = trialData.fin - old_imp;
            % 
            % % revise again after the meeting..
            % % trialData.imp = new_imp;
            % % trialData.bst = new_imp - bst_offset;
            % % trialData.add = new_imp - add_offset;
            % % trialData.fin = new_imp + fin_offset;
            % 
            % % 701 matched; using 702 for imp position accuracy based on the imp marker
            % trialData.imp = new_imp+1; % 0721 set back to 701 for position accuracy
            % % trialData.imp = new_imp+1;
            % % trialData.imp = new_imp;
            % trialData.bst = new_imp - bst_offset+1;
            % trialData.add = new_imp - add_offset+1;
            % trialData.fin = new_imp + fin_offset+1;
            % 
            % if trialData.vid_imp <old_imp
            %     % trialData.vid_imp = new_imp - vid_offset+1;
            %     trialData.vid_imp = new_imp - vid_offset+2; % 0721 final attempt at synchronization
            % else
            %     % trialData.vid_imp = new_imp + vid_offset+1;
            %     trialData.vid_imp = new_imp + vid_offset+2;
            % end
            % 
            % 
            % 
            % 
            % swingData_2508(subj).clubN(club).trialN(trial) =trialData;
            % 
            % % figure(200)
            % % plot(trialData.apdm(:,4:6))
        end
    end
end



function [q, t0_out] = load_APDM(h5_path, apdm_rate, cut_freq, t0_in)

if nargin < 4
    t0_in = nan;
end

deviceID = {'12395'}; %id 11513
[b, a] = butter(4, cut_freq/(apdm_rate/2));
q = struct();

for i = 1:length(deviceID)
    id = deviceID{i};
    try
        name = h5readatt(h5_path, ['/Sensors/', id, '/Configuration'], 'Label 0');
    catch ME
        if strcmp(ME.identifier,  'MATLAB:imagesci:hdf5lib:libraryError')
            % id of a device not included
            continue
        else
            rethrow(ME)
        end
    end
    name = name(isletter(name));
    name = lower(name);

    % local_acc_ = h5read(h5_path, ['/Sensors/', id, '/Accelerometer'])';
    % raw_acc_ = filtfilt(b, a, local_acc_);
    % gyro_ = filtfilt(b, a, h5read(h5_path, ['/Sensors/', id, '/Gyroscope'])');

    %0430 for raw data processing
    raw_acc_ = h5read(h5_path, ['/Sensors/', id, '/Accelerometer'])';
    gyro_ = h5read(h5_path, ['/Sensors/', id, '/Gyroscope'])';
    %0703 magnetometer
    mag_ = h5read(h5_path, ['/Sensors/', id, '/Magnetometer'])';

    quat_ = h5read(h5_path, ['/Processed/', id, '/Orientation'])';
    % acc_ = filtfilt(b, a, quatrotate(quat_, quatrotate(quatinv(quat_), local_acc_) - [0, 0, 9.81]));

    q.(name).rawacc = struct('x', raw_acc_(:, 1), 'y', raw_acc_(:, 2), 'z', raw_acc_(:, 3));
    % q.(name).acc = struct('x', acc_(:, 1), 'y', acc_(:, 2), 'z', acc_(:, 3));
    q.(name).gyro = struct('x', gyro_(:, 1), 'y', gyro_(:, 2), 'z', gyro_(:, 3));
    q.(name).magnet = struct('x', mag_(:, 1), 'y', mag_(:, 2), 'z', mag_(:, 3));

    if i == 1
        time_ = h5read(h5_path, ['/Sensors/', id, '/Time']);
        t0_out = time_(1);
        if isnan(t0_in)
            q.time = 1e-6 * double(time_ - time_(1));
        else
            q.time = 1e-6 * double(time_ - t0_in);
        end
    end
end
end


%% function for phase detection
% seems to be imu heuristic code, re-check later

function Ind = max_peak(vector)
% global peakrange
% vector(1:peakrange) = 0;
max_val = max(vector);
vector(vector< max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector);
Ind = peak_ind(end);
end

function Ind = min_peak(vector)
% global peakrange
% vector(1:peakrange) = mean(vector);
vector = mean(vector)-vector;
max_val = max(vector);
vector(vector< max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector);
if length(peak_ind)==0 peak_ind=50; end
Ind = peak_ind(end);
end

function Ind = min_peak_beforeMax(vector,range,num)
% vector(1:ignore) = mean(vector);
max_val = max(vector);
vector_in_range=vector;
vector_in_range(vector_in_range < max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector_in_range);
max_ind = peak_ind(end);
vector=vector(max_ind-range*200:max_ind);
vector = max(vector(:)) - vector;
[~, peak_ind] = findpeaks(vector);
Ind = peak_ind(end-num+1)+max_ind-range*200-1;
end

function Ind = min_beforeMax_threshold(vector,threshold,num)
max_val = max(vector);
vector_in_range=vector;
vector_in_range(vector_in_range < max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector_in_range);
if length(peak_ind)==0 peak_ind=length(vector); end
max_ind = peak_ind(end);
vector=vector(1:max_ind);
max_vec=max(vector(:));
vector = max_vec - vector;
vector(vector<max_vec-threshold)=0;    % threshold=20 deg/s
[~, peak_ind] = findpeaks(vector);
if length(peak_ind)==0 peak_ind=50; end
Ind = peak_ind(end-num+1);
end

function Ind = min_afterMax_threshold(vector,from,threshold,num)
vector=vector(from:end);
max_vec=max(vector(:));
vector = max_vec - vector;
vector(vector<max_vec-threshold)=0;    % threshold=20 deg/s
[~, peak_ind] = findpeaks(vector);
if length(peak_ind)==0 peak_ind=30; end
Ind = peak_ind(1)+from-1;
end

function Ind = find_address(vector,backswingtop)
vector = vector(1:backswingtop-100);    % 0.5sec before backswingtop
max_val=max(vector(:));
vector = max_val - vector;
vector(vector<max_val-0.3)=0;
[~, peak_ind] = findpeaks(vector);
Ind = peak_ind(end);
end