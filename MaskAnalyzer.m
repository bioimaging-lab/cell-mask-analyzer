classdef MaskAnalyzer
    %MASKANALYZER  Quantify errors in cell image masks

    properties


    end

    methods

        function quantifyErrors(obj, mask, gtImage)
            %QUANTIFYERRORS

            %Basic process:
            %  * Register the two masks to correct for any systematic erros
            %  * Label the test mask
            %  * Calculate over/under-segmentation

            nFrames = numel(imfinfo(gtImage));

            for iT = 1:nFrames

                








            end

        end

    end

    methods (Static)

        function labels = relabelMask(mask)
            %RELABELMASK  Relabels a mask or label image with unique IDs
            %
            %  L = RELABELMASK(MASK) will return a labelled image, where
            %  each unique object in MASK is labeled with an ID. MASK can
            %  be either a binary mask or a different labelled image. The
            %  background pixels will be labelled with a 0.

            %Initialize the output label matrix
            labels = zeros(size(mask));

            %Get data from each object
            tmpData = regionprops(Icp3, 'Area', 'PixelIdxList');

            %(Mainly for input labels) Remove objects with no areas
            tmpData([tmpData.Area] == 0) = [];

            %Label the objects
            currID = 0;

            for ii = 1:numel(tmpData)

                currID = currID + 1;
                labels(cellData(iCell).PixelIdxList) = currID;

            end

            imshow(label2rgb(labels))

        end



    end



end