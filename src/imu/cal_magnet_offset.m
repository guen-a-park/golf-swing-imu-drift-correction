clc; clear all; close all;

apdm_path = fullfile(dataRoot(), 'pilot', '260109pilot', '20260109_imu_pilot');
apdm_files = dir(fullfile(apdm_path, '*.h5'));
[~, idx] = sort([apdm_files.datenum]);
apdm_files = apdm_files(idx);

cut_freq = 15;
apdm_rate = 200;

mean_list = [];
trial_offset_mean = [];

for trial=[8 9 10 12 13]
    apdm_filePath = fullfile(apdm_path, apdm_files(trial).name);

    [q_apdm, init_time] = load_APDM(apdm_filePath, apdm_rate, cut_freq);
    apdm_data = [q_apdm.golf.rawacc.x, q_apdm.golf.rawacc.y, q_apdm.golf.rawacc.z q_apdm.golf.gyro.x, ...
    q_apdm.golf.gyro.y, q_apdm.golf.gyro.z, q_apdm.golf.magnet.x, q_apdm.golf.magnet.y, q_apdm.golf.magnet.z];
    

    offset_mean = [];
    for i = 1001:2000
        offset = rad2deg(atan2(apdm_data(i,8),apdm_data(i,7)));
        offset_mean = [offset_mean offset];
    end
    trial_offset_mean = [trial_offset_mean mean(offset_mean)];

    trial_mean = mean(apdm_data(1001:2000,7:9));
    mean_list = [mean_list;trial_mean];
end

mean(mean_list)
std(mean_list)

mean(trial_offset_mean)
std(trial_offset_mean)

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