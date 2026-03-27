classdef TestBinary < matlab.unittest.TestCase

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
        function testCreateAndReopenBinaryArray(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.raw');
            data = reshape(uint16(1:60), [5, 4, 3]);

            binaryArray = imagestack.virtual.Binary(filePath, size(data), 'uint16');
            binaryArray(:, :, :) = data;
            clear binaryArray

            reopened = imagestack.virtual.Binary(filePath);
            testCase.verifyEqual(size(reopened), [5, 4, 3])
            testCase.verifyEqual(reopened(:, :, :), data)
        end

        function testImageStackCanOpenBinaryFile(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.raw');
            data = reshape(uint16(1:60), [5, 4, 3]);

            binaryArray = imagestack.virtual.Binary(filePath, size(data), 'uint16');
            binaryArray(:, :, :) = data;
            clear binaryArray

            stack = imagestack.ImageStack(filePath);
            testCase.verifyEqual(size(stack), [5, 4, 3])
            testCase.verifyEqual(stack.getFrameSet(2), data(:, :, 2))
        end

        function testBinarySupportsDynamicCache(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.raw');
            data = reshape(uint16(1:120), [5, 4, 6]);

            binaryArray = imagestack.virtual.Binary(filePath, size(data), 'uint16');
            binaryArray(:, :, :) = data;
            clear binaryArray

            binaryArray = imagestack.virtual.Binary(filePath, ...
                'UseDynamicCache', true, 'DynamicCacheSize', 2);
            frameA = binaryArray(:, :, 2);
            frameB = binaryArray(:, :, 2);

            testCase.verifyTrue(binaryArray.HasCachedData)
            testCase.verifyEqual(frameA, data(:, :, 2))
            testCase.verifyEqual(frameB, data(:, :, 2))
        end
    end
end
