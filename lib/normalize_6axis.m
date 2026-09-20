 function [normalized_input] = normalize_6axis(input)

     % Normalize to [0, 1]:
     input_a1=[]; input_a2=[]; input_a3=[];
     input_g1=[]; input_g2=[]; input_g3=[];

     for i = 1:length(input)
         input_a1 = [input_a1 input{i}(:,1)];
         input_a2 = [input_a2 input{i}(:,2)];
         input_a3 = [input_a3 input{i}(:,3)];
         input_g1 = [input_g1 input{i}(:,1)];
         input_g2 = [input_g2 input{i}(:,2)];
         input_g3 = [input_g3 input{i}(:,3)];
     end
     
     range_a1 = max(input_a1) - min(input_a1);
     
     m1 = min(array1);
     range1 = max(array1) - m1;
     m2 = min(array2);
     range2 = max(array2) - m2;
     m3 = min(array3);
     range3 = max(array3) - m3;
     
     maxRange=max([range1,range2,range3]);
     
     normalized1 = (array1 - m1) / maxRange;
     normalized2 = (array2 - m2) / maxRange;
     normalized3 = (array3 - m3) / maxRange;
     
