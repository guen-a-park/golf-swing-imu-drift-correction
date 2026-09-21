function C = R2_participant_colors(n)

RGB = [ 140  13  13;    %  1
        153  26  51;    %  2
        179  51   0;    %  3
        191  89  38;    %  4
        204  26  26;    %  5
        217  38  77;    %  6
        242  64  26;    %  7
        230 115  26;    %  8
        242 140  51;    %  9
        242 179 102 ];  % 10
C = RGB / 255;

if nargin > 0
    assert(n <= size(C, 1), ...
        'R2_participant_colors: table holds %d colours, %d requested', size(C, 1), n);
    C = C(1:n, :);
end
end
