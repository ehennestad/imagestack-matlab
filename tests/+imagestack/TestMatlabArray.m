classdef TestMatlabArray < matlab.unittest.TestCase

    methods (Test)
        function testConstructMatlabArray(testCase)
            data = zeros(8, 6, 4, 'uint16');
            array = imagestack.data.MatlabArray(data, Description="smoke");

            testCase.verifyEqual(size(array), [8, 6, 4])
            testCase.verifyEqual(string(array.Description), "smoke")
            testCase.verifyEqual(array.DataDimensionArrangement, 'YXT')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXT')
        end

        function testCustomDimensionArrangement(testCase)
            data = rand(5, 4, 3);
            array = imagestack.data.MatlabArray(data, ...
                DataDimensionArrangement='YXC');

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXC')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXC')
        end
    end
end
