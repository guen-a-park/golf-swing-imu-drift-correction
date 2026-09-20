%% sample rate sr1 to sr2

function qinf = get_orientation_quaternion_samplerate(time, a, w, ind, qini, sr1, sr2)

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
    dt = (time(t) - time(t-1))*sr1/sr2;
    if mod(t,sr2/sr1)==0
        qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, w(t,:)]);
    else
        qt = qinf(t-1,:);
    end
    
%     qt = qinf(t-1,:) + 0.5*dt*quaternProd(qinf(t-1,:),[0, (w(t,:)+w(t-1,:))/2]);
    qinf(t,:) = qt ./ norm(qt);
end
end