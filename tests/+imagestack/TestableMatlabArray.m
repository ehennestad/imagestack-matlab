classdef TestableMatlabArray < imagestack.data.MatlabArray

    methods
        function obj = TestableMatlabArray(dataArray, varargin)
            obj@imagestack.data.MatlabArray(dataArray, varargin{:})
        end

        function value = exposedGetDimLength(obj, dimName)
            value = obj.getDimLength(dimName);
        end

        function value = exposedGetDataDimensionNumber(obj, dimName)
            value = obj.getDataDimensionNumber(dimName);
        end

        function value = exposedGetFrameIndexingDimension(obj)
            value = obj.getFrameIndexingDimension();
        end

        function value = exposedRearrangeSubs(obj, subs)
            value = obj.rearrangeSubs(subs);
        end
    end
end
