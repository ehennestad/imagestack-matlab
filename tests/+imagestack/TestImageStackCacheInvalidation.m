classdef TestImageStackCacheInvalidation < matlab.unittest.TestCase
%TestImageStackCacheInvalidation Derived caches follow changes to Data.

    methods (Test)
        function testReplacingDataClearsProjectionAndLimits(testCase)
            stack = createStack(1);
            stack.getFullProjection('max');
            stack.getDataIntensityLimits();

            stack.Data = createBackend(200);

            testCase.verifyEqual(stack.getFullProjection('max'), 200 * ones(4, 4, 'uint8'))
            testCase.verifyEqual(stack.getDataIntensityLimits(), [200, 200])
        end

        function testIndexedWriteThroughDataClearsProjection(testCase)
            stack = createStack(1);
            stack.getFullProjection('max');

            stack.Data(:, :, 1) = 200 * ones(4, 4, 'uint8');

            testCase.verifyEqual(stack.getFullProjection('max'), 200 * ones(4, 4, 'uint8'))
        end

        function testReplacingDataClearsStaticCache(testCase)
            stack = createStack(1);
            stack.addToStaticCache(stack.getFrameSet(1:2), 1:2)
            testCase.assertTrue(stack.HasStaticCache)

            stack.Data = createBackend(200);

            testCase.verifyFalse(stack.HasStaticCache)
        end

        function testWriteFrameSetClearsStaticCache(testCase)
            stack = createStack(1);
            stack.addToStaticCache(stack.getFrameSet(1:2), 1:2)

            stack.writeFrameSet(200 * ones(4, 4, 'uint8'), 1)

            testCase.verifyFalse(stack.HasStaticCache)
        end

        function testDataRejectsValueThatIsNotABackend(testCase)
            stack = createStack(1);

            testCase.verifyError(@() assignData(stack, ones(4, 4, 3)), ...
                'IMAGESTACK:InvalidData')
        end
    end
end

function stack = createStack(fillValue)
stack = imagestack.ImageStack(createBackend(fillValue));
end

function backend = createBackend(fillValue)
data = fillValue * ones(4, 4, 3, 'uint8');
backend = imagestack.data.MatlabArray(data, DataDimensionArrangement='YXT');
end

function assignData(stack, value)
stack.Data = value;
end
