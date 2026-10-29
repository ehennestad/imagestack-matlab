classdef TestImageStackAxisResolution < matlab.unittest.TestCase
%TestImageStackAxisResolution Axis resolution in the ImageStack front end.
%
%   Covers stacks without a T dimension, chunking along C and Z, and
%   backends whose data dimension order differs from the stack order.

    methods (Test)
        function testStackWithoutTimeIsIndexedAlongPlanes(testCase)
            data = reshape(uint8(1:(5*4*6)), [5, 4, 6]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXZ');

            testCase.verifyEqual(stack.NumPlanes, 6)
            testCase.verifyEqual(stack.NumTimepoints, 1)
            testCase.verifyEqual(stack.getFrameSet(2:3), data(:, :, 2:3))
        end

        function testStackWithoutTimeAndPlanesIsIndexedAlongChannels(testCase)
            data = reshape(uint8(1:(5*4*3)), [5, 4, 3]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXC');

            testCase.verifyEqual(stack.NumChannels, 3)
            testCase.verifyEqual(stack.getFrameSet(2), data(:, :, 2))
        end

        function testNumFramesFollowsNansenFormula(testCase)
            % Selected channels times selected planes times timepoints.
            stack = imagestack.ImageStack(zeros(5, 4, 2, 3, 7, 'uint8'), ...
                'DataDimensionArrangement', 'YXCZT');

            testCase.verifyEqual(stack.NumFrames, 7)

            stack.CurrentChannel = 1:2;
            stack.CurrentPlane = ':';
            testCase.verifyEqual(stack.NumFrames, 2 * 3 * 7)
        end

        function testSingleTimepointSeriesKeepsTimeAxis(testCase)
            % size() drops the trailing singleton, so DataSize is [5, 4]
            % while the arrangement has three letters.
            image = reshape(uint8(1:20), [5, 4, 1]);
            stack = imagestack.ImageStack(image, 'DataDimensionArrangement', 'YXT');

            testCase.verifyEqual(stack.NumTimepoints, 1)
            testCase.verifyEqual(stack.NumFrames, 1)
            testCase.verifyEqual(stack.getFrameSet(1), image)
        end

        function testSingleImageAcceptsOnlyIndexOne(testCase)
            image = reshape(uint8(1:20), [5, 4]);
            stack = imagestack.ImageStack(image, 'DataDimensionArrangement', 'YX');

            testCase.verifyEqual(stack.NumFrames, 1)
            testCase.verifyEqual(stack.getFrameSet(1), image)
            testCase.verifyEqual(stack.getFrameSet('all'), image)
            testCase.verifyEqual(stack.getFrameSetSize(1), [5, 4])
            testCase.verifyError(@() stack.getFrameSet(2), ...
                'IMAGESTACK:FrameIndexOutOfRange')
        end

        function testGetChunkAlongPlaneAxisOfVolumeTimeSeries(testCase)
            data = reshape(uint16(1:(3*2*4*5)), [3, 2, 4, 5]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXZT');

            testCase.verifyEqual(stack.getChunk(1, 2, 'Z'), data(:, :, 1:2, :))
            testCase.verifyEqual(stack.getChunk(2, 3, 'Z'), data(:, :, 4, :))
            testCase.verifyEqual(stack.getChunk(2, 2, 'T'), data(:, :, :, 3:4))
        end

        function testGetChunkAlongChannelAxis(testCase)
            data = reshape(uint16(1:(3*2*4*5)), [3, 2, 4, 5]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCT');

            testCase.verifyEqual(stack.getChunk(2, 3, 'C'), data(:, :, 4, :))
        end

        function testGetChunkSizeWithPermutedDataOrder(testCase)
            stack = createPermutedStack();
            bytesPerPixel = 2; % uint16
            bytesPerTimepoint = 5 * 4 * 2 * bytesPerPixel; % Y * X * Z
            numTimepoints = 3;

            chunkSize = stack.getChunkSize(numTimepoints * bytesPerTimepoint, 'T');

            testCase.verifyEqual(chunkSize, [5, 4, 2, 3])
        end

        function testExtendedReadWithPermutedDataOrder(testCase)
            [stack, stackOrderData] = createPermutedStack();

            testCase.verifyEqual(stack.getFullImage(), stackOrderData)
            testCase.verifyEqual(stack.getFrameSet(1:3, 'extended'), ...
                stackOrderData(:, :, :, 1:3))
            testCase.verifyEqual(stack.getFrameSetSize(1:3, 'extended'), ...
                size(stack.getFrameSet(1:3, 'extended')))
            testCase.verifyEqual(stack.getFrameSetSize('all', 'extended'), ...
                size(stackOrderData))
        end

        function testStandardReadWithPermutedDataOrder(testCase)
            [stack, stackOrderData] = createPermutedStack();
            stack.CurrentPlane = 2;

            testCase.verifyEqual(stack.getFrameSet(4:5), stackOrderData(:, :, 2, 4:5))
        end

        function testExtendedProjectionWithPermutedDataOrder(testCase)
            [stack, stackOrderData] = createPermutedStack();

            projection = stack.getProjection('max', 'all', 'T', 'extended');

            testCase.verifyEqual(projection, max(stackOrderData, [], 4))
        end

        function testGetProjectionRejectsMissingDimension(testCase)
            stack = imagestack.ImageStack(zeros(5, 4, 6, 'uint8'), ...
                'DataDimensionArrangement', 'YXT');

            testCase.verifyError(@() stack.getProjection('max', 'all', 'Z'), ...
                'IMAGESTACK:UnknownDimension')
        end
    end
end

function [stack, stackOrderData] = createPermutedStack()
% Backend stores Y-X-T-Z (6 timepoints, 2 planes). The stack presents the
% canonical Y-X-Z-T order, so data order and stack order differ.
backendData = reshape(uint16(1:(5*4*6*2)), [5, 4, 6, 2]);
stack = imagestack.ImageStack(backendData, 'DataDimensionArrangement', 'YXTZ');
stackOrderData = permute(backendData, [1, 2, 4, 3]);
end
