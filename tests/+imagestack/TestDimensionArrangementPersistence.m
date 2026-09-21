classdef TestDimensionArrangementPersistence < matlab.unittest.TestCase
%TestDimensionArrangementPersistence Data arrangement of file-backed arrays.
%
%   The data is stored as Y-X-T-Z, which differs from the arrangement that
%   is guessed from a 4D size (Y-X-C-T).

    properties
        FilePath
    end

    properties (Constant)
        DataSize = [5, 4, 3, 2]
        StackOrderPermutation = [1, 2, 4, 3] % Y-X-T-Z data to Y-X-Z-T stack
    end

    methods (TestMethodSetup)
        function useTemporaryFolder(testCase)
            fixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.FilePath = fullfile(fixture.Folder, 'stack.raw');
        end
    end

    methods (Test)
        function testCreateWithOnlyDataArrangement(testCase)
            array = testCase.createArray();
            cleanup = onCleanup(@() delete(array));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXTZ')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXZT')
            testCase.verifyEqual(size(array), [5, 4, 2, 3])
        end

        function testReopenRestoresSavedArrangement(testCase)
            data = reshape(uint16(1:prod(testCase.DataSize)), testCase.DataSize);
            stackOrderData = permute(data, testCase.StackOrderPermutation);
            array = testCase.createArray();
            array(:, :, :, :) = stackOrderData;
            delete(array)

            reopened = imagestack.virtual.Binary(testCase.FilePath);
            cleanup = onCleanup(@() delete(reopened));

            testCase.verifyEqual(reopened.DataDimensionArrangement, 'YXTZ')
            testCase.verifyEqual(reopened(:, :, :, :), stackOrderData)
        end

        function testReopenKeepsArrangementInMetadataFile(testCase)
            array = testCase.createArray();
            delete(array)

            reopened = imagestack.virtual.Binary(testCase.FilePath);
            delete(reopened)

            testCase.verifyEqual(testCase.readSavedArrangement(), 'YXTZ')
        end

        function testCallerArrangementOverridesSavedArrangement(testCase)
            array = testCase.createArray();
            delete(array)

            reopened = imagestack.virtual.Binary(testCase.FilePath, ...
                'DataDimensionArrangement', 'YXZT');
            delete(reopened)

            testCase.verifyEqual(testCase.readSavedArrangement(), 'YXZT')
        end

        function testFailedConstructionIsWarningFree(testCase)
            % The destructor runs for an object whose constructor failed.
            % An error in it surfaces as a warning.
            testCase.verifyWarningFree(@() testCase.constructWithInvalidOption())
        end
    end

    methods (Access = private)
        function array = createArray(testCase)
            array = imagestack.virtual.Binary(testCase.FilePath, ...
                testCase.DataSize, 'uint16', 'DataDimensionArrangement', 'YXTZ');
        end

        function arrangement = readSavedArrangement(testCase)
            [folder, name] = fileparts(testCase.FilePath);
            metadata = jsondecode(fileread(fullfile(folder, [name, '.yaml'])));
            arrangement = metadata.DimensionArrangement;
        end

        function constructWithInvalidOption(testCase)
            try
                imagestack.virtual.Binary(testCase.FilePath, testCase.DataSize, ...
                    'uint16', 'DataDimensionArrangement', 'YXTZ', ...
                    'StackDimensionArrangement', 'YX');
            catch
                % The constructor is expected to fail. Only the destructor
                % of the partially built object is under test.
            end
        end
    end
end
