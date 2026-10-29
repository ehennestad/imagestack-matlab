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

        function testSelectionEqualToColonCharacterCode(testCase)
            % double(':') is 58, and isequal(58, ':') is true.
            numPlanes = 60;
            data = reshape(uint16(1:(2*2*numPlanes*3)), [2, 2, numPlanes, 3]);
            planeStack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXZT');
            channelStack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXCT');

            planeStack.CurrentPlane = double(':');
            channelStack.CurrentChannel = double(':');

            testCase.verifyEqual(planeStack.getFrameSet(1), data(:, :, 58, 1))
            testCase.verifyEqual(channelStack.getFrameSet(1), data(:, :, 58, 1))
        end

        function testColonSelectsAllPlanes(testCase)
            data = reshape(uint16(1:(2*2*4*3)), [2, 2, 4, 3]);
            stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXZT');

            stack.CurrentPlane = ':';
            testCase.verifyEqual(stack.getFrameSet(2), data(:, :, :, 2))

            stack.CurrentPlane = ":";
            testCase.verifyEqual(stack.getFrameSet(2), data(:, :, :, 2))
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
