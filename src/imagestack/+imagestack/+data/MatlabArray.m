classdef MatlabArray < imagestack.data.abstract.ImageStackData
%MatlabArray ImageStackData implementation for in-memory matlab arrays.

    properties
        DataArray
    end

    methods
        function obj = MatlabArray(dataArray, options)
            arguments
                dataArray
                options.Description = ''
                options.DataDimensionArrangement char = ''
                options.StackDimensionArrangement char = ''
            end

            obj.DataArray = dataArray;
            obj.MetaData = imagestack.metadata.StackMetadata();
            obj.Description = options.Description;

            obj.assignDataSize()
            obj.assignDataType()

            if ~isempty(options.DataDimensionArrangement)
                obj.DataDimensionArrangement = options.DataDimensionArrangement;
            end
            obj.setDefaultDataDimensionArrangement()

            if ~isempty(options.StackDimensionArrangement)
                obj.StackDimensionArrangement = options.StackDimensionArrangement;
            end
            obj.setDefaultStackDimensionArrangement()

            obj.MetaData.Size = obj.DataSize;
            obj.MetaData.Class = obj.DataType;
            obj.MetaData.DimensionArrangement = obj.DataDimensionArrangement;
            obj.MetaData.SizeX = obj.getDimLength('X');
            obj.MetaData.SizeY = obj.getDimLength('Y');
            obj.MetaData.SizeC = obj.getDimLength('C');
            obj.MetaData.SizeZ = obj.getDimLength('Z');
            obj.MetaData.SizeT = obj.getDimLength('T');
        end

        function insertImageData(obj, imageData, insertInd)
            stackSize = size(obj.DataArray);
            nDim = max([3, numel(stackSize)]);
            subs = arrayfun(@(l) 1:l, stackSize, 'UniformOutput', false);

            msg = ['Image cannot be inserted into this stack because ', ...
                'the sizes do not match.'];
            assert(isequal(stackSize(1:nDim-1), size(imageData)), msg)

            if insertInd == 1
                obj.DataArray = cat(nDim, imageData, obj.DataArray(subs{:}));
            else
                [subsPre, subsPost] = deal(subs);
                subsPre{nDim} = 1:insertInd(1)-1;
                subsPost{nDim} = insertInd(1):subsPost{nDim}(end);

                obj.DataArray = cat(nDim, obj.DataArray(subsPre{:}), ...
                    imageData, obj.DataArray(subsPost{:}));
            end

            obj.assignDataSize()

            if numel(stackSize) ~= ndims(obj.DataArray) ...
                    && strcmp(obj.DataDimensionArrangement, 'YX')
                obj.DataDimensionArrangement = 'YXT';
            end
        end

        function removeImageData(~, ~)
            error('IMAGESTACK:NotImplemented', ...
                'removeImageData is not implemented yet.')
        end
    end

    methods (Access = protected)
        function assignDataSize(obj)
            obj.DataSize = size(obj.DataArray);
        end

        function assignDataType(obj)
            obj.DataType = class(obj.DataArray);
        end

        function data = getData(obj, subs)
            if all(cellfun(@(s) ischar(s) && isequal(s, ':'), subs))
                data = obj.DataArray;
            else
                data = obj.DataArray(subs{:});
            end
        end

        function setData(obj, subs, data)
            if all(cellfun(@(s) ischar(s) && isequal(s, ':'), subs))
                obj.DataArray = data;
            else
                obj.DataArray(subs{:}) = data;
            end
        end

        function data = getLinearizedData(obj)
            data = obj.DataArray(:);
        end
    end

    methods
        function varargout = max(obj, varargin)
            if nargout == 0
                max(obj.DataArray, varargin{:})
            else
                varargout = cell(1, nargout);
                [varargout{:}] = max(obj.DataArray, varargin{:});
            end
        end
    end
end
