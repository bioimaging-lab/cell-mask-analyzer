I = imread('../data/testMask_SegmentationIssues.tif');

I2 = imread('../data/Handcorrected.tif');
I2 = I2 > 0;

It = circshift(I, [0, -8]);

% imshowpair(It, bwperim(I2))
% imwrite(It, '../data/testMask_SegmentationIssues2.tif', 'Compression', 'none')

%Relabel the mask so each cell has a unique identifier
cpLabels = zeros(size(It));
cpData = regionprops(It, 'Area', 'PixelIdxList');
cpData([cpData.Area] == 0) = [];

maskCtr = 0;

for ii = 1:numel(cpData)

    %Make a mask of the labels
    currMask = false(size(It));
    currMask(cpData(ii).PixelIdxList) = true;

    cellData = regionprops(currMask, 'PixelIdxList');

    for iCell = 1:numel(cellData)

        maskCtr = maskCtr + 1;
        cpLabels(cellData(iCell).PixelIdxList) = maskCtr;

    end    

end

imwrite(cpLabels, '../data/testMask_SegmentationIssues2.tif', 'Compression', 'none')
