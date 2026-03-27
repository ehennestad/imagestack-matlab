classdef TestVirtualArrayContract < matlab.unittest.TestCase

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
        function testCreateAndReopenVirtualArray(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.mock');
            data = reshape(uint16(1:60), [5, 4, 3]);

            array = imagestack.MockVirtualArray(filePath, size(data), 'uint16');
            array(:, :, :) = data;
            clear array

            reopened = imagestack.MockVirtualArray(filePath);
            testCase.verifyEqual(size(reopened), [5, 4, 3])
            testCase.verifyEqual(reopened(:, :, :), data)
            testCase.verifyEqual(reopened.MetaData.DimensionArrangement, 'YXC')
        end

        function testCustomDimensionArrangementRoundTrip(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.mock');
            data = reshape(uint16(1:120), [5, 4, 2, 3]);

            array = imagestack.MockVirtualArray(filePath, size(data), 'uint16', ...
                'DataDimensionArrangement', 'YXCT', ...
                'StackDimensionArrangement', 'YXTC');
            array(:, :, :, :) = permute(data, [1, 2, 4, 3]);
            clear array

            reopened = imagestack.MockVirtualArray(filePath, ...
                'DataDimensionArrangement', 'YXCT', ...
                'StackDimensionArrangement', 'YXTC');
            testCase.verifyEqual(size(reopened), [5, 4, 3, 2])
            testCase.verifyEqual(reopened(:, :, :, :), permute(data, [1, 2, 4, 3]))
        end

        function testDynamicCachePreservesReadBehavior(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.mock');
            data = reshape(uint16(1:240), [5, 4, 2, 6]);

            array = imagestack.MockVirtualArray(filePath, size(data), 'uint16');
            array(:, :, :, :) = data;
            clear array

            array = imagestack.MockVirtualArray(filePath, ...
                'UseDynamicCache', true, ...
                'DynamicCacheSize', 2);

            block1 = array(:, :, :, 2);
            block2 = array(:, :, :, [2, 4]);

            testCase.verifyTrue(array.HasCachedData)
            testCase.verifyEqual(block1, data(:, :, :, 2))
            testCase.verifyEqual(block2, data(:, :, :, [2, 4]))
        end

        function testMetadataIsWrittenForWritableVirtualArray(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.mock');
            array = imagestack.MockVirtualArray(filePath, [5, 4, 3], 'uint16');

            metadataPath = fullfile(testCase.TempFolder, 'stack.yaml');

            testCase.verifyTrue(isfile(filePath))
            testCase.verifyTrue(isfile(metadataPath))
            testCase.verifyEqual(array.MetaData.Size, [5, 4, 3])
        end
    end
end
