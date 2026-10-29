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

            obj.updateMetadata()
        end

        function insertImageData(obj, imageData, insertInd)
        %insertImageData Insert image data along the time dimension.
        %
        %   imageData is in data dimension order and must match the array
        %   in every dimension except T. insertInd is the timepoint that
        %   the first inserted image gets, from 1 to the number of
        %   timepoints plus 1. An array without a T dimension, such as a
        %   single image, becomes a time series with T as the last
        %   dimension.
            hasTimeDimension = contains(obj.DataDimensionArrangement, 'T');
            if hasTimeDimension
                timeDim = obj.getDataDimensionNumber('T');
            else
                timeDim = numel(obj.DataDimensionArrangement) + 1;
            end

            % Compare sizes over the same number of dimensions, so that
            % trailing singleton dimensions count as length 1.
            numDims = max(timeDim, numel(obj.DataDimensionArrangement));
            arraySize = size(obj.DataArray, 1:numDims);
            imageSize = size(imageData, 1:numDims);
            otherDims = setdiff(1:numDims, timeDim);

            if ~isequal(arraySize(otherDims), imageSize(otherDims)) ...
                    || ndims(imageData) > numDims
                error('IMAGESTACK:InsertSizeMismatch', ...
                    ['Image data of size %s cannot be inserted into data of size %s ', ...
                    '(%s). All dimensions except T must match.'], ...
                    mat2str(size(imageData)), mat2str(arraySize), ...
                    obj.DataDimensionArrangement)
            end

            numTimepoints = arraySize(timeDim);
            isValidIndex = isnumeric(insertInd) && isscalar(insertInd) ...
                && insertInd == round(insertInd) ...
                && insertInd >= 1 && insertInd <= numTimepoints + 1;
            if ~isValidIndex
                error('IMAGESTACK:InsertIndexOutOfRange', ...
                    'insertInd must be an integer from 1 to %d.', numTimepoints + 1)
            end

            subsBefore = repmat({':'}, 1, numDims);
            subsBefore{timeDim} = 1:(insertInd-1);
            subsAfter = repmat({':'}, 1, numDims);
            subsAfter{timeDim} = insertInd:numTimepoints;

            obj.DataArray = cat(timeDim, obj.DataArray(subsBefore{:}), ...
                imageData, obj.DataArray(subsAfter{:}));

            % The arrangement gains its T before the size is assigned, so
            % that it describes every dimension of the new size.
            if ~hasTimeDimension
                obj.DataDimensionArrangement = [obj.DataDimensionArrangement, 'T'];
            end
            obj.assignDataSize()
            obj.updateMetadata()
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

        function updateMetadata(obj)
        %updateMetadata Copy the current size, type and arrangement to MetaData.
            obj.MetaData.Size = obj.DataSize;
            obj.MetaData.Class = obj.DataType;
            obj.MetaData.DimensionArrangement = obj.DataDimensionArrangement;
            obj.MetaData.SizeX = obj.getDimLength('X');
            obj.MetaData.SizeY = obj.getDimLength('Y');
            obj.MetaData.SizeC = obj.getDimLength('C');
            obj.MetaData.SizeZ = obj.getDimLength('Z');
            obj.MetaData.SizeT = obj.getDimLength('T');
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
