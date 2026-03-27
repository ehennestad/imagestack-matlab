classdef TestTiffMultiPart < matlab.unittest.TestCase

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
        function testOpenSingleMultipageTiff(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.tif');
            data = reshape(uint16(1:60), [5, 4, 3]);
            writeMultipageTiff(filePath, data)

            array = imagestack.virtual.TiffMultiPart(filePath);

            testCase.verifyEqual(size(array), [5, 4, 3])
            testCase.verifyEqual(array(:, :, :), data)
        end

        function testOpenMultipartTiffStack(testCase)
            filePath1 = fullfile(testCase.TempFolder, 'stack_001.tif');
            filePath2 = fullfile(testCase.TempFolder, 'stack_002.tif');

            data1 = reshape(uint16(1:40), [5, 4, 2]);
            data2 = reshape(uint16(41:80), [5, 4, 2]);
            writeMultipageTiff(filePath1, data1)
            writeMultipageTiff(filePath2, data2)

            array = imagestack.virtual.TiffMultiPart(filePath1);

            expected = cat(3, data1, data2);
            testCase.verifyEqual(size(array), [5, 4, 4])
            testCase.verifyEqual(array(:, :, :), expected)
        end

        function testImageStackCanOpenTiff(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.tif');
            data = reshape(uint16(1:60), [5, 4, 3]);
            writeMultipageTiff(filePath, data)

            stack = imagestack.ImageStack(filePath);

            testCase.verifyEqual(size(stack), [5, 4, 3])
            testCase.verifyEqual(stack.getFrameSet(2), data(:, :, 2))
        end
    end
end

function writeMultipageTiff(filePath, data)
for i = 1:size(data, 3)
    if i == 1
        imwrite(data(:, :, i), filePath, 'tif')
    else
        imwrite(data(:, :, i), filePath, 'tif', 'WriteMode', 'append')
    end
end
end
