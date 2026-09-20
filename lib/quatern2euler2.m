function euler = quatern2euler2(q)  %custom
euler=zeros(length(q),3);
for i=1:length(q)
    dcm=quatern2dcm(q(i,:));
    euler(i,1)=atan2(-dcm(2,3),dcm(3,3));   % alpha
    euler(i,2)=atan2(-dcm(1,3),dcm(3,3));   % beta
    euler(i,3)=atan2(dcm(1,3),dcm(2,3));   % gamma
end
euler=unwrap(euler);
end
