 function [normalized1, normalized2, normalized3] = normalize_var_3(array1, array2, array3)

     % Normalize to [0, 1]:
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
     
