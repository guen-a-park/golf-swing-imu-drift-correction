function qinf = get_orientation_quaternion_f2(time, ini, imp, fin, w, qini, qimp, qfin, coef)
%Function to reconstruct orientation of IMU using forward & backward integration

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
qinf = zeros(fin-ini+1,4); qinf(1,:) = q0;

%Convert angular velocity to rad/s
w = w * pi/180; % without removing bias

%Initial integration
for t=ini+1:fin
    dt = time(t) - time(t-1);
    qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
    qinf(t,:) = qt ./ norm(qt);
end

%Backward integration
qinfb=qinf;
qinfb(fin,:)=qfin;
for i=1:fin-ini
    t=fin-i;
    dt = time(t+1) - time(t);
    qt = qinfb(t+1,:) + 0.5*dt*quaternProd(qinfb(t+1,:),[0, -w(t,:)]);
    qinfb(t,:) = qt ./ norm(qt);
end 

%Reconstruction round 1
qinf(fin,:)=qfin;
for t=ini+1:fin-1
    qt = avg_quaternion_scale(qinf(t,:),qinfb(t,:),coef*(fin-t),t-ini);    % linear coef:1
    qinf(t,:) = qt ./ norm(qt);
    if qinf(t,:)<0
    qinf(t,:)=-qinf(t,:);
    end
end

%integration from IMP
qinfi=qinf;
qinfi(imp,:)=qimp;
for t=imp+1:fin
    dt = time(t) - time(t-1);
    qt = qinfi(t-1,:) + 0.5*dt*quaternProd(qinfi(t-1,:),[0, w(t,:)]);
    qinfi(t,:) = qt ./ norm(qt);
end
for i=1:imp-ini
    t=imp-i;
    dt = time(t+1) - time(t);
    qt = qinfi(t+1,:) + 0.5*dt*quaternProd(qinfi(t+1,:),[0, -w(t,:)]);
    qinfi(t,:) = qt ./ norm(qt);
end 

%Reconstruction round 2
qinf(imp,:)=qimp;
for t=ini+1:imp-1
    qt = avg_quaternion_scale(qinf(t,:),qinfi(t,:),2*(fin-t),t-ini);    % 2:1
    qinf(t,:) = qt ./ norm(qt);
    if qinf(t,:)<0
    qinf(t,:)=-qinf(t,:);
    end
end
for t=imp+1:fin-1
    qt = avg_quaternion_scale(qinfi(t,:),qinf(t,:),1*(fin-t),t-ini);    % 1:1
    qinf(t,:) = qt ./ norm(qt);
    if qinf(t,:)<0
    qinf(t,:)=-qinf(t,:);
    end
end

% qinf=qinfi;


end