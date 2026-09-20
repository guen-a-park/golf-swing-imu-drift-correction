clc; clear all; close all;

swingData_2508_raw=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});
swingData_2508=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});

subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN = ["driver","iron","fast"];

apdm_rate = 200;
cut_freq = 15;

%clublength computed separately in its own code
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

% 251124 imu calibration
load swingData_2508_cal.mat

for subj = 1:10  % a few end frames have no data, so NaN may appear
% for subj = [1 3 5 8 9 10] % subjects 4 and 7 have a synchronisation problem
% for subj = 9
    % for club = 3
    for club = 1:3
        apdm_path = fullfile(dataRoot(), 'imu');
        apdm_path = strjoin([apdm_path, "\", subjN(subj), "\", clubN(club)], '');
        apdm_files = dir(fullfile(apdm_path, '*.h5'));
        % sort by creation time (ascending - oldest first)
        [~, idx] = sort([apdm_files.datenum]);
        apdm_files = apdm_files(idx);

        mocap_path = fullfile(dataRoot(), 'mocap');
        mocap_path = strjoin([mocap_path, "\", subjN(subj), "\",clubN(club)], '');
        mocap_files = dir(fullfile(mocap_path, '*.csv'));
        [~, idx] = sort({mocap_files.name});  % sort file names in ascending order
        mocap_files = mocap_files(idx); % shot101 ends up before 99..
        
        dl_path = fullfile(dataRoot(), 'video');
        dl_path = strjoin([dl_path, "\", subjN(subj), "\", clubN(club)], '');
        dl_files = dir(fullfile(dl_path, '*.csv'));
        [~, idx] = sort({dl_files.name});
        dl_files = dl_files(idx);

        % for trial = 8
        % for trial = [ 8 10]
        for trial = 1:30
            if subj==1 && club==2 && trial ==1 % seems to be an apdm recording error
                continue
            elseif subj==5 && club==3 && trial==5 % cannot be extracted from the video at all
                continue
            end
            if club==3 && (trial>10)
                continue;
            end
            
            cal_data = swingData_2508_cal(subj).clubN(club).trialN(trial).apdm;


            apdm_filePath = fullfile(apdm_path, apdm_files(trial).name);
            cut_freq = 15;
            [q_apdm, init_time] = load_APDM(apdm_filePath, apdm_rate, cut_freq);
            apdm_data = [q_apdm.golf.rawacc.x, q_apdm.golf.rawacc.y, q_apdm.golf.rawacc.z q_apdm.golf.gyro.x, ...
                q_apdm.golf.gyro.y, q_apdm.golf.gyro.z, q_apdm.golf.magnet.x, q_apdm.golf.magnet.y, q_apdm.golf.magnet.z];

            dl_filePath = fullfile(dl_path, dl_files(trial).name);
            dataTable_dl= readmatrix(dl_filePath);
            pose_est = dataTable_dl(:,1:12);

            mocap_filePath = fullfile(mocap_path, mocap_files(trial).name);
            dataTable_mocap= readmatrix(mocap_filePath);

            % case post-processed with the grip or the whole pelvis removed
            if size(dataTable_mocap,2) ~= 29
                disp('specific marker removed during post-processing. needs checking')
                fprintf('participant: %d, club : %d, trial : %d\n', subj, club,trial);
                disp(size(dataTable_mocap,2))
                if size(dataTable_mocap,2)==23 %case where the pelvis was removed entirely
                    dataTable_mocap = insert_zero_cols(dataTable_mocap, 3, 6);
                end
            end

            % the start point differs between some csv files
            if dataTable_mocap(2,1)==200
                start_index = dataTable_mocap(6,1);
                if subj==2 && club==3 %this one put the grip at the very end
                    marker = dataTable_mocap(6:end,3:23);
                elseif subj==2 && ((club==1 && trial> 3) ||club==2) % just remove the grip marker
                    marker = dataTable_mocap(6:end,3:23);
                else
                    marker = dataTable_mocap(6:end,[3:20 24:26]); % exclude club grip and origin
                end
            else
                start_index = dataTable_mocap(4,1);
                if subj==2 && club==3
                    marker = dataTable_mocap(4:end,3:23);
                elseif subj==2 && ((club==1 && trial> 3) ||club==2)
                    marker = dataTable_mocap(4:end,3:23);
                else
                    marker = dataTable_mocap(4:end,[3:20 24:26]);
                end
            end
            % case where the nexus start frame was adjusted
            if start_index ~=1
                apdm_data = apdm_data(start_index:end,:);
            end
            

            %% fill data with undetected pelvis with zeros
            % fast has to be checked manually % checked by opening the csv beforehand
            if club==3
                marker(isnan(marker)) = 0;
            end
            % fill the unused pelvis with zeros here and filter it out of the statistics in the main code
            % also open this file and check that nothing at the very end is unfilled
            if subj==2 && club==1 && trial == 10 
                marker(isnan(marker)) = 0;
            elseif subj==2 && club==2 && (trial == 23 || trial == 29)
                marker(isnan(marker)) = 0;
            elseif subj==3 && club==2 && (trial == 1 || trial == 11 || trial == 14 || trial == 15)
                marker(isnan(marker)) = 0;
            elseif subj==6 && club==1 && trial == 3 
                marker(isnan(marker)) = 0;
            end

            % % filter marker data
            cut_freq = 15; %the smaller the number, the blunter it gets
            [b, a] = butter(4, cut_freq/(200/2));
            marker = filtfilt(b,a,marker);

    
            % define column index pattern
            cols_x = 1:3:size(marker, 2);  % 1, 4, 7, ...
            cols_y = 2:3:size(marker, 2);  % 2, 5, 8, ...
            cols_z = 3:3:size(marker, 2);  % 3, 6, 9, ...
            
            if club==3
                marker(:, cols_x) = marker(:, cols_x) - ball(subj,1);  % subtract the first value of ball from the x coordinate
                marker(:, cols_y) = marker(:, cols_y) - ball(subj,2);  % subtract the second value of ball from the y coordinate
                marker(:, cols_z) = marker(:, cols_z) - ball(subj,3);  % subtract the third value of ball from the z coordinate
            else
                marker(:, cols_x) = marker(:, cols_x) - ball(subj,club*3-2);  % subtract the first value of ball from the x coordinate
                marker(:, cols_y) = marker(:, cols_y) - ball(subj,club*3-1);  % subtract the second value of ball from the y coordinate
                marker(:, cols_z) = marker(:, cols_z) - ball(subj,club*3);  % subtract the third value of ball from the z coordinate
            end

            % define wrist position as the midpoint of front and back
            mocap_lwrist = (marker(:,7:9)+marker(:,13:15))./2;

            % align axes with t5
            temp = apdm_data;
            apdm_data(:,1) = -temp(:,2);
            apdm_data(:,2) = temp(:,1);
            apdm_data(:,3) = temp(:,3);
            % gyro direction
            apdm_data(:,4) = -temp(:,5);
            apdm_data(:,5) = temp(:,4);
            apdm_data(:,6) = temp(:,6);
            
            % trialData = struct('apdm',apdm_data);
            % swingData_2508_cal(subj).clubN(club).trialN(trial) =trialData;
            apdm_data(:,1:6) = cal_data; %unfiltered calibrated data

            % magnet direction
            apdm_data(:,7) = -temp(:,8);
            apdm_data(:,8) = temp(:,7);
            apdm_data(:,9) = temp(:,9);

            % filtering after cal
            cut_freq = 15; %the smaller the number, the blunter it gets %10 and 15 are similar, still undecided
            [b, a] = butter(4, cut_freq/(200/2));
            apdm_data = filtfilt(b,a,apdm_data);


            % figure(trial)
            % plot(apdm_data(:,4:6))
            gyro_norm = vecnorm(apdm_data(:,4:6), 2, 2);   % 2-norm per row (√(x^2+y^2+z^2))

            %% calculate swing phase
            mocap_ch = marker(:,19:21);

            % figure(trial)
            % plot(mocap_ch)

            delta_t = 1/200;
            %Calculate the difference (derivative) for each XYZ component
            % diff_mocap_ch = diff(mocap_ch) / delta_t; % one sample fewer
            [dot1,ddot1] = deriv5(mocap_ch(1:end,1),delta_t);
            [dot2,ddot2] = deriv5(mocap_ch(1:end,2),delta_t);
            [dot3,ddot3] = deriv5(mocap_ch(1:end,3),delta_t);

            diff_mocap_ch = [dot1 dot2 dot3];
            % cut_freq = 15;
            % % filter data
            % [b, a] = butter(4, cut_freq/(200/2));
            % diff_mocap_ch = filtfilt(b, a, diff_mocap_ch);
            % t9_data = filtfilt(b,a,t9_data);
            chs = sqrt(sum(diff_mocap_ch.^2, 2));

            threshold = 100;
            min_distance = 100;
            time_data = 1:length(mocap_ch);

            % find local maxima
            [pks_max, locs_max] = findpeaks(chs, 'MinPeakHeight', threshold);  % find maxima

            % invert the data to find local minima
            [pks_min, locs_min] = findpeaks(-chs, 'MinPeakDistance', min_distance);  % find minima
            pks_min = -pks_min;  % convert local minima back to the original values

            % merge local maxima and local minima into one list
            pks = [pks_max; pks_min];  % combine local maxima and minima
            locs = [locs_max; locs_min];  % combine positions of local maxima and minima

            % sort by position
            [locs, sort_idx] = sort(locs);  % sort by locs_combined
            pks = pks(sort_idx);  % sort pks_combined to match the sorted order

            % 1. define impact (IMP) as the position of the maximum peak
            [~, imp_idx] = max(pks);
            imp_time = time_data(locs(imp_idx));

            % 2. define backswing (BST) as the position of the minimum before IMP
            bst_idx = find(locs < locs(imp_idx), 1, 'last');
            bst_time = time_data(locs(bst_idx));
            %% if the two are within 20 of each other, drop one; it catches a double peak
            if (imp_time-bst_time)<20
                bst_idx = bst_idx-1;
            end
            bst_time = time_data(locs(bst_idx));
            
            %% address method mine
            add_threshold=10;
            % find all indices below a given index whose value is below threshold_value
            add_indexes = find(chs(1:bst_time) <= add_threshold);
            add_time = add_indexes(end); %last of those values

            while apdm_data(add_time, 2) < -9.8
                % disp(apdm_data(add_time, 2))
                % check add_indexes one by one from the end
                add_indexes(end) = []; % remove the last index
                if isempty(add_indexes)
                    error('cannot find an index satisfying the condition.');
                end
                add_time = add_indexes(end); % set the new add_time
            end

            % 5. set finish (FIN) as the minimum after IMP
            fin_idx = find(locs(imp_idx)<locs, 1, 'first');
            fin_time = time_data(locs(fin_idx));
            % prevent catching a double peak; if the value exceeds 10000, add 1 to the index
            if chs(fin_time) > 10000
                fin_idx = fin_idx+1;
            end
            fin_time = time_data(locs(fin_idx));

            IMP = min_peak(apdm_data(:,5));
            % check the interval in which imp is detected from the markers
            if bst_time>IMP
                data = mocap_ch(bst_time:bst_time+200, 2);
            else 
                data = mocap_ch(bst_time:IMP+10, 2); 
            end

            % detect the change along the global y axis: find where it switches from - to +
            sign_change = diff(data > 0);  % find the point where the value changes from negative to positive
            pos_ind = find(sign_change == 1);  % find the index of the value that turned positive % minus 1 gives the point that is still negative
            % imp_marker = pos_ind(1)+bst_time;
            imp_marker = pos_ind+bst_time; % plotting it myself, this looks more correct


            %% ms heuristic compare %
            % saved as add_imu, bst_imu, imp_imu, fin_imu
            % isn't it enough if this can also be screened visually?
            bst_imu = zeroCross(apdm_data(:,6),-0.6,0); % zero-crossing
            if club==1 || club== 3
                if subj==1 || subj==7
                    add_imu = min_beforeMax_threshold(gyro_norm(1:bst_imu),500,10,1);
                elseif subj==4 && club==3
                    add_imu = min_beforeMax_threshold(gyro_norm(1:bst_imu),500,10,1);
                else
                    add_imu = min_beforeMax_threshold(gyro_norm(1:bst_imu),500,15,1);
                end
            else
                if subj==4 || subj==6
                    add_imu = min_beforeMax_threshold(gyro_norm(1:bst_imu),500,7,1);
                else
                    add_imu = min_beforeMax_threshold(gyro_norm(1:bst_imu),500,5,1); %subj3 iron was not caught, so 15->10->5
                end
                
            end
            imp_imu = min_peak(apdm_data(:,5));

            imp_imu2 = zeroCross(apdm_data(:,6),0.5,0);  % extract imp from the gyro z zero crossing
            if subj==2 && club==1 && trial==30
                imp_imu = imp_imu2;
            end
            if subj==4 && club==2
                if trial == 26
                    imp_imu2 = 3053;
                elseif trial == 17
                    imp_imu2 = 2773;
                elseif trial == 8
                    imp_imu2 = 2593;
                elseif trial == 2
                    imp_imu2 = 2540;
                elseif trial == 12
                    imp_imu2 = 2834;
                end
            elseif subj==4 && club==3 &&trial==6
                    imp_imu2 = 1593;
            elseif subj==5 && club==1 &&trial==23
                    imp_imu2 = 3374;
            end
            fin_imu = min_afterMax_threshold(gyro_norm, imp_imu, 70, 1); %number adjusted after filtering, 80 ms used



            %% phase exception code
            % when the imu & mocap heuristic fails to catch it

            if subj==1 && club==1 
                if trial==29
                    add_imu = 2730;
                elseif trial==21
                    fin_imu = 3121;
                end

            elseif subj==2 && club==2 
                if trial==2
                    add_imu = 2684;
                elseif trial==9
                    add_imu = 2975;
                elseif trial==24
                    add_imu = 2554;
                end
            elseif subj==2 && club==3 
                if trial==10
                    add_time = 885;
                elseif trial==1
                    add_time = 454;
                elseif trial==4
                    add_time = 760;
                elseif trial==2
                    add_time = 519;
                elseif trial==5
                    add_time = 673;
                elseif trial==3
                    add_time = 1027;
                end

            elseif subj==3 && club==2 && trial==16
                add_imu = 2470;
            elseif subj==3 && club==3 && (trial == 1 || trial == 2)
                if trial==1
                    add_time = 1619;
                elseif trial==2
                    add_time = 1186;
                elseif trial==4
                    add_time = 1508;
                elseif trial==5
                    add_time = 1523;
                end


            elseif subj==4 && club==2 
                if trial==9
                    add_imu = 2397;
                elseif trial==21
                    add_imu = 2676;
                elseif trial==7 || trial==13 || trial==17 || trial==26 || trial==29 || trial==10
                    add_imu = add_imu;
                elseif trial==3 || trial==4 || trial ==15
                    add_imu = add_imu-90;
                else
                    add_imu = add_imu-80;
                end
            elseif subj==4 && club==3
                if trial==7
                    add_time = 1239;
                    add_imu = 1171;
                elseif trial ==3
                    add_imu = 755;
                elseif trial ==5
                    add_imu = 1010;
                elseif trial ==9
                    add_imu = 2240;
                end


            elseif subj==5 && club==1 && trial==2
                add_time = 2244;
            elseif subj==5 && club==2 
                if trial==15
                    add_imu = 2565;
                elseif trial==3
                    add_imu = 1998;
                elseif trial==4
                    add_imu = 2383;
                elseif trial==6
                    add_imu = 2354;
                elseif trial==8
                    add_imu = 2284;
                elseif trial==11
                    add_imu = 2557;
                elseif trial==14
                    add_imu = 2632;
                elseif trial==21
                    add_imu = 2523;
                elseif trial==23
                    add_imu = 2193;
                elseif (trial==26 || trial==12)
                    add_imu = 2473;
                end
            elseif subj==5 && club==3
                if trial == 6
                    add_imu = 807;
                elseif trial==4
                    add_time = 935;
                end
            
            elseif subj==6 && club==1
                if trial==1
                    add_time = 2228;
                elseif trial==2
                    add_time = 2106;
                elseif trial==23
                    add_time = 2560;
                end
            elseif subj==6 && club==2
                if trial ==13 || trial==18
                    add_imu= add_imu;
                elseif trial ==1
                    add_imu = 2095;
                elseif trial ==4
                    add_imu = 2006;
                elseif trial ==25
                    add_imu = 2265;
                elseif trial ==22
                    add_imu = 2424;
                elseif trial==29
                    add_imu =2090;
                else
                    add_imu = add_imu+85;
                end
            elseif subj==6 && club==3
                if trial==6
                    add_time = 728;
                end

            elseif subj==7 && club==1
                add_imu = add_imu-100;
            elseif subj==7 && club==2 && trial==26
                add_imu = 3170;
            elseif subj==7 && club==3 && trial==1
                add_imu = 1212;

            elseif subj==8 && club==1
                if trial ==1
                    fin_time = 2335;
                elseif trial==12
                    add_imu = 1755;
                end
            elseif subj==8 && club==2 && trial==10
                add_imu = 1873;
            elseif subj==8 && club==3
                if trial==3
                    add_time = 980;
                elseif trial==8
                    add_time = 1119;
                    add_imu = 1101;
                end

            elseif subj==9 && club==1
                add_imu = add_imu-40;
                if trial==26
                    fin_time = 3010;
                end
            elseif subj==9 && club==2
                add_imu = add_imu-40;
                if trial==30 || trial==20
                    fin_time = 3216;
                elseif trial==5 || trial==14
                    fin_time = 3478;
                elseif trial==26 || trial ==10 || trial==7
                    fin_time = 3287;
                elseif trial==29 || trial==16
                    fin_time = 3111;
                end
            elseif subj==9 && club==3
                if trial==5
                    add_time  = 413;
                elseif trial==7
                    add_imu = 605;
                elseif trial==3
                    add_imu = 476;
                elseif trial==8
                    add_imu = 354;
                elseif trial==4
                    add_imu = 384;
                elseif trial==6
                    add_time = 639;
                elseif trial==2
                    add_imu = 491;
                end

            elseif subj==10&& club==2
                if trial==5
                    add_imu = 2981;
                elseif trial==30
                    add_imu = 2850;
                end

            end




            %% visualise the heuristic and mocap phases

            % % check swing phase
            % figure(trial)
            % plot(chs)
            % xline([ add_time bst_time imp_marker(1) fin_time],'-',{'ADD','BST','IMP','FIN'},'HandleVisibility','off');
            % xline([add_imu, bst_imu, imp_imu, fin_imu],'-',{'ADD IMU','BST IMU','IMP IMU','FIN IMU'},'Color','r','HandleVisibility','off');
            % xlim([add_time-100 fin_time+100])
            % hold on;
            
            % subj==10 club==3 trial==10 does not work
            % figure(trial+100)
            % hold on
            % % plot(gyro_norm)
            % % plot(apdm_data(:,5:6),LineWidth=1)
            % plot(apdm_data(:,6),LineWidth=1)
            % xline([imp_marker(1), imp_imu, imp_imu2],'-',{'imp marker','IMP IMU','IMP IMU2'},'Color','k','HandleVisibility','off');
            % yline(0);
            % xlim([imp_marker(1)-20 imp_marker(1)+50])
            
            % tileFigures();            % automatic grid
            % tileFigures(2,4);       % force 2 rows by 4 columns
            % tileFigures(2,4,2);   % automatic grid on monitor 2
            
            if subj==10 && club==3 && trial==10
                swing_phase = [add_time bst_time imp_time fin_time];
            else %1020 plotted at line 860 and matched imp %subtract 1 from imp_marker(1)
                % the length is matched all at once below
                % swing_phase = [add_time bst_time imp_marker(1)-1 fin_time]; 
                
                %1201 numerically it sits too far left of the address, so +1 again
                swing_phase = [add_time bst_time imp_marker(1) fin_time]; 
            end

            swing_phase_imu = [add_imu bst_imu imp_imu imp_imu2 fin_imu];

            %% interpolation
            % interpolation somehow worked until now.. fixed the code

            fs1 = 200; % 200 Hz sampling rate
            fs2 = 150;

            % data size
            data1_length = length(apdm_data);
            data2_length = length(pose_est);

            % create time vector
            t1 = (0:data1_length-1) / fs1; % time vector of the 200Hz data
            t2 = (0:data2_length-1) / fs2; % time vector of the 150Hz data

            % new time vector for interpolation (same as the 200Hz time vector)
            % t_new = t1;
            t_new = 0 : 1/fs1 : t2(end);
            pose_est_interp = interp1(t2, pose_est(:,1:12), t_new, 'linear', 'extrap');
            % 
            cut_freq = 10; %the smaller the number, the blunter it gets %10 and 15 are similar, still undecided
            [b, a] = butter(4, cut_freq/(200/2));
            pose_est_interp = filtfilt(b,a,pose_est_interp);

            % % to really do it manually
            % figure(10000+trial)
            % hold on;
            % plot(mocap_lwrist(:,2));
            % plot(pose_est_interp(:,2));

            % 1019 synchronisation
            %% 1) first-pass alignment of the start point using the z maximum (peak)

            % club 3 uses ymin
            % --- peak on the mocap side ---
            if subj == 2 && club==1 && trial==8
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
                [pks_vid, locs_vid] = findpeaks(-pose_est_interp(:,2), 'MinPeakHeight', threshold);
                [~, vid_idx] = max(pks_vid);
                vid_max = locs_vid(vid_idx);
            elseif subj ~= 1 && (club==1 ||club==2 )
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(mocap_lwrist(:,3),'MinPeakHeight',threshold);
                if isempty(pks_mark)
                    [~, mark_max] = max(mocap_lwrist(:,3));   % fallback
                else
                    [~, k]  = max(pks_mark);
                    mark_max = locs_mark(k);
                end
                % --- peak on the video (pose) side ---
                [pks_vid, locs_vid] = findpeaks(pose_est_interp(:,3),'MinPeakHeight',threshold);
                if isempty(pks_vid)
                    [~, vid_max] = max(pose_est_interp(:,3)); % fallback
                else
                    [~, k]  = max(pks_vid);
                    vid_max = locs_vid(k);
                end
            % really manual % confusing, so just matched the numbers, do not understand the principle
            elseif subj == 2 && club==3 && (trial == 2|| trial ==3)
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
                vid_max = 1000;
            elseif subj == 4 && club==3 && (trial == 1|| trial ==5 || trial==9)
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
                vid_max = 1500;
                if trial ==5
                    vid_max = 1400;
                elseif trial==9
                    vid_max = 2700;
                end
            elseif subj == 7 && club==3 && trial == 2
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
                vid_max = 1500;
            elseif subj == 10 && club==3 && trial == 8
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
                vid_max = 1900;

            else %if club==3 % trial where the participant jumped and did not raise the arm properly
                % synchronise using the y maximum
                threshold = 100;
                [pks_mark, locs_mark] = findpeaks(-mocap_lwrist(:,2), 'MinPeakHeight', threshold);  % find maxima
                [~, mark_idx] = max(pks_mark);
                mark_max = locs_mark(mark_idx);
                mark_start = mark_max-mark_max+1;
    
                [pks_vid, locs_vid] = findpeaks(-pose_est_interp(:,2), 'MinPeakHeight', threshold);
                [~, vid_idx] = max(pks_vid);
                vid_max = locs_vid(vid_idx);
                % the video recording is usually started first
            end

            
            % compute the start index (trim the front instead of padding)
            % e.g. when the difference is 8, start must be +1, since the original start was 1
            % when phase is referenced to the changed start, start is positive so always subtract it and add 1.
            % (that removes exactly delta, cancelling the 1 added when start was computed)
            % when referenced to delta, subtracting alone is enough
            mark_start = 1; vid_start = 1;
            if vid_max > mark_max
                vid_start  = vid_max - mark_max + 1;     % start pose later
            else
                mark_start = mark_max - vid_max + 1;     % start mocap/marker/APDM later
                disp('video is shorter (peak alignment stage)');
            end
            
            % actual trimming
            marker        = marker(mark_start:end, :);
            mocap_lwrist  = mocap_lwrist(mark_start:end, :);
            apdm_data     = apdm_data(mark_start:end, :);
            pose_est_interp = pose_est_interp(vid_start:end, :);
            
            % shift swing_phase to the mocap reference as well (keep 1-based)
            swing_phase = swing_phase - (mark_start - 1);
            swing_phase_imu = swing_phase_imu - (mark_start - 1);
            

            %% 2) fine correction using the z minimum (in the interval of interest, e.g. after impact)
            sp2 = max(1, swing_phase(2));                  % interval start
            % end of the common interval where both signals exist
            common_end = min([size(pose_est_interp,1), size(mocap_lwrist,1), ...
                              max(sp2, swing_phase(4))]);
            
            % minimal safeguard in case the interval end is smaller than the start
            if common_end <= sp2
                warning('common interval too short, skipping the min-based correction.');
                delta = 0;
            else
                % z-minimum position of pose / mocap respectively (relative)
                [~, pose_min_rel ] = min(pose_est_interp(sp2:common_end, 3));
                [~, mocap_min_rel] = min(mocap_lwrist (sp2:common_end, 3));

                % absolute index (referenced after trimming)
                pose_min_abs  = sp2 + pose_min_rel  - 1;
                mocap_min_abs = sp2 + mocap_min_rel - 1;
                
                % min detection does not work properly
                if subj==10 && club==2
                    if trial >19 && (trial ~= 23 || trial ~=28 || trial ~= 29)
                        pose_min_abs = pose_min_abs-10;
                    end
                end

                % +: the mocap event is later → start pose later (trim the front)
                % -: the mocap event is earlier → start vid later
                delta = mocap_min_abs - pose_min_abs;
            
                if delta > 0
                    marker        = marker(delta+1:end, :);
                    mocap_lwrist  = mocap_lwrist(delta+1:end, :);
                    apdm_data     = apdm_data(delta+1:end, :);
                    swing_phase = swing_phase-delta;
                    swing_phase_imu = swing_phase_imu-delta;

                elseif delta < 0
                    % leave mocap as is for now
                    delta = -delta;
                    pose_est_interp = pose_est_interp(delta+1:end,:);
                end
            end
            
            %% (optional) match the final lengths: skip if different lengths are allowed
            % common_len = min([size(marker,1), size(mocap_lwrist,1), size(pose_est_interp,1), size(apdm_data,1)]);
            % marker        = marker(1:common_len,:);
            % mocap_lwrist  = mocap_lwrist(1:common_len,:);
            % pose_est_interp = pose_est_interp(1:common_len,:);
            % apdm_data     = apdm_data(1:common_len,:);
            % swing_phase   = min(swing_phase, common_len);   % clamp to the boundary

            % figure(trial+200)
            % hold on;
            % plot(mocap_lwrist(:,3));
            % plot(pose_est_interp(:,3));



            % this also requires bst_time to be found first
            % to check the difference from the z min
            if swing_phase(4)> size(pose_est_interp,1) % the video ends too early
                [min_value, min_idx_relative] = min(pose_est_interp(swing_phase(2):size(pose_est_interp,1),3));
            else
                [min_value, min_idx_relative] = min(pose_est_interp(swing_phase(2):swing_phase(4),3));
            end

            % actual index in the full data
            min_idx_absolute = min_idx_relative + swing_phase(2) - 1;
            
            % min detection does not work properly %700 adjusted as well
            if subj==10 && club==2
                if trial >19 && (trial ~=28 || trial ~= 29)
                    min_idx_absolute = min_idx_absolute-10;
                end
            end

            swing_phase(5) = min_idx_absolute;

            
            % %% synchronisation verification plot
            % figure(trial+200)
            % hold on;
            % plot(mocap_lwrist(:,3),'LineWidth', 1.5);
            % plot(pose_est_interp(:,3),'LineWidth', 1.5);
            % xline(swing_phase,'-',{'ADD','BST','IMP','FIN','vid_imp'},'HandleVisibility','off');
            % 
            % figure(trial+300)
            % hold on;
            % plot(mocap_lwrist(:,3),'LineWidth', 1.5);
            % plot(pose_est_interp(:,3),'LineWidth', 1.5);
            % xline(swing_phase,'-',{'ADD','BST','IMP','FIN','vid_imp'},'HandleVisibility','off');
            % xlim([swing_phase(2) swing_phase(4)]);
            % 
            % tileFigures(3,3,2);   % automatic grid on monitor 2


            trialData = struct('add', swing_phase(1), ...
                'bst', swing_phase(2), ...
                'imp', swing_phase(3), ...
                'fin', swing_phase(4), ...
                'vid_min',swing_phase(5),...
                'marker', marker,...
                'apdm',apdm_data,'dl',pose_est_interp, ...
                'add_imu',swing_phase_imu(1),'bst_imu',swing_phase_imu(2),'imp_imu1',swing_phase_imu(3),...
                'imp_imu2',swing_phase_imu(4),'fin_imu',swing_phase_imu(5));

            swingData_2508_raw(subj).clubN(club).trialN(trial) =trialData;

            %process trialData along the time axis
            fps = 200;

            % Desired time window in seconds around old_imp
            time_before = 3.5; % seconds before old_imp
            time_after = 1;    % seconds after old_imp

            % Calculate corresponding number of samples
            % samples_before = time_before * fps; % 3.5 s * 200 fps = 700 samples
            % samples_after = time_after * fps;   % 1 s * 200 fps = 200 samples
            
            %1020 if old imp is 700, start_idx should become 1
            samples_before = time_before * fps-1; % 3.5 s * 200 fps = 700 samples
            samples_after = time_after * fps;   % 1 s * 200 fps = 200 samples

            old_imp = trialData.imp;
            % set the new imp value to 700
            new_imp = 700;

            % set the data interval (referenced to old_imp)
            start_idx = old_imp - samples_before;
            end_idx = old_imp + samples_after;


            trialData = struct('add', swing_phase(1), ...
                'bst', swing_phase(2), ...
                'imp', swing_phase(3), ...
                'fin', swing_phase(4), ...
                'vid_min',swing_phase(5),...
                'marker', marker,...
                'apdm',apdm_data,'dl',pose_est_interp, ...
                'add_imu',swing_phase_imu(1),'bst_imu',swing_phase_imu(2),'imp_imu1',swing_phase_imu(3),...
                'imp_imu2',swing_phase_imu(4),'fin_imu',swing_phase_imu(5));

            % extract only the data in the set interval for each data field
            % 1104 what is this code? ah, it seems to mean there is data after fin?
            fields = {'marker','apdm','dl'};
            for j = 1:length(fields)
                fieldName = fields{j};
                data = trialData.(fieldName);

                % check that the data is within the interval and extract it
                % if the video is short, pad with the last value--> this seems to be the only case where the video is shorter
                % ah, participant 9 seems to be caught here
                if start_idx > 0 && end_idx <= size(data, 1)
                    trialData.(fieldName) = data(start_idx:end_idx, :);
                elseif end_idx > size(data, 1)
                    additional_rows = end_idx - size(data, 1);
                    last_row = data(end, :);
                    padding = repmat(last_row, additional_rows, 1);
                    extended_data = [data; padding];
                    trialData.(fieldName) = extended_data(start_idx:end_idx, :);
                else
                    % zero padding at the front
                    temp = data;
                    pre = zeros(abs(start_idx)+1,size(data,2));
                    data= [pre; temp];
                    trialData.(fieldName) = data(1:900,:);
                    % old_imp = 700;
                    disp('Warning: Data index out of bounds.');
                end
            end

            % scale the other field values proportionally (add, bst, fin)
            bst_offset = old_imp - trialData.bst;
            add_offset = old_imp - trialData.add;
            fin_offset = trialData.fin - old_imp;

            %1020 final field adjustment
            % first check that the intervals match %they do
            trialData.imp = new_imp; 
            trialData.bst = new_imp - bst_offset;
            trialData.add = new_imp - add_offset;
            trialData.fin = new_imp + fin_offset;
            
            vid_offset = old_imp - trialData.vid_min;
            trialData.vid_min = new_imp - vid_offset; 
            imp_imp1_offset = old_imp - trialData.imp_imu1;
            trialData.imp_imu1 = new_imp - imp_imp1_offset; 
            imp_imp2_offset = old_imp - trialData.imp_imu2;
            trialData.imp_imu2 = new_imp - imp_imp2_offset; 

            % accordingly make the final adjustment to the imu-based phase too
            bst_imu_offset = old_imp - trialData.bst_imu;
            add_imu_offset = old_imp - trialData.add_imu;
            fin_imu_offset = trialData.fin_imu - old_imp;

            trialData.bst_imu = new_imp - bst_imu_offset;
            trialData.add_imu = new_imp - add_imu_offset;
            trialData.fin_imu = new_imp + fin_imu_offset;
            
            if subj==9&&club==3&& trial==8
                trialData.imp = new_imp; 
                swing_phase_imu = swing_phase_imu + abs(start_idx)+1;
                swing_phase = swing_phase + abs(start_idx)+1;
                trialData.bst = swing_phase(2);
                trialData.add = swing_phase(1);
                trialData.fin = swing_phase(4);
                trialData.vid_min = swing_phase(5); 

                trialData.bst_imu = swing_phase_imu(2);
                trialData.add_imu = swing_phase_imu(1);
                trialData.fin_imu = swing_phase_imu(5);
                trialData.imp_imu1 = swing_phase_imu(3); 
                trialData.imp_imu2 = swing_phase_imu(4); 
            end

            % % try plotting
            % % identify the imp instant % checked on the data cropped to 700 samples
            % Lhand = trialData.marker(trialData.bst:new_imp+1, 13:15); % coordinates of the first marker (columns 13~15)
            % clubhead = trialData.marker(trialData.bst:new_imp+1, 19:21); % coordinates of the second marker (columns 19~21) % from the plot, imp seems to be +1
            % 
            % % 3D plot setup
            % figure(trial*550);
            % hold on;
            % grid on;
            % xlabel('X');
            % ylabel('Y');
            % zlabel('Z');
            % title('3D Swing Trajectory');
            % % view(3); % 3D view setup
            % view([90 0]);
            % 
            % % plot the 3D swing trajectory over time
            % for t = 1:size(Lhand, 1)
            %     % % connect from the origin to the first marker
            %     % plot3([0, Lhand(t, 1)], [0, Lhand(t, 2)], [0, Lhand(t, 3)], 'r-', 'LineWidth', 1.5);
            %     % 
            %     % connect from the first marker to the second marker
            %     plot3([Lhand(t, 1), clubhead(t, 1)], ...
            %           [Lhand(t, 2), clubhead(t, 2)], ...
            %           [Lhand(t, 3), clubhead(t, 3)], 'b-', 'LineWidth', 1.5);
            % 
            %     plot3(0, 0, 0, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); % mark the origin (0,0,0) with a red dot
            % 
            %     % update the plot
            %     drawnow;
            % end



            %if it exceeds 900, just fix it at 900
            % subj=8, trial = 1 is odd
            if  trialData.fin >900
                trialData.fin = 900;
            end
            if  trialData.fin_imu >900
                trialData.fin_imu = 900;
            end
            swingData_2508(subj).clubN(club).trialN(trial) =trialData;


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



    %0430 for raw data processing
    raw_acc_ = h5read(h5_path, ['/Sensors/', id, '/Accelerometer'])';
    gyro_ = h5read(h5_path, ['/Sensors/', id, '/Gyroscope'])';
    %0703 magnetometer
    mag_ = h5read(h5_path, ['/Sensors/', id, '/Magnetometer'])';


    % %% 1019 filtering applied first to identify the instants
    % raw_acc_ = filtfilt(b, a, raw_acc_);
    % gyro_ = filtfilt(b, a, gyro_);
    % mag_ = filtfilt(b, a, mag_);

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

%% match the number of columns
function A = insert_zero_cols(A, start_col, num_cols)
    n = size(A, 1);
    A = [A(:, 1:start_col-1), zeros(n, num_cols), A(:, start_col:end)];
end


%% function for phase detection
% seems to be the imu heuristic code, check again later

function Ind = zeroCross(vector,range,cross)
max_val = max(vector);
vector_in_range=vector;
vector_in_range(vector_in_range < max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector_in_range);
if length(peak_ind)==0 peak_ind=200; end
max_ind = peak_ind(end);
if range<0 % -0.6 is passed when finding bst / find max and organise around it
    vector=vector(max_ind+range*200:max_ind);
    cross_ind = find(vector-cross<0,1,'last');
    Ind = cross_ind+max_ind+range*200-1;
elseif range>0
    vector=vector(max_ind:max_ind+range*200);
    cross_ind = find(vector-cross<0,1);
    % Ind = cross_ind+max_ind-1;
    Ind = cross_ind+max_ind-2; %just before the cross, not after
end
if length(Ind)==0 Ind=30; end
end


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

function Ind = min_beforeMax_threshold(vector,start, threshold,num)

bst_index = size(vector,1);
%check only the 2.5 s before bst, start : 500
vector = vector(bst_index-start:end);

threshold = deg2rad(threshold);
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
Ind = peak_ind(end-num+1)+bst_index-start;
end

function Ind = min_afterMax_threshold(vector,from,threshold,num)
temp = vector;
threshold = deg2rad(threshold);
vector=vector(from:end);
max_vec=max(vector(:));
vector = max_vec - vector;
vector(vector<max_vec-threshold)=0;    % threshold=20 deg/s // keep only values below the threshold, set larger ones to 0
[~, peak_ind] = findpeaks(vector);
% disp(peak_ind)
if length(peak_ind)==0 peak_ind=30; end
Ind = peak_ind(1)+from-1; % first minimum below the threshold
% figure(2000)
% plot(temp)
% xline(peak_ind+from-1)
end

% previously used code
% %% address method ms
% %% find the address instant % not sure how this was done
% % cjs and kdc tended not to be detected well
% add_time=find_address(chs ,bst_time);
function Ind = find_address(vector,backswingtop)
vector = vector(1:backswingtop-100);    % 0.5sec before backswingtop
max_val=max(vector(:));
vector = max_val - vector;
vector(vector<max_val-0.3)=0;
[~, peak_ind] = findpeaks(vector);
Ind = peak_ind(end);
end

function y = ifelse(c,a,b), if c, y=a; else, y=b; end, end

function tileFigures(rows, cols, monitor_index, margin_px, stagger, headroom_px)
% rows, cols      : grid size
% monitor_index   : index of the monitor to place on (default 1)
% margin_px       : tile spacing (default 30)
% stagger=[dx dy] : offset applied per page (default [0 0])
% headroom_px     : spare pixels subtracted from the tile height (default: 40 for QHD, 0 otherwise)
%
% if there are more figures than grid cells, they are placed overlapping in the same cell (modulo).
% window placement uses 'OuterPosition' so the size includes the title bar.

    if nargin < 4 || isempty(margin_px), margin_px = 10; end
    if nargin < 5 || isempty(stagger),   stagger   = [0 0]; end

    figs = findall(0,'Type','figure');
    if isempty(figs), return; end

    % so that they are placed from the top in creation order
    figs = flipud(figs);

    n       = numel(figs);
    gridN   = rows * cols;

    % monitor area
    mp = get(0,'MonitorPositions');                % [x y w h]
    monitor_index = min(monitor_index, size(mp,1));
    mon = mp(monitor_index,:);  X0=mon(1); Y0=mon(2); W=mon(3); H=mon(4);

    % auto-detect QHD, then set the default headroom
    if nargin < 6 || isempty(headroom_px)
        isQHD = (abs(W-2560)<=16 && abs(H-1440)<=16);  % tolerance included
        headroom_px = tern(isQHD, 10, 0);              % 40px of slack for QHD
    end

    % tile size (based on the whole window)
    tileW = (W - margin_px*(cols+1)) / cols;
    tileH = (H - margin_px*(rows+1)) / rows - headroom_px;
    tileH = max(tileH, 100);   % prevent it from becoming too small

    % placement
    for k = 1:n
        pageIdx = floor((k-1)/gridN);            % 0,1,2,… page number
        posIdx  = mod(k-1, gridN) + 1;           % position within 1..gridN

        r = rows - 1 - floor((posIdx-1)/cols);   % from the top
        c = mod((posIdx-1), cols);               % left→right

        x = X0 + margin_px + c*(tileW + margin_px) + pageIdx*stagger(1);
        y = Y0 + margin_px + r*(tileH + margin_px) + pageIdx*stagger(2);

        set(figs(k), 'Units','pixels', 'WindowStyle','normal', ...
            'OuterPosition', [x y tileW tileH], 'Visible','on');
        drawnow;                                  % the last placed window comes to the front
    end
end

function out = tern(cond,a,b)
    if cond, out = a; else, out = b; end
end
