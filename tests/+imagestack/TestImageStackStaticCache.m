classdef TestImageStackStaticCache < matlab.unittest.TestCase
%TestImageStackStaticCache Reads of the static cache through getFrameSet.

    methods (Test)
        function testCacheReadReturnsStoredData(testCase)
            stack = createStack();
            cachedData = zeros(4, 4, 2, 'uint8');
            stack.addToStaticCache(cachedData, 1:2)

            testCase.verifyEqual(stack.getFrameSet('cache'), cachedData)
        end

        function testCacheReadWithoutCacheReturnsAllFrames(testCase)
            stack = createStack();

            testCase.verifyFalse(stack.HasStaticCache)
            testCase.verifyEqual(stack.getFrameSet('cache'), stack.getFrameSet('all'))
        end

        function testGetFrameSetSizeMatchesCacheRead(testCase)
            stack = createStack();
            testCase.verifyEqual(stack.getFrameSetSize('cache'), [4, 4, 3])

            stack.addToStaticCache(zeros(4, 4, 2, 'uint8'), 1:2)

            testCase.verifyEqual(stack.getFrameSetSize('cache'), ...
                size(stack.getFrameSet('cache')))
        end

        function testNewCacheReplacesPreviousCache(testCase)
            stack = createStack();
            stack.addToStaticCache(zeros(4, 4, 2, 'uint8'), 1:2)
            replacement = 7 * ones(4, 4, 1, 'uint8');

            stack.addToStaticCache(replacement, 3)

            testCase.verifyEqual(stack.getFrameSet('cache'), replacement)
        end
    end
end

function stack = createStack()
data = reshape(uint8(1:(4*4*3)), [4, 4, 3]);
stack = imagestack.ImageStack(data, 'DataDimensionArrangement', 'YXT');
end
