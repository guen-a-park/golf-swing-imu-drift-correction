function qinf = get_orientation_quaternion(time, w, ind, qini)
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

%Convert to a quaternion   
q0 = qini;

%Initialize variables
qinf = zeros(length(time),4); qinf(1,:) = q0;

%Convert angular velocity to rad/s
w = w * pi/180; % without removing bias

%Define orientation throughout trial
for t=1:ind
    qinf(t,:) = q0;
end
for t=ind+1:length(time)
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
%     qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, (w(t,:)+w(t-1,:))/2]);
    qinf(t,:) = qt ./ norm(qt);
end
end