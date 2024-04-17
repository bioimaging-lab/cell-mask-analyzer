clearvars
clc

refImagePath = 'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\20230428_Mask_ground_truth.tif';
testImagePath = 'D:\Documents\OneDrive - UCB-O365\Storage\CyposeMasks\7002\masks_cyto2_predicted.tif';

%%

MA = MaskAnalyzer;

quantifyErrors(MA, testImagePath, refImagePath)