classdef MaskAnalyzer
    %MASKANALYZER  Quantify errors in cell image masks


    %  Originally created by Dr. Jian Wei Tay (jian.tay@colorado.edu)

    properties


    end

    methods

        function quantifyErrors(obj, testImagePath, refImagePath, varargin)
            %QUANTIFYERRORS  Quantifies errors between test and reference images
            %
            %  QUANTIFYERRORS(OBJ, TEST, REF) will quantify errors between
            %  a test image and a reference (or ground truth) image. TEST
            %  and REF should be the path to the corresponding images. The
            %  test and reference images can be single or an image stack.
            %
            %  Currently, the function is able to recognize the following
            %  issues: over-segmentation, under-segmentation, missing
            %  objects (objects in REF but not in TEST), and additional
            %  objects (objects in TEST but not in REF). There is a
            %  built-in tolerance to allow for minor inconsistencies.

            %Parse inputs
            if ~iscell(testImagePath)
                testImagePath = {testImagePath};
            end

            if ~iscell(refImagePath)
                refImagePath = {refImagePath};
            end

            if numel(refImagePath) == 1 && numel(testImagePath) > 1
                [refImagePath{1:numel(testImagePath)}] = deal(refImagePath{1});
            end

            ip = inputParser;
            addOptional(ip, 'registerImages', false);
            addOptional(ip, 'frameRange', Inf);
            parse(ip, varargin{:});

            for iFile = 1:numel(testImagePath)

                if isinf(ip.Results.frameRange)
                    frameRange = 1:numel(imfinfo(refImagePath{iFile}));
                else
                    frameRange = ip.Results.frameRange;
                end

                %Begin processing
                storeError = cell(numel(frameRange), 1);
                storeStats = cell(numel(frameRange), 1);

                ctr = 0;

                for iT = frameRange

                    %Read in and validate images
                    refImage = imread(refImagePath{iFile}, iT);
                    testImage = imread(testImagePath{iFile}, iT);

                    %Convert the test image into labels
                    refImage = obj.relabelMask(refImage);
                    testImage = obj.relabelMask(testImage);

                    %Register test image to reference image
                    if ip.Results.registerImages

                        pxshift = obj.xcorrreg(refImage > 0, testImage > 0);
                        testImage = circshift(testImage, pxshift);

                    end

                    [err, stats] = obj.findSegmentationErrors(testImage, refImage);

                    %Store error and stats
                    ctr = ctr + 1;
                    storeError{ctr} = err;
                    storeStats{ctr} = stats;

                    %Generate output images
                    [fPath, fName] = fileparts(testImagePath{iFile});

                    Iout = uint8((testImage > 0) * 255);

                    %Visualize the errors
                    for iErr = 1:numel(err)

                        switch lower(err(iErr).Type)

                            case 'oversegmented'
                                color = 'magenta';

                            case 'undersegmented'
                                color = 'blue';

                            case 'missing'
                                color = 'red';

                            case 'additional'
                                color = 'green';

                        end

                        %Draw a bounding box
                        Iout = insertShape(Iout, 'rectangle', ...
                            [err(iErr).BoundingBox(1), err(iErr).BoundingBox(2),...
                            err(iErr).BoundingBox(3) - err(iErr).BoundingBox(1) + 1,...
                            err(iErr).BoundingBox(4) - err(iErr).BoundingBox(2) + 1], ...
                            'ShapeColor', color);

                    end

                    Imerge = imfuse(testImage, bwperim(refImage));

                    if iT == frameRange(1)
                        imwrite(Iout, fullfile(fPath, [fName, '_errs.tif']))
                        imwrite(Imerge, fullfile(fPath, [fName, '_merged.tif']))
                    else
                        imwrite(Iout, fullfile(fPath, [fName, '_errs.tif']), 'writeMode', 'append')
                        imwrite(Imerge, fullfile(fPath, [fName, '_merged.tif']), 'writeMode', 'append')
                    end

                end

                save(fullfile(fPath, [fName, '_stats.mat']), 'storeStats', 'storeError')
            end
        end

    end

    methods (Static)

        function labels = relabelMask(Iin)
            %RELABELMASK  Relabels a mask or label image with unique IDs
            %
            %  L = RELABELMASK(MASK) will return a labelled image, where
            %  each unique object in MASK is labeled with an ID. MASK can
            %  be either a binary mask or a different labelled image, in
            %  which case RELABELMASK can be used to remove unused labels.
            %  The background pixels will be labelled with a 0.

            %Check if input consists only of two numbers
            if ~islogical(Iin) && numel(unique(Iin)) == 2

                %Convert to logical array
                Iin = Iin > min(unique(Iin));

            end

            if islogical(Iin)

                labels = bwlabel(Iin);

            else

                %Initialize the output label matrix
                labels = zeros(size(Iin));

                %Get data from each object
                tmpData = regionprops(Iin, 'Area', 'PixelIdxList');

                %(Mainly for input labels) Remove objects with no areas
                tmpData([tmpData.Area] == 0) = [];

                %Label the objects
                currID = 0;

                for iObj = 1:numel(tmpData)

                    currID = currID + 1;
                    labels(tmpData(iObj).PixelIdxList) = currID;

                end
            end

            % imshow(label2rgb(labels))

        end

        function BB = getBoundingBox(imageIn, label)
            %GETBOUNDINGBOX  Return coordinate of bounding box
            %
            %  B = GETBOUNDINGBOX(I, L) returns the row and column indices
            %  of the smallest box that will contain the specified object
            %  label L in the labeled image I. B = [left top right botom].

            %Get the row indices
            M = imageIn == label;

            anyRow = any(M, 2);
            rowTop = find(anyRow, 1, 'first');
            rowBottom = find(anyRow, 1, 'last');

            anyCol = any(M, 1);
            colLeft = find(anyCol, 1, 'first');
            colRight = find(anyCol, 1, 'last');

            BB = [colLeft, rowTop, colRight, rowBottom];

        end

        function pxShift = xcorrreg(refImg, movedImg)

            %REGISTERIMG  Register two images using cross-correlation
            %
            %  I = xcorrreg(R, M) registers two images by calculating the
            %  cross-correlation between them. R is the reference or stationary image,
            %  and M is the moved image.
            %
            %  Note: This algorithm only works for translational shifts, and will not
            %  work for rotational shifts or image resizing.

            %Compute the cross-correlation of the two images
            crossCorr = ifft2((fft2(refImg) .* conj(fft2(movedImg))));

            %Find the location in pixels of the maximum correlation
            [xMax, yMax] = find(crossCorr == max(crossCorr(:)));

            %Compute the relative shift in pixels
            Xoffset = fftshift(-size(refImg,1)/2:(size(refImg,1)/2 - 1));
            Yoffset = fftshift(-size(refImg,2)/2:(size(refImg,2)/2 - 1));

            pxShift = round([Xoffset(xMax), Yoffset(yMax)]);

        end

        function [errStruct, stats] = findSegmentationErrors(Itest, Iref)
            %FINDSEGMENTATIONERRORS  Find and count segmentation errors
            %
            %  S = FINDSEGMENTATIONERRORS(TEST, REF) will compare the TEST
            %  image to the REF image. TEST and REF must be label images.

            stats = struct('NumRef', 0, 'NumTest', 0, ...
                'NumOversegmented', 0, 'NumUndersegmented', 0, ...
                'NumMissing', 0, 'NumAdditional', 0);

            nErrors = 0;

            testObjectLabels = unique(Itest);
            nTestObjects = max(testObjectLabels);

            refObjectLabels = unique(Iref);
            nRefObjects = max(refObjectLabels);
            isRefObjFound = false(1, nRefObjects);

            stats.NumRef = nRefObjects;
            stats.NumTest = nTestObjects;

            for currTestObj = 1:nTestObjects
                % if currTestObj == 324
                %     keyboard
                % end

                %Get reference labels under current test object
                currRefLabels = Iref(Itest == currTestObj);

                %Get number of unique labels
                currUniqueRefLabels = unique(currRefLabels);
                nCurrUniqueRefLabels = numel(currUniqueRefLabels);

                %Get size of current object
                szCurrTestObj = nnz(Itest == currTestObj);

                %Check if the test object is present in the reference label
                %image by counting number of zeros
                if nnz(currRefLabels == 0) > (0.9 * szCurrTestObj)

                    nErrors = nErrors + 1;

                    errStruct(nErrors).testObjLabel = currTestObj;
                    errStruct(nErrors).BoundingBox = MaskAnalyzer.getBoundingBox(Itest, currTestObj);
                    errStruct(nErrors).Type = 'Additional';

                    stats.NumAdditional = stats.NumAdditional + 1;

                else

                    %Check if object is under-segmented - this is true if
                    %there are more than 1 reference labels which cover
                    %more than 20% of the area of the cell
                    nLabelsGT = 0;

                    currUniqueRefLabels(currUniqueRefLabels == 0) = [];

                    for ii = reshape(currUniqueRefLabels, 1, [])
                        if nnz(currRefLabels == ii) > 150 || ...
                                nnz(currRefLabels == ii) > (0.15 * szCurrTestObj)

                            nLabelsGT = nLabelsGT + 1;

                            if ii ~= 0

                                %If reference object was already previously
                                %found, then the object is oversegmented
                                if isRefObjFound(ii)

                                    nErrors = nErrors + 1;

                                    errStruct(nErrors).testObjLabel = currTestObj;
                                    errStruct(nErrors).BoundingBox = MaskAnalyzer.getBoundingBox(Itest, currTestObj);
                                    errStruct(nErrors).Type = 'Oversegmented';

                                    stats.NumOversegmented = stats.NumOversegmented + 1;

                                else
                                    isRefObjFound(ii) = true;
                                end

                            end
                        end
                    end

                    if nLabelsGT >= 2

                        nErrors = nErrors + 1;

                        errStruct(nErrors).testObjLabel = currTestObj;
                        errStruct(nErrors).BoundingBox = MaskAnalyzer.getBoundingBox(Itest, currTestObj);
                        errStruct(nErrors).Type = 'Undersegmented';

                        stats.NumUndersegmented = stats.NumUndersegmented + 1;

                    end


                end


            end

            %Find missing objects - any reference objects not yet
            %identified
            for currRefObj = find(~isRefObjFound)

                nErrors = nErrors + 1;

                errStruct(nErrors).refObjLabel = currRefObj;
                errStruct(nErrors).BoundingBox = MaskAnalyzer.getBoundingBox(Iref, currRefObj);
                errStruct(nErrors).Type = 'Missing';

                stats.NumMissing = stats.NumMissing + 1;

            end

            if nErrors == 0
                errStruct = [];
            end

        end

    end



end