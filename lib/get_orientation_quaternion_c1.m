function qinf = get_orientation_quaternion_c1(time, add, fin, w, qini, qfin)
%Function to determine orientation of IMU.

%Inputs:
%1. time - time (s, nx1) 
%2. w - angular velocity (deg/s, nx3) 
%3. ind - index array specifying the samples where the device is at rest 
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
for t=1:add
    qinf(t,:) = q0;
end

%Initial integration
for t=add+1:length(time)
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
    qinf(t,:) = qt ./ norm(qt);
end

%Calculate correction factors
% B = 2/(time(fin)-time(fin-1)) * (qfin - qini);
% A = 2/(time(fin)-time(fin-1)) * (qinf(fin,:)-qini);
B = qfin;
A = qinf(fin,:);
C = quaternProd(quaternConj(A),B);
ang = 2*acos(C(1));
axs = [C(2)/sqrt(1-C(1)^2), C(3)/sqrt(1-C(1)^2), C(4)/sqrt(1-C(1)^2)];

%Quaternion correction
deg=5;
for t=add+1:length(time)
    qang = ang * (t-add)^deg/(fin-add)^deg;  % angle difference distributed equally, ^3, ^4
    qc = [cos(qang/2), axs(1)*sin(qang/2), axs(2)*sin(qang/2), axs(3)*sin(qang/2)];
    qt = quaternProd(qinf(t,:),qc); 
    qinf(t,:) = qt ./ norm(qt);
end

end