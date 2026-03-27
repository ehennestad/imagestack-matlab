classdef ImageStackDataModern < imagestack.data.abstract.ImageStackDataCore ...
        & matlab.mixin.indexing.RedefinesParen
%ImageStackDataModern ImageStackData variant backed by RedefinesParen.

    methods (Static)
        function obj = empty(varargin) %#ok<INUSD,STOUT>
            error('IMAGESTACK:EmptyNotSupported', ...
                'Empty ImageStackData arrays are not supported.')
        end
    end

    methods
        function out = cat(varargin) %#ok<STOUT>
            error('IMAGESTACK:ConcatenationNotSupported', ...
                'Concatenation is not supported for ImageStackData objects.')
        end

        function ndim = ndims(obj)
            ndim = ndims@imagestack.data.abstract.ImageStackDataCore(obj);
        end
    end

    methods (Access = protected)
        function varargout = parenReference(obj, indexOp)
            value = obj.referenceStackData(indexOp(1).Indices);

            if numel(indexOp) == 1
                varargout{1} = value;
            else
                [varargout{1:nargout}] = obj.forwardReference(value, indexOp(2:end));
            end
        end

        function obj = parenAssign(obj, indexOp, varargin)
            if numel(indexOp) == 1
                obj.assignStackData(indexOp(1).Indices, varargin{1})
                return
            end

            value = obj.referenceStackData(indexOp(1).Indices);
            value.(indexOp(2:end)) = varargin{:};
            obj.assignStackData(indexOp(1).Indices, value)
        end

        function obj = parenDelete(obj, ~)
            %#ok<INUSD>
            error('IMAGESTACK:DeleteNotSupported', ...
                'Deleting ImageStackData elements is not supported.')
        end

        function n = parenListLength(obj, indexOp, indexContext)
            if numel(indexOp) == 1
                n = 1;
                return
            end

            value = obj.referenceStackData(indexOp(1).Indices);
            n = obj.getForwardedListLength(value, indexOp(2:end), indexContext);
        end
    end
end
