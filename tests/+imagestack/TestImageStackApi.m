classdef TestImageStackApi < matlab.unittest.TestCase

    methods (Test)
        function testGetFrameSetAll(testCase)
            data = reshape(uint16(1:120), [5, 4, 2, 3]);
            stack = imagestack.ImageStack(data, 'CurrentChannel', ':');

            result = stack.getFrameSet('all');

            testCase.verifyEqual(result, data)
        end

        function testGetProjectionMeanOverTime(testCase)
            data = reshape(single(1:120), [5, 4, 2, 3]);
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXCT');

            projection = stack.getProjection('mean', 'all', 'T', 'extended');

            testCase.verifyEqual(projection, mean(data, 4))
        end

        function testGetProjectionMaxStandardRespectsCurrentChannel(testCase)
            data = reshape(uint16(1:120), [5, 4, 2, 3]);
            stack = imagestack.ImageStack(data, 'CurrentChannel', 2, ...
                'DataDimensionArrangement', 'YXCT');

            projection = stack.getProjection('max', 'all', 'T');

            testCase.verifyEqual(projection, max(data(:, :, 2, :), [], 4))
        end

        function testGetChunkedFrameIndices(testCase)
            data = zeros(5, 4, 10, 'uint16');
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXT');

            [indices, numChunks] = stack.getChunkedFrameIndices(4, 2, 'T');

            testCase.verifyEqual(indices, 5:8)
            testCase.verifyEqual(numChunks, 3)
        end

        function testGetChunkReturnsExpectedFrames(testCase)
            data = reshape(uint16(1:200), [5, 4, 10]);
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXT');

            chunk = stack.getChunk(2, 4, 'T');

            testCase.verifyEqual(chunk, data(:, :, 5:8))
        end

        function testGetChunkSize(testCase)
            data = zeros(5, 4, 2, 10, 'uint16');
            stack = imagestack.ImageStack(data, ...
                'DataDimensionArrangement', 'YXCT');

            chunkSize = stack.getChunkSize(5 * 4 * 2 * 3 * 2, 'T');

            testCase.verifyEqual(chunkSize(1:3), [5, 4, 2])
            testCase.verifyEqual(chunkSize(4), 3)
        end
    end
end
