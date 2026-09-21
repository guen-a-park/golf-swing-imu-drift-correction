clc; clear all; close all;

swingData_2508_raw=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});
swingData_2508=struct('name',{"S01";"S02";"S03";"S04";"S05";"S06";"S07";"S08";"S09";"S10"});

subjN = ["S01","S02","S03","S04","S05","S06","S07","S08","S09","S10"];
clubN = ["driver","iron","vc"];

apdm_rate = 200;
cut_freq = 15;

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

for subj = 3 %some end frames have no data, so NaN may appear
    for club = [1 3]

        mocap_path = fullfile(dataRoot(), 'mocap');
        mocap_path = strjoin([mocap_path, "\", subjN(subj), "\",clubN(club)], '');
        mocap_files = dir(fullfile(mocap_path, '*.csv'));
        [~, idx] = sort({mocap_files.name});  % sort file names in ascending order
        mocap_files = mocap_files(idx);
        

        for trial = 1:30

            mocap_filePath = fullfile(mocap_path, mocap_files(trial).name);
            dataTable_mocap= readmatrix(mocap_filePath);

            if dataTable_mocap(2,1)==200
                start_index = dataTable_mocap(6,1);
                marker = dataTable_mocap(6:end,[3:20 24:26]);
            else
                start_index = dataTable_mocap(4,1);
                marker = dataTable_mocap(4:end,[3:20 24:26]);
            end

            cut_freq = 15; %the smaller the number, the blunter it gets
            [b, a] = butter(4, cut_freq/(200/2));
            marker = filtfilt(b,a,marker);
    
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

            mocap_lwrist = (marker(:,7:9)+marker(:,13:15))./2;

%% calculate swing phase
            mocap_ch = marker(:,19:21);
            delta_t = 1/200;
            [dot1,ddot1] = deriv5(mocap_ch(1:end,1),delta_t);
            [dot2,ddot2] = deriv5(mocap_ch(1:end,2),delta_t);
            [dot3,ddot3] = deriv5(mocap_ch(1:end,3),delta_t);

            diff_mocap_ch = [dot1 dot2 dot3];
            chs = sqrt(sum(diff_mocap_ch.^2, 2));

            threshold = 100;
            min_distance = 100;
            time_data = 1:length(mocap_ch);

            [pks_max, locs_max] = findpeaks(chs, 'MinPeakHeight', threshold);  % find maxima

            [pks_min, locs_min] = findpeaks(-chs, 'MinPeakDistance', min_distance);  % find minima
            pks_min = -pks_min;  % convert local minima back to the original values

            pks = [pks_max; pks_min];  % combine local maxima and local minima
            locs = [locs_max; locs_min];  % combine the positions of local maxima and local minima

            [locs, sort_idx] = sort(locs);  % sort by locs_combined
            pks = pks(sort_idx);  % sort pks_combined to match the sorted order

            [~, imp_idx] = max(pks);
            imp_time = time_data(locs(imp_idx));

            bst_idx = find(locs < locs(imp_idx), 1, 'last');
            bst_time = time_data(locs(bst_idx));
%% if the gap between the two is within 20, drop one; it catches a double peak
            if (imp_time-bst_time)<20
                bst_idx = bst_idx-1;
            end
            bst_time = time_data(locs(bst_idx));

            
            
%% address method mine
            add_threshold=10;
            add_indexes = find(chs(1:bst_time) <= add_threshold);
            add_time = add_indexes(end);

    
            fin_idx = find(locs(imp_idx)<locs, 1, 'first');
            fin_time = time_data(locs(fin_idx));
            if chs(fin_time) > 10000
                fin_idx = fin_idx+1;
            end
            fin_time = time_data(locs(fin_idx));

            figure(10000)
            hold on;
            
            if club==1
                plot(mocap_lwrist(imp_time-350:imp_time+100,:),'k')
            else
                plot(mocap_lwrist(imp_time-350:imp_time+100,:),'m')
            end

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
            continue
        else
            rethrow(ME)
        end
    end
    name = name(isletter(name));
    name = lower(name);

    raw_acc_ = h5read(h5_path, ['/Sensors/', id, '/Accelerometer'])';
    gyro_ = h5read(h5_path, ['/Sensors/', id, '/Gyroscope'])';
    mag_ = h5read(h5_path, ['/Sensors/', id, '/Magnetometer'])';

    quat_ = h5read(h5_path, ['/Processed/', id, '/Orientation'])';

    q.(name).rawacc = struct('x', raw_acc_(:, 1), 'y', raw_acc_(:, 2), 'z', raw_acc_(:, 3));
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

function Ind = max_peak(vector)
max_val = max(vector);
vector(vector< max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector);
Ind = peak_ind(end);
end

function Ind = min_peak(vector)
vector = mean(vector)-vector;
max_val = max(vector);
vector(vector< max_val*0.99) = 0;
[~, peak_ind] = findpeaks(vector);
if length(peak_ind)==0 peak_ind=50; end
Ind = peak_ind(end);
end

function Ind = min_peak_beforeMax(vector,range,num)
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