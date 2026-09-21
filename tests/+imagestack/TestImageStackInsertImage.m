classdef TestImageStackInsertImage < matlab.unittest.TestCase
%TestImageStackInsertImage Inserting timepoints into in-memory stacks.

    methods (Test)
        function testAppendToSingleImageCreatesTimeSeries(testCase)
            first = reshape(uint8(1:20), [4, 5]);
            second = first + 100;
            stack = imagestack.ImageStack(first, 'DataDimensionArrangement', 'YX');

            stack.insertImage(second)

            testCase.verifyEqual(stack.DataDimensionOrder, 'YXT')
            testCase.verifyEqual(stack.NumTimepoints, 2)
            testCase.verifyEqual(stack.getFrameSet('all'), cat(3, first, second))
        end

        function testPrependToSingleImage(testCase)
            first = reshape(uint8(1:20), [4, 5]);
            second = first + 100;
            stack = imagestack.ImageStack(first, 'DataDimensionArrangement', 'YX');

            stack.insertImage(second, 1)

            testCase.verifyEqual(stack.getFrameSet('all'), cat(3, second, first))
        end

        function testInsertInsideTimeSeriesUpdatesDataAndMetadata(testCase)
            data = reshape(uint8(1:(4*5*3)), [4, 5, 3]);
            inserted = 200 * ones(4, 5, 'uint8');
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');

            stack.insertImage(inserted, 2)

            expected = cat(3, data(:, :, 1), inserted, data(:, :, 2:3));
            testCase.verifyEqual(stack.getFrameSet('all'), expected)
            testCase.verifyEqual(stack.MetaData.SizeT, 4)
            testCase.verifyEqual(stack.MetaData.Size, [4, 5, 4])
        end

        function testAppendMultiChannelTimepoint(testCase)
            data = zeros(4, 5, 2, 3, 'uint8');
            inserted = ones(4, 5, 2, 'uint8');
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCT');

            stack.insertImage(inserted)

            testCase.verifyEqual(stack.NumChannels, 2)
            testCase.verifyEqual(stack.NumTimepoints, 4)
            testCase.verifyEqual(stack.getFrameSet(4, 'extended'), inserted)
        end

        function testAppendColorImageToColorImageCreatesTimeSeries(testCase)
            first = zeros(4, 5, 3, 'uint8');
            second = ones(4, 5, 3, 'uint8');
            stack = imagestack.ImageStack(first, 'DataDimensionArrangement', 'YXC');

            stack.insertImage(second)

            testCase.verifyEqual(stack.DataDimensionOrder, 'YXCT')
            testCase.verifyEqual(stack.NumChannels, 3)
            testCase.verifyEqual(stack.NumTimepoints, 2)
        end

        function testGrayscaleImageIsNotAddedAsChannelOfColorImage(testCase)
            stack = imagestack.ImageStack(zeros(4, 5, 3, 'uint8'), ...
                'DataDimensionArrangement', 'YXC');

            testCase.verifyError(@() stack.insertImage(ones(4, 5, 'uint8')), ...
                'IMAGESTACK:InsertSizeMismatch')
            testCase.verifyEqual(stack.NumChannels, 3)
        end

        function testInsertRejectsMismatchedImageSize(testCase)
            stack = imagestack.ImageStack(zeros(4, 5, 3, 'uint8'), ...
                'DataDimensionArrangement', 'YXT');

            testCase.verifyError(@() stack.insertImage(ones(5, 4, 'uint8')), ...
                'IMAGESTACK:InsertSizeMismatch')
        end

        function testInsertRejectsIndexOutOfRange(testCase)
            stack = imagestack.ImageStack(zeros(4, 5, 3, 'uint8'), ...
                'DataDimensionArrangement', 'YXT');
            image = ones(4, 5, 'uint8');

            for invalidIndex = [0, 5, 1.5]
                testCase.verifyError(@() stack.insertImage(image, invalidIndex), ...
                    'IMAGESTACK:InsertIndexOutOfRange')
            end
            testCase.verifyEqual(stack.NumTimepoints, 3)
        end

        function testInsertRejectsPermutedDataOrder(testCase)
            % The backend stores X-Y-T while the stack presents Y-X-T.
            stack = imagestack.ImageStack(zeros(5, 4, 3, 'uint8'), ...
                'DataDimensionArrangement', 'XYT');

            testCase.verifyError(@() stack.insertImage(ones(4, 5, 'uint8')), ...
                'IMAGESTACK:InsertNotSupported')
        end

        function testBackendInsertsAlongTimeWhenTimeIsNotLast(testCase)
            % Data order Y-X-T-C with 2 timepoints and 3 channels.
            backend = imagestack.data.MatlabArray(zeros(4, 5, 2, 3, 'uint8'), ...
                DataDimensionArrangement='YXTC');
            timepoint = ones(4, 5, 1, 3, 'uint8');

            backend.insertImageData(timepoint, 3)

            testCase.verifyEqual(backend.DataSize, [4, 5, 3, 3])
            testCase.verifyEqual(backend.DataArray(:, :, 3, :), timepoint)
            testCase.verifyEqual(backend.MetaData.SizeT, 3)
            testCase.verifyEqual(backend.MetaData.SizeC, 3)
        end
    end
end
