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
