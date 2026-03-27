classdef TestStackMetadata < matlab.unittest.TestCase

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
        function testSampleRateRoundTrip(testCase)
            metadata = imagestack.metadata.StackMetadata();
            metadata.SampleRate = 5;

            testCase.verifyEqual(metadata.TimeIncrement, 0.2, 'AbsTol', 1e-12)
            testCase.verifyEqual(metadata.SampleRate, 5, 'AbsTol', 1e-12)
        end

        function testImageSizeSetterUpdatesPhysicalSize(testCase)
            metadata = imagestack.metadata.StackMetadata();
            metadata.SizeX = 10;
            metadata.SizeY = 5;
            metadata.ImageSize = [20, 15];

            testCase.verifyEqual(metadata.PhysicalSizeX, 2)
            testCase.verifyEqual(metadata.PhysicalSizeY, 3)
            testCase.verifyEqual(metadata.ImageSize, [20, 15])
        end

        function testWriteAndReadMetadata(testCase)
            filePath = fullfile(testCase.TempFolder, 'stack.raw');
            metadata = imagestack.metadata.StackMetadata(filePath);
            metadata.DimensionArrangement = 'YXT';
            metadata.Size = [5, 4, 3];
            metadata.Class = 'uint16';
            metadata.PhysicalSizeX = 1.5;
            metadata.PhysicalSizeY = 2.5;
            metadata.TimeIncrement = 0.25;
            metadata.TimeIncrementUnit = 'second';
            metadata.StartTime = datetime(2025, 1, 2, 3, 4, 5, 678);
            metadata.SpatialPosition = [1, 2, 3];
            metadata.FrameTimes = [0.1, 0.2, 0.3];
            metadata.writeToFile()

            reopened = imagestack.metadata.StackMetadata(filePath);

            testCase.verifyEqual(reopened.DimensionArrangement, 'YXT')
            testCase.verifyEqual(reopened.Size, [5, 4, 3])
            testCase.verifyEqual(reopened.Class, 'uint16')
            testCase.verifyEqual(reopened.PhysicalSizeX, 1.5)
            testCase.verifyEqual(reopened.PhysicalSizeY, 2.5)
            testCase.verifyEqual(reopened.TimeIncrement, 0.25)
            testCase.verifyEqual(reopened.SampleRate, 4)
            testCase.verifyEqual(reopened.SpatialPosition, [1, 2, 3])
            testCase.verifyEqual(reopened.FrameTimes, [0.1, 0.2, 0.3], 'AbsTol', 1e-12)
            testCase.verifyEqual(string(reopened.StartTime), string(metadata.StartTime))
        end
    end
end
