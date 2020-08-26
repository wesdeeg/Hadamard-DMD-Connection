% removes all prior variables and functions, clean slate
clear
close all
% starts a stopwatch
tic

% loading a mask pattern, .mat file type (binary data container)
load('testmask9.mat');
Msk = mask;
d = DMD('debug', 1);
% d = DMD(1);
% d.reset;
d.setMode(3);
d.patternControl(0);
I = zeros(size(Msk{1,1}));
% l is the pattern index, idx
l = 0;
% % impatternidx is the image pattern index
impatternidx = 0;
var = 1;
% Below gets a set of 24 images, identifies their place in the pattern
% and then sets them in the lookup table as they are defined.
for i = 1:8
    for j = 1:3
       I = I+ 2^(l)*Msk{i,j};
       l = l+1;
       impatternidx = var*8;
       var = var + 1;
    end
end
BMP = prepBMP(I);
for i = 1:8
    for j = 4:6
        I = I + 2^(l)*Msk{i, j};
        l = l + 1;
        impatternidx = var*8;
        var = var + 1;
    end
end
BMP = vertcat(BMP, prepBMP(I));
% for i = 1:8
%     for j = 7:8
%         I = I + 2^(l)*Msk{i, j};
%         l = l + 1;
%         impatternidx = var*8;
%         var = var + 1;
%     end
% end
% BMP = vertcat(BMP, prepBMP(I));

% Loading in premade BMP file
% temp = regexp(fileread('testbmp5.txt'), '\r?\n', 'split');
% BMP = vertcat(temp{:});

d.configureLUT(48);
d.initPatternLoad(0,size(BMP,1));
d.numOfImages(48,0);
d.uploadPattern(BMP);
d.numOfImages(48,0);
d.patternControl(2);

toc
% Original script for uploaded 24 patterns
% for i = 1:4
%     for j = 1:4
%        I = I+ 2^(l)*Msk{i,j};
%        d.definePattern(l, impatternidx);
%         l = l+1;
%         impatternidx = var*8;
%         var = var + 1;
%     end
% end
% for i = 5:8
%     for j = 5:6
%        I = I+ 2^(l)*Msk{i,j};
%        d.definePattern(l, impatternidx);
%         l = l+1;
%         impatternidx = var*8;
%         var = var+1;
%     end
% end
