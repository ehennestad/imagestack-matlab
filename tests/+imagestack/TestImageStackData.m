classdef TestImageStackData < matlab.unittest.TestCase

    methods (Test)
        function testDefaultDimensionArrangementFor2D(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YX')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YX')
            testCase.verifyEqual(size(array), [5, 4])
        end

        function testDefaultDimensionArrangementFor3DRgb(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 3));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXC')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXC')
            testCase.verifyEqual(array.exposedGetFrameIndexingDimension(), 3)
        end

        function testDefaultDimensionArrangementFor3DTime(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 4));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXT')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXT')
            testCase.verifyEqual(array.exposedGetFrameIndexingDimension(), 3)
        end

        function testDefaultDimensionArrangementFor4D(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 7));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXCT')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXCT')
            testCase.verifyEqual(array.exposedGetFrameIndexingDimension(), 4)
        end

        function testDefaultDimensionArrangementFor5D(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 3, 7));

            testCase.verifyEqual(array.DataDimensionArrangement, 'YXCZT')
            testCase.verifyEqual(array.StackDimensionArrangement, 'YXCZT')
            testCase.verifyEqual(array.exposedGetFrameIndexingDimension(), 5)
        end

        function testCustomStackArrangementUpdatesReportedSize(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 7), ...
                DataDimensionArrangement='YXCT', ...
                StackDimensionArrangement='YXTC');

            testCase.verifyEqual(size(array), [5, 4, 7, 2])
            testCase.verifyEqual(array.exposedGetDimLength('C'), 2)
            testCase.verifyEqual(array.exposedGetDimLength('T'), 7)
        end

        function testGetDataDimensionNumberAndMissingDimension(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 4));

            testCase.verifyEqual(array.exposedGetDataDimensionNumber('T'), 3)
            testCase.verifyEqual(array.exposedGetDimLength('Z'), 1)
        end

        function testRearrangeSubsForCustomStackArrangement(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 7), ...
                DataDimensionArrangement='YXCT', ...
                StackDimensionArrangement='YXTC');

            subs = {':', ':', 6, 2};
            rearranged = array.exposedRearrangeSubs(subs);

            testCase.verifyEqual(rearranged, {':', ':', 2, 6})
        end

        function testChangingDataArrangementPreservesStackOrderWhenPossible(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 7), ...
                DataDimensionArrangement='YXCT', ...
                StackDimensionArrangement='YXTC');

            array.DataDimensionArrangement = 'YXZT';

            testCase.verifyEqual(array.StackDimensionArrangement, 'YXTZ')
            testCase.verifyEqual(size(array), [5, 4, 7, 2])
        end

        function testChangingDataArrangementToDefaultUsesDefaultOrder(testCase)
            array = imagestack.TestableMatlabArray(zeros(5, 4, 2, 3, 7), ...
                DataDimensionArrangement='YXCZT', ...
                StackDimensionArrangement='YXTZC');

            array.DataDimensionArrangement = 'YXCZT';

            testCase.verifyEqual(array.StackDimensionArrangement, 'YXTZC')
        end

        function testValidateDimensionArrangementErrorsOnInvalidLetter(testCase)
            testCase.verifyError(@() imagestack.TestableMatlabArray( ...
                zeros(5, 4, 4), DataDimensionArrangement='YXA'), ...
                'Nansen:ImageStackData:WrongDimensionLetter')
        end

        function testGetImageDataByteSize(testCase)
            testCase.verifyEqual( ...
                imagestack.data.abstract.ImageStackData.getImageDataByteSize([5, 4, 3], 'uint16'), ...
                5 * 4 * 3 * 2)
            testCase.verifyEqual( ...
                imagestack.data.abstract.ImageStackData.getImageDataByteSize([5, 4], 'single'), ...
                5 * 4 * 4)
        end
    end
end
