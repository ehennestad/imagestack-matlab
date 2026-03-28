classdef TestImageStackConsumerContract < matlab.unittest.TestCase

    properties
        TempFolder
    end

    methods (TestMethodSetup)
        function createTempFolder(testCase)
            testCase.TempFolder = tempname;
            mkdir(testCase.TempFolder)
        end
    end

    methods (TestMethodTeardown)
        function removeTempFolder(testCase)
            if isfolder(testCase.TempFolder)
                rmdir(testCase.TempFolder, 's')
            end
        end
    end

    methods (Test)
        function testWriteFrameSetToMatlabArray(testCase)
            stack = testCase.createXYTStack();
            replacement = uint16(1000 + reshape(1:20, [5, 4]));

            stack.writeFrameSet(replacement, 3)

            testCase.verifyEqual(stack.getFrameSet(3), replacement)
        end

        function testWriteFrameSetToBinaryStack(testCase)
            [stack, sourceData] = testCase.createWritableBinaryStack();
            replacement = uint16(5000 + reshape(1:20, [5, 4]));

            stack.writeFrameSet(replacement, 2)

            expected = sourceData;
            expected(:, :, 2) = replacement;
            testCase.verifyEqual(stack.getFrameSet('all'), expected)
        end

        function testGetChunkedFrameIndicesReturnsAllChunksWhenChunkIndexOmitted(testCase)
            stack = testCase.createXYTStack(10);

            [chunkIndices, numChunks] = stack.getChunkedFrameIndices(4);

            testCase.verifyClass(chunkIndices, 'cell')
            testCase.verifyEqual(numChunks, 3)
            testCase.verifyEqual(chunkIndices, {1:4, 5:8, 9:10})
        end

        function testGetChunkedFrameIndicesHonorsIntervalBounds(testCase)
            stack = testCase.createXYTStack(12);

            [chunkIndices, numChunks] = stack.getChunkedFrameIndices(3, [], 'T', 3, 10);

            testCase.verifyEqual(numChunks, 3)
            testCase.verifyEqual(chunkIndices, {3:5, 6:8, 9:10})
        end

        function testChooseChunkLengthReturnsPositiveLength(testCase)
            stack = imagestack.ImageStack(zeros(5, 4, 2, 9, 'uint16'), ...
                'DataDimensionArrangement', 'YXCT');

            nT = stack.chooseChunkLength('uint16', 1/32, 'T');
            nC = stack.chooseChunkLength('uint16', 1/32, 'C');

            testCase.verifyGreaterThanOrEqual(nT, 1)
            testCase.verifyGreaterThanOrEqual(nC, 1)
            testCase.verifyLessThanOrEqual(nT, stack.NumTimepoints)
            testCase.verifyLessThanOrEqual(nC, stack.NumChannels)
        end

        function testDynamicCacheEnabledTogglesVirtualBackend(testCase)
            [stack, ~] = testCase.createWritableBinaryStack();

            stack.DynamicCacheEnabled = 'on';
            testCase.verifyTrue(stack.DynamicCacheEnabled)
            testCase.verifyTrue(stack.Data.UseDynamicCache)

            stack.DynamicCacheEnabled = 'off';
            testCase.verifyFalse(stack.DynamicCacheEnabled)
            testCase.verifyFalse(stack.Data.UseDynamicCache)
        end
    end

    methods (Access = private)
        function stack = createXYTStack(~, numFrames)
            if nargin < 2
                numFrames = 6;
            end
            data = reshape(uint16(1:(5*4*numFrames)), [5, 4, numFrames]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');
        end

        function [stack, data] = createWritableBinaryStack(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.raw');
            data = reshape(uint16(1:(5*4*4)), [5, 4, 4]);

            binaryArray = imagestack.virtual.Binary(filePath, size(data), 'uint16');
            binaryArray(:, :, :) = data;
            clear binaryArray

            stack = imagestack.ImageStack(filePath);
        end
    end
end
