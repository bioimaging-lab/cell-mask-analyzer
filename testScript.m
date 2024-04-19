clearvars
clc

refImagePath = 'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\20230428_Mask_ground_truth.tif';
testImagePath = {'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cyto2_predicted.tif', ...
    'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cypose_predicted.tif'};

% refImagePath = 'D:\Work\Research\cell-mask-analyzer\data\Handcorrected.tif';
% testImagePath = 'D:\Work\Research\cell-mask-analyzer\data\testMask_SegmentationIssues2.tif';

%%

MA = MaskAnalyzer;

quantifyErrors(MA, testImagePath, refImagePath)
% 
% clearvars
% clc
% 
cypose = load('D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cypose_predicted_stats.mat');
cyto2 = load('D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cyto2_predicted_stats.mat');

for ii = 1:numel(cyto2.storeStats)
    data(ii) = cyto2.storeStats{ii}.NumOversegmented + cyto2.storeStats{ii}.NumUndersegmented + ...
        cyto2.storeStats{ii}.NumMissing + cyto2.storeStats{ii}.NumAdditional;
end

plot(data)