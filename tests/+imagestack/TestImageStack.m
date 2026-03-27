classdef TestImageStack < matlab.unittest.TestCase

    methods (Test)
        function testConstructImageStackFromArray(testCase)
            data = reshape(uint16(1:60), [5, 4, 3]);
            stack = imagestack.ImageStack(data, Name='ExampleStack');

            testCase.verifyEqual(stack.Name, 'ExampleStack')
            testCase.verifyEqual(size(stack), [5, 4, 3])
            testCase.verifyEqual(stack.DataDimensionOrder, 'YXC')
            testCase.verifyEqual(stack.NumChannels, 3)
        end

        function testGetFrameSetUsesCurrentSelections(testCase)
            data = reshape(1:120, [5, 4, 2, 3]);
            stack = imagestack.ImageStack(data, CurrentChannel=2);

            frame = stack.getFrameSet(1);

            testCase.verifyEqual(size(frame), [5, 4])
            testCase.verifyEqual(frame, data(:, :, 2, 1))
        end
    end
end
