function qinf = get_orientation_quaternion_backward(time, w, ind, qfin)
%Function to determine orientation of IMU.

%Inputs:
%1. time - time (s, nx1)
%2. a - acceleration (g, nx3)
%3. w - angular velocity (deg/s, nx3)
%4. ind - index array specifying the samples where the device is at rest
%         at the beginning of the trial (binary, nx1)
%
%Outputs:
%1. qinf - quaternion describing IMU orientation (nx4)

%Initialize variables
qinf = zeros(length(time),4); qinf(end,:) = qfin;

%Convert angular velocity to rad/s
w = w * pi/180; % without removing bias

%Define orientation ind~end
for t=ind:length(time)
    qinf(t,:) = qfin;
end

%Define orientation through backward integration
for i=1:ind-1
    t=ind-i;
    dt = time(t+1) - time(t);
    qt = qinf(t+1,:) + 0.5*dt*quaternProd(qinf(t+1,:),[0, -w(t,:)]);
    qinf(t,:) = qt ./ norm(qt);
end

end