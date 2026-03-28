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

        function testGetFrameSetSizeMatchesStandardRead(testCase)
            data = reshape(uint16(1:(5*4*2*6)), [5, 4, 2, 6]);
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXCT', 'CurrentChannel', 2);

            expected = size(stack.getFrameSet(2:4, 'standard'));
            actual = stack.getFrameSetSize(2:4, 'standard');

            testCase.verifyEqual(actual, expected)
        end

        function testGetFrameSetSizeMatchesExtendedRead(testCase)
            data = reshape(uint16(1:(5*4*2*6)), [5, 4, 2, 6]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCT');

            expected = size(stack.getFrameSet(2:4, 'extended'));
            actual = stack.getFrameSetSize(2:4, 'extended');

            testCase.verifyEqual(actual, expected)
        end

        function testGetMovingWindowFrameIndicesHandlesEdges(testCase)
            stack = testCase.createXYTStack(10);

            testCase.verifyEqual(stack.getMovingWindowFrameIndices(1, 5), 1:5)
            testCase.verifyEqual(stack.getMovingWindowFrameIndices(5, 5), 3:7)
            testCase.verifyEqual(stack.getMovingWindowFrameIndices(10, 5), 6:10)
        end

        function testGetDimensionNumberReturnsExpectedAxis(testCase)
            data = reshape(uint16(1:(5*4*2*3*6)), [5, 4, 2, 3, 6]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCZT');

            testCase.verifyEqual(stack.getDimensionNumber('Z'), 4)
            testCase.verifyEmpty(stack.getDimensionNumber('Q'))
        end

        function testFramePropertiesAndIntensityHelpers(testCase)
            stack = imagestack.ImageStack(zeros(5, 4, 3, 7, 'single'), ...
                'DataDimensionArrangement', 'YXCT', 'CurrentChannel', ':');

            testCase.verifyEqual(stack.FrameSize, [5, 4])
            testCase.verifyEqual(stack.NumFrames, 21)
            testCase.verifyEqual(stack.DataTypeIntensityLimits, [0, 1])
        end

        function testGetDataIntensityLimitsReflectsStackData(testCase)
            data = reshape(single(linspace(2, 11, 5*4*6)), [5, 4, 6]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');

            testCase.verifyEqual(stack.getDataIntensityLimits(), double([2, 11]))
        end

        function testGetFullProjectionInvalidatesAfterWrite(testCase)
            data = reshape(uint16(1:(5*4*4)), [5, 4, 4]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');

            initialProjection = stack.getFullProjection('max');
            replacement = uint16(9000 + reshape(1:20, [5, 4]));
            stack.writeFrameSet(replacement, 1)
            updatedProjection = stack.getFullProjection('max');

            testCase.verifyNotEqual(updatedProjection, initialProjection)
            testCase.verifyEqual(updatedProjection, max(cat(3, replacement, data(:, :, 2:4)), [], 3))
        end

        function testGetSampleRateUsesMetadata(testCase)
            stack = testCase.createXYTStack(5);
            stack.MetaData.SampleRate = 15;

            testCase.verifyEqual(stack.getSampleRate(), 15)
        end

        function testGetFullImageReturnsExtendedData(testCase)
            data = reshape(uint16(1:(5*4*2*3)), [5, 4, 2, 3]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCT');

            testCase.verifyEqual(stack.getFullImage(), data)
        end

        function testIsVirtualReflectsBackendType(testCase)
            matlabStack = testCase.createXYTStack(4);
            [binaryStack, ~] = testCase.createWritableBinaryStack();

            testCase.verifyFalse(matlabStack.IsVirtual)
            testCase.verifyTrue(binaryStack.IsVirtual)
        end

        function testAddToStaticCacheEnablesHasStaticCache(testCase)
            stack = testCase.createXYTStack(4);
            cacheData = stack.getFrameSet(1:2);

            stack.addToStaticCache(cacheData, 1:2)

            testCase.verifyTrue(stack.HasStaticCache)
            testCase.verifyGreaterThan(stack.getCacheByteSize(), 0)
        end

        function testColorModelAndCustomColorModelRoundTrip(testCase)
            stack = testCase.createXYTStack(4);
            customColors = [1, 0, 0; 0, 1, 0];

            stack.ColorModel = 'Custom';
            stack.CustomColorModel = customColors;

            testCase.verifyEqual(stack.ColorModel, 'Custom')
            testCase.verifyEqual(stack.CustomColorModel, customColors)
        end

        function testDataIntensityLimitsCanBeAssigned(testCase)
            stack = testCase.createXYTStack(4);

            stack.DataIntensityLimits = [10, 20];

            testCase.verifyEqual(stack.DataIntensityLimits, [10, 20])
            testCase.verifyEqual(stack.getDataIntensityLimits(), [10, 20])
        end

        function testInsertImageIntoInMemoryStack(testCase)
            stack = testCase.createXYTStack(4);
            insertedImage = uint16(700 + reshape(1:20, [5, 4]));

            stack.insertImage(insertedImage, 3)

            testCase.verifyEqual(stack.NumTimepoints, 5)
            testCase.verifyEqual(stack.getFrameSet(3), insertedImage)
        end

        function testDownsampleTReturnsExpectedMean(testCase)
            data = reshape(uint16(1:(5*4*6)), [5, 4, 6]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');

            downsampled = stack.downsampleT(2, 'mean');

            expected = cat(3, ...
                cast(mean(data(:, :, 1:2), 3), 'uint16'), ...
                cast(mean(data(:, :, 3:4), 3), 'uint16'), ...
                cast(mean(data(:, :, 5:6), 3), 'uint16'));
            testCase.verifyEqual(downsampled.getFrameSet('all'), expected)
        end

        function testDownsampleTWorksForVirtualSource(testCase)
            [stack, sourceData] = testCase.createWritableBinaryStack();

            downsampled = stack.downsampleT(2, 'max');

            expected = cat(3, ...
                max(sourceData(:, :, 1:2), [], 3), ...
                max(sourceData(:, :, 3:4), [], 3));
            testCase.verifyEqual(downsampled.getFrameSet('all'), expected)
        end

        function testMultiResolutionScaledReadReturnsExpectedSize(testCase)
            stack = testCase.createXYTStack(4);
            multiresStack = imagestack.views.MultiResolutionStack(stack);

            scaled = multiresStack.getFrameSet(1, 'Scale', 0.5);

            testCase.verifyEqual(size(scaled), [3, 2])
        end

        function testMultiResolutionRoiReadReturnsExpectedCrop(testCase)
            data = reshape(uint16(1:(6*8*2)), [6, 8, 2]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');
            multiresStack = imagestack.views.MultiResolutionStack(stack);

            roiData = multiresStack.getFrameSet(1, 'Scale', 0.5, ...
                'ROI', [2, 3; 1, 2]);

            scaledSource = data(1:2:end, 1:2:end, 1);
            testCase.verifyEqual(roiData, scaledSource(1:2, 2:3))
        end

        function testMultiResolutionReusesCachedPyramidLevel(testCase)
            stack = testCase.createXYTStack(4);
            multiresStack = imagestack.views.MultiResolutionStack(stack);

            multiresStack.getFrameSet(1, 'Scale', 0.5);
            cacheCountAfterFirstRead = multiresStack.getNumCachedLevels();
            multiresStack.getFrameSet(2, 'Scale', 0.5);

            testCase.verifyEqual(cacheCountAfterFirstRead, 2)
            testCase.verifyEqual(multiresStack.getNumCachedLevels(), 2)
        end

        function testProcessorSimulationWorkflow(testCase)
            sourceData = reshape(uint16(1:(5*4*6)), [5, 4, 6]);
            sourceStack = imagestack.ImageStack(sourceData, 'DataDimensionArrangement', 'YXT');
            outputStack = imagestack.ImageStack(zeros(size(sourceData), 'uint16'), ...
                'DataDimensionArrangement', 'YXT');

            [chunks, numChunks] = sourceStack.getChunkedFrameIndices(2);
            for i = 1:numChunks
                frames = sourceStack.getFrameSet(chunks{i});
                processed = frames + 1;
                outputStack.writeFrameSet(processed, chunks{i})
            end

            testCase.verifyEqual(outputStack.getFrameSet('all'), sourceData + 1)
        end

        function testViewerSimulationWorkflow(testCase)
            data = reshape(uint16(1:(5*4*2*6)), [5, 4, 2, 6]);
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXCT', 'CurrentChannel', ':');

            movingWindow = stack.getMovingWindowFrameIndices(3, 3);
            frameSetSize = stack.getFrameSetSize(movingWindow, 'standard');
            frameSet = stack.getFrameSet(movingWindow, 'standard');
            projection = stack.getFullProjection('max');
            stack.DynamicCacheEnabled = false;

            testCase.verifyEqual(frameSetSize, size(frameSet))
            testCase.verifyEqual(size(projection), [5, 4, 2])
            testCase.verifyFalse(stack.DynamicCacheEnabled)
        end

        function testHighResolutionViewerSimulation(testCase)
            data = reshape(uint16(1:(8*8*4)), [8, 8, 4]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');
            multiresStack = imagestack.views.MultiResolutionStack(stack);

            roiA = multiresStack.getDisplayFrame(1, 'Scale', 0.5, ...
                'ROI', [1, 2; 1, 2]);
            roiB = multiresStack.getDisplayFrame(1, 'Scale', 0.5, ...
                'ROI', [2, 3; 1, 2]);

            testCase.verifyEqual(multiresStack.getNumCachedLevels(), 2)
            testCase.verifyNotEqual(roiA, roiB)
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
