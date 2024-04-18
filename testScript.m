clearvars
clc

% refImagePath = 'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\20230428_Mask_ground_truth.tif';
% testImagePath = 'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cyto2_predicted.tif';

refImagePath = 'D:\Work\Research\cell-mask-analyzer\data\Handcorrected.tif';
testImagePath = 'D:\Work\Research\cell-mask-analyzer\data\testMask_SegmentationIssues2.tif';

%%

MA = MaskAnalyzer;

quantifyErrors(MA, testImagePath, refImagePath)