function [te, ae, ge]=extendADDFIN(acc, gyro, extendL, totL)

dataL=length(acc(:,1));
for i=1:extendL
    a(i,:)=acc(1,:);
%     g(i,:)=gyro(1,:);
    g(i,:)=zeros(1,3);
end
for i=extendL+1:dataL+extendL
    a(i,:)=acc(i-extendL,:);
    g(i,:)=gyro(i-extendL,:);
end
for i=dataL+extendL+1:dataL+2*extendL
    a(i,:)=acc(end,:);
%     g(i,:)=gyro(end,:);
    g(i,:)=zeros(1,3);
end

t=linspace(0,1,dataL+2*extendL)';
te=linspace(0,1,totL)';
ae(:,1)=interpn(t,a(:,1),te);
ae(:,2)=interpn(t,a(:,2),te);
ae(:,3)=interpn(t,a(:,3),te);
ge(:,1)=interpn(t,g(:,1),te);
ge(:,2)=interpn(t,g(:,2),te);
ge(:,3)=interpn(t,g(:,3),te);

end