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

function value = upperFirst(value)
value = char(value);
value(1) = upper(value(1));
value = string(value);
end
