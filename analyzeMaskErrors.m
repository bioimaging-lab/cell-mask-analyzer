clearvars
clc

Igt = imread('Handcorrected.tif') > 1;
Icp3 = imread('testMask_SegmentationIssues.tif');

%% Pre-process the Cellpose masks

%Register the two images
Icp3_binary = Icp3 > 0;

pxshift = xcorrreg(Igt, Icp3);
Icp3 = circshift(Icp3, pxshift);

%Relabel the mask so each cell has a unique identifier
cpLabels = zeros(size(Icp3));
cpData = regionprops(Icp3, 'Area', 'PixelIdxList');
cpData([cpData.Area] == 0) = [];

maskCtr = 0;

for ii = 1:numel(cpData)

    %Make a mask of the labels
    currMask = false(size(Icp3));
    currMask(cpData(ii).PixelIdxList) = true;

    cellData = regionprops(currMask, 'PixelIdxList');

    for iCell = 1:numel(cellData)

        maskCtr = maskCtr + 1;
        cpLabels(cellData(iCell).PixelIdxList) = maskCtr;

    end    

end

imshow(label2rgb(cpLabels))

%% Initialize storage struct

problemCells = struct;

%% Find over- and under-segmented cells
% A cell is over-segmented if there is more than 1 unique label

celldata = regionprops(Igt, 'PixelIdxList', 'BoundingBox');

for iCell = 1:numel(celldata)

    currCellMask = Icp3(celldata(iCell).PixelIdxList);
    
    %Define oversegmentation if cell has more than one number within
    %(excluding zeros)
    uniqueNums = unique(currCellMask);
    uniqueNums(uniqueNums == 0) = [];

    if numel(uniqueNums) > 1

        %Check if the area covered is greater than 10% - we'll call this a
        %problem
        tmpOS = 0;
        for ii = 1:numel(uniqueNums)

            if nnz(uniqueNums(ii) == currCellMask) > (0.2 * numel(currCellMask))
                tmpOS = tmpOS + 1;
            end            
        end

        if tmpOS > 1
            newIdx = numel(problemCells) + 1;
            problemCells(newIdx).BB = celldata(iCell).BoundingBox;
            problemCells(newIdx).Type = 'Oversegmented';
        end
    end        
end

%% For undersegmented cells - maybe do the same but the opposite (there's probably a better way to do this)

celldata = regionprops(cpLabels, 'PixelIdxList', 'BoundingBox');

for iCell = 1:numel(celldata)

    currCellMask = false(size(cpLabels));
    currCellMask(celldata(iCell).PixelIdxList) = true;
    
    combinedMasks = Igt & currCellMask;
    % figure(99)
    % imshow(combinedMasks)
    % pause
   
    %Define undersegmentation if there are really two objects in the ground
    %truth dataset
    gtCellData = regionprops(combinedMasks, 'Area');

    %Remove any small regions to account for expected discrepency between
    %predicted and ground truth masks
    gtCellData([gtCellData.Area] < 10) = [];

    if numel(gtCellData) >= 2
        newIdx = numel(problemCells) + 1;
        problemCells(newIdx).BB = celldata(iCell).BoundingBox;
        problemCells(newIdx).Type = 'Undersegmented';
    end
end

%% Find objects which are MISSING

Icp3Mask = Icp3 > 0;

missingCells = Igt & ~Icp3Mask;

%Clear any lines
missingCells = imopen(missingCells, strel('disk', 5));

missingCellData = regionprops(missingCells, 'BoundingBox');

for iAC = 1:numel(missingCellData)
    newIdx = numel(problemCells) + 1;
    problemCells(newIdx).BB = missingCellData(iAC).BoundingBox;
    problemCells(newIdx).Type = 'Missing';
end

%% Find objects which are ADDED

%Invert the ground-truth mask
IgtInv = ~Igt;
Icp3Mask = Icp3 > 0;

additionalCells = IgtInv & Icp3Mask;

%Clear any lines
additionalCells = imopen(additionalCells, strel('disk', 5));
%imshow(additionalCells)

addCellsData = regionprops(additionalCells, 'BoundingBox');

for iAC = 1:numel(addCellsData)
    newIdx = numel(problemCells) + 1;
    problemCells(newIdx).BB = addCellsData(iAC).BoundingBox;
    problemCells(newIdx).Type = 'Added';
end

%%
figure(1);
imshow(Icp3)
for ii = 2:numel(problemCells)
    
    switch problemCells(ii).Type
        case 'Oversegmented'
            boxColor = 'r';

        case 'Added'
            boxColor = 'g';

        case 'Missing'
            boxColor = 'y';

        case 'Undersegmented'
            boxColor = 'm';

    end

    rectangle('Position',problemCells(ii).BB, 'EdgeColor', boxColor)

end

figure(2);
imshowpair(Icp3, bwperim(Igt))