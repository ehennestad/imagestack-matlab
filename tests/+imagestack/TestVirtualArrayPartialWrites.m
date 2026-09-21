classdef TestVirtualArrayPartialWrites < matlab.unittest.TestCase
%TestVirtualArrayPartialWrites Writes that replace part of a frame on disk.
%
%   The file stores Y-X-C-T data with 2 channels and 3 timepoints.

    properties
        FilePath
    end

    methods (TestMethodSetup)
        function useTemporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.FilePath = fullfile(fixture.Folder, 'stack.raw');
        end
    end

    methods (Test)
        function testWriteOneChannelOfOneTimepoint(testCase)
            [array, expected] = testCase.createArray();
            cleanup = onCleanup(@() delete(array));
            newChannel = 7000 * ones(4, 5, 'uint16');

            array(:, :, 1, 2) = newChannel;

            expected(:, :, 1, 2) = newChannel;
            testCase.verifyEqual(array(:, :, :, :), expected)
        end

        function testWriteImageRegionAcrossTimepoints(testCase)
            [array, expected] = testCase.createArray();
            cleanup = onCleanup(@() delete(array));
            region = 7000 * ones(2, 2, 2, 3, 'uint16');

            array(2:3, 1:2, :, :) = region;

            expected(2:3, 1:2, :, :) = region;
            testCase.verifyEqual(array(:, :, :, :), expected)
        end

        function testPartialWriteIsVisibleThroughCache(testCase)
            [array, expected] = testCase.createArray('UseDynamicCache', true);
            cleanup = onCleanup(@() delete(array));
            array(:, :, :, 1:3);
            newChannel = 7000 * ones(4, 5, 'uint16');

            array(:, :, 2, 1) = newChannel;

            expected(:, :, 2, 1) = newChannel;
            testCase.verifyEqual(array(:, :, :, 1:3), expected)
        end

        function testWriteFrameSetWritesCurrentChannel(testCase)
            [array, expected] = testCase.createArray();
            delete(array)
            stack = imagestack.ImageStack(testCase.FilePath);
            cleanup = onCleanup(@() delete(stack.Data));
            stack.CurrentChannel = 2;
            newImages = 7000 * ones(4, 5, 1, 2, 'uint16');

            stack.writeFrameSet(newImages, [1, 3])

            expected(:, :, 2, [1, 3]) = newImages;
            testCase.verifyEqual(stack.getFullImage(), expected)
        end

        function testReadDataPadsMissingSubscripts(testCase)
            [array, expected] = testCase.createArray();
            cleanup = onCleanup(@() delete(array));

            testCase.verifyEqual(array.readData({':', ':'}), expected(:, :, 1, 1))
        end
    end

    methods (Access = private)
        function [array, data] = createArray(testCase, varargin)
            data = reshape(uint16(1:(4*5*2*3)), [4, 5, 2, 3]);
            array = imagestack.virtual.Binary(testCase.FilePath, size(data), 'uint16', ...
                'DataDimensionArrangement', 'YXCT', varargin{:});
            array(:, :, :, :) = data;
        end
    end
end
