classdef TestDynamicFrameCache < matlab.unittest.TestCase
%TestDynamicFrameCache Reads through the dynamic frame cache of a VirtualArray.

    properties
        Folder
    end

    methods (TestMethodSetup)
        function useTemporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
        end
    end

    methods (Test)
        function testCachedFramesReturnInRequestedOrder(testCase)
            [array, data] = testCase.createCachedArray();
            cleanup = onCleanup(@() delete(array));

            % Fill the cache in an order that differs from the frame order.
            array(:, :, 3);
            array(:, :, 1:2);

            testCase.verifyEqual(array(:, :, 1:3), data(:, :, 1:3))
            testCase.verifyEqual(array(:, :, [3, 1]), data(:, :, [3, 1]))
        end

        function testRepeatedFrameIndexReturnsRepeatedFrames(testCase)
            [array, data] = testCase.createCachedArray();
            cleanup = onCleanup(@() delete(array));

            testCase.verifyEqual(array(:, :, [2, 2]), data(:, :, [2, 2]))
            testCase.verifyEqual(array(:, :, [2, 5, 2]), data(:, :, [2, 5, 2]))
        end

        function testWriteInvalidatesCachedFrame(testCase)
            [array, data] = testCase.createCachedArray();
            cleanup = onCleanup(@() delete(array));
            array(:, :, 1:2);
            newImage = 9000 * ones(4, 5, 'uint16');

            array(:, :, 1) = newImage;

            testCase.verifyEqual(array(:, :, 1), newImage)
            testCase.verifyEqual(array(:, :, 2), data(:, :, 2))
        end

        function testCacheSmallerThanRequest(testCase)
            [array, data] = testCase.createCachedArray('DynamicCacheSize', 2);
            cleanup = onCleanup(@() delete(array));

            for repeat = 1:3
                testCase.verifyEqual(array(:, :, 1:5), data(:, :, 1:5))
                testCase.verifyEqual(array(:, :, [6, 1, 4]), data(:, :, [6, 1, 4]))
            end
        end

        function testChangingArrangementRebuildsCache(testCase)
            data = reshape(uint16(1:(4*5*2*3)), [4, 5, 2, 3]);
            filePath = fullfile(testCase.Folder, 'rearranged.raw');
            array = imagestack.virtual.Binary(filePath, size(data), 'uint16', ...
                'DataDimensionArrangement', 'YXCT', 'UseDynamicCache', true);
            cleanup = onCleanup(@() delete(array));
            array(:, :, :, :) = data;
            array(:, :, :, 1:2);

            % The frame dimension moves from 4 to 3.
            array.DataDimensionArrangement = 'YXTC';

            reference = imagestack.data.MatlabArray(data, DataDimensionArrangement='YXTC');
            testCase.verifyEqual(array(:, :, :, :), reference(:, :, :, :))
        end

        function testCacheLengthFollowsLeadingDimension(testCase)
            numFrames = 6;
            cache = imagestack.utility.FrameCache([4, 5, numFrames, 2], 'uint16', 1000, ...
                'LeadingDimension', 3);

            testCase.verifyEqual(cache.CacheLength, numFrames)
        end
    end

    methods (Access = private)
        function [array, data] = createCachedArray(testCase, varargin)
            data = reshape(uint16(1:(4*5*6)), [4, 5, 6]);
            filePath = fullfile(testCase.Folder, 'cached.raw');
            array = imagestack.virtual.Binary(filePath, size(data), 'uint16', ...
                'DataDimensionArrangement', 'YXT', 'UseDynamicCache', true, varargin{:});
            array(:, :, :) = data;
        end
    end
end
