% Orthogonalization procedure
% from Direction Cosine Matrix IMU: Theory by William Premerlani and Paul Bizard equations 19-21.

function R_ort=orthogonalization(R)
    x=R(:,1); y=R(:,2); z=R(:,3);
    error=dot(x,y);
    
    x_ort=x-(error/2)*y;
    y_ort=y-(error/2)*x;
    z_ort=cross(x_ort, y_ort);
    
    x_new = 1/2*(3-dot(x_ort,x_ort))*x_ort;
    y_new = 1/2*(3-dot(y_ort,y_ort))*y_ort;
    z_new = 1/2*(3-dot(z_ort,z_ort))*z_ort;
    
    R_ort = [x_new y_new z_new];
end