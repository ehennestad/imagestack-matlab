classdef TestImageStackIndexing < matlab.unittest.TestCase

    methods (Test)
        function testDirectReadUsesActiveIndexingBackend(testCase)
            data = reshape(uint16(1:5*4*2*3), [5, 4, 2, 3]);
            array = imagestack.data.MatlabArray(data, ...
                DataDimensionArrangement='YXCT', ...
                StackDimensionArrangement='YXTC');

            expected = ipermute(data(:, :, 2, 3), [1, 2, 4, 3]);
            actual = array(:, :, 3, 2);

            testCase.verifyEqual(actual, expected)
        end

        function testDirectWriteUsesActiveIndexingBackend(testCase)
            array = imagestack.data.MatlabArray(zeros(5, 4, 2, 3, 'uint16'), ...
                DataDimensionArrangement='YXCT', ...
                StackDimensionArrangement='YXTC');
            patch = uint16(9 * ones(5, 4));

            array(:, :, 2, 1) = patch;

            testCase.verifyEqual(array.DataArray(:, :, 1, 2), patch)
        end

        function testEndKeywordUsesStackSize(testCase)
            [array, stackOrderData] = createPermutedArray();

            testCase.verifyEqual(array(:, :, end), stackOrderData(:, :, end))
            testCase.verifyEqual(array(end, :, :), stackOrderData(end, :, :))
            testCase.verifyEqual(array(:, end-1, 2:end), stackOrderData(:, end-1, 2:end))
        end

        function testEndKeywordOnPropertyValue(testCase)
            array = createPermutedArray();

            testCase.verifyEqual(array.DataSize(end), 3)
            testCase.verifyEqual(array.DataDimensionArrangement(end), 'X')
        end

        function testSizeOfDimensionsBeyondTheStack(testCase)
            array = createPermutedArray();

            testCase.verifyEqual(size(array, 5), 1)
            [numRows, numBeyond] = size(array, [1, 5]);
            testCase.verifyEqual([numRows, numBeyond], [2, 1])
        end

        function testLinearIndexCountsInStackOrder(testCase)
            [array, stackOrderData] = createPermutedArray();

            for linearIndex = [1, 2, 7, 20, numel(stackOrderData)]
                testCase.verifyEqual(array(linearIndex), stackOrderData(linearIndex))
            end
            testCase.verifyEqual(array(end), stackOrderData(end))
        end

        function testLinearIndexEqualToColonCharacterCode(testCase)
            % double(':') is 58, and isequal(58, ':') is true.
            data = reshape(uint16(1:(6*4*5)), [6, 4, 5]);
            array = imagestack.data.MatlabArray(data, DataDimensionArrangement='TYX');
            stackOrderData = permute(data, [2, 3, 1]);

            testCase.verifyEqual(array(double(':')), stackOrderData(double(':')))
        end

        function testColonReturnsElementsInStackOrder(testCase)
            [array, stackOrderData] = createPermutedArray();

            testCase.verifyEqual(array(:), stackOrderData(:))
        end

        function testLinearIndexVectorIsRejected(testCase)
            array = createPermutedArray();

            testCase.verifyError(@() array([1, 5]), ...
                'IMAGESTACK:LinearIndexingNotSupported')
        end

        function testSelectorMatchesConfiguredVariant(testCase)
            activeVariant = string(getpref('imagestack', 'IndexingVariant'));
            expectedSuperclass = "imagestack.data.abstract.ImageStackData" + ...
                upperFirst(activeVariant);

            classInfo = ?imagestack.data.abstract.ImageStackData;
            superclassNames = string({classInfo.SuperclassList.Name});

            testCase.verifyEqual(superclassNames, expectedSuperclass)
        end
    end
end

function [array, stackOrderData] = createPermutedArray()
% Data is stored as T-Y-X with sizes 6, 2 and 3. The stack presents Y-X-T.
data = reshape(uint16(1:(6*2*3)), [6, 2, 3]);
array = imagestack.data.MatlabArray(data, DataDimensionArrangement='TYX');
stackOrderData = permute(data, [2, 3, 1]);
end

function value = upperFirst(value)
value = char(value);
value(1) = upper(value(1));
value = string(value);
end
