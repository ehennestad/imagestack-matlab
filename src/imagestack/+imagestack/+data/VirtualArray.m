classdef (Abstract) VirtualArray < imagestack.data.abstract.ImageStackData
%VirtualArray Base class for file-backed imagestack data.

    properties (Abstract, Constant, Hidden)
        FILE_PERMISSION char
    end

    properties
        FilePath char = ''
        UseDynamicCache logical = false
        DynamicCacheSize (1,1) double {mustBePositive, mustBeInteger} = 1000
        IsTransient logical = false
    end

    properties (Access = protected)
        DynamicFrameCache imagestack.utility.FrameCache = imagestack.utility.FrameCache.empty
    end

    properties (Dependent)
        HasCachedData
    end

    methods (Abstract, Access = protected)
        getFileInfo(obj)
        createMemoryMap(obj)
    end

    methods (Abstract)
        data = readFrames(obj, frameIndex)
        writeFrames(obj, data, frameIndex)
    end

    methods
        function obj = VirtualArray(filePath, varargin)
            if isempty(filePath)
                return
            end

            [creationArgs, optionArgs] = obj.parseConstructorInputs(varargin{:});
            obj.applyOptions(optionArgs)

            if iscell(filePath)
                fileReference = filePath{1};
            else
                fileReference = filePath;
            end

            if ~isfile(fileReference) && ~isempty(creationArgs.DataSize)
                obj.createFile(fileReference, creationArgs.DataSize, ...
                    creationArgs.DataType)
            end

            obj.assignFilePath(filePath);
            obj.initializeMetaData()
            obj.getFileInfo()

            assert(~isempty(obj.DataSize), ...
                'DataSize should be set in getFileInfo or provided on creation.')
            assert(~isempty(obj.DataType), ...
                'DataType should be set in getFileInfo or provided on creation.')

            obj.setDefaultDataDimensionArrangement()
            obj.setDefaultStackDimensionArrangement()
            obj.createMemoryMap()
            obj.updateMetadata()

            if obj.UseDynamicCache
                obj.initializeDynamicFrameCache()
            end
        end

        function delete(obj)
            obj.writeMetadata()
            if obj.IsTransient && ~isempty(obj.FilePath) && isfile(obj.FilePath)
                obj.MetaData.deleteFile()
                delete(obj.FilePath)
            end
        end

        function tf = get.HasCachedData(obj)
            tf = ~isempty(obj.DynamicFrameCache);
        end

        function data = readData(obj, subs)
            if numel(subs) < numel(obj.DataSize)
                subs{end+1:numel(obj.DataSize)} = {1};
            end

            dim = obj.getFrameIndexingDimension();
            frameInd = subs{dim};
            if ischar(frameInd) && strcmp(frameInd, ':')
                frameInd = 1:obj.getDimLength(obj.DataDimensionArrangement(dim));
            end

            data = obj.readFrames(frameInd);
            subs{dim} = ':';
            data = data(subs{:});
        end

        function writeData(obj, subs, data)
            obj.validateFrameSize(data)
            dim = obj.getFrameIndexingDimension();
            frameInd = subs{dim};
            obj.writeFrames(data, frameInd);
        end

        function readMetadata(obj)
            obj.MetaData.readFromFile()
        end

        function writeMetadata(obj)
            if strcmp(obj.FILE_PERMISSION, 'write') && ~obj.IsTransient
                obj.MetaData.writeToFile()
            end
        end
    end

    methods (Access = protected)
        function onDataSizeChanged(obj)
            onDataSizeChanged@imagestack.data.abstract.ImageStackData(obj)
            if obj.UseDynamicCache
                obj.initializeDynamicFrameCache()
            end
        end

        function validateFrameSize(obj, data)
            dimX = obj.getDataDimensionNumber('X');
            dimY = obj.getDataDimensionNumber('Y');

            assert(size(data, dimX) == obj.DataSize(dimX), ...
                'Width of image data to write must match the image width.')
            assert(size(data, dimY) == obj.DataSize(dimY), ...
                'Height of image data to write must match the image height.')
        end

        function assignFilePath(obj, filePath)
            obj.FilePath = char(filePath);
        end

        function initializeMetaData(obj)
            if strcmp(obj.FILE_PERMISSION, 'write')
                obj.MetaData = imagestack.metadata.StackMetadata(obj.FilePath);
            else
                obj.MetaData = imagestack.metadata.StackMetadata();
            end
        end

        function updateMetadata(obj)
            if isempty(obj.MetaData.Size)
                obj.MetaData.Size = obj.DataSize;
            end
            if isempty(obj.MetaData.Class)
                obj.MetaData.Class = obj.DataType;
            end
            obj.MetaData.DimensionArrangement = obj.DataDimensionArrangement;
            obj.MetaData.SizeX = obj.getDimLength('X');
            obj.MetaData.SizeY = obj.getDimLength('Y');
            obj.MetaData.SizeC = obj.getDimLength('C');
            obj.MetaData.SizeZ = obj.getDimLength('Z');
            obj.MetaData.SizeT = obj.getDimLength('T');
            obj.writeMetadata()
        end

        function data = getData(obj, subs)
            if obj.HasCachedData
                data = obj.getDataUsingCache(subs);
            else
                data = obj.readData(subs);
            end
        end

        function setData(obj, subs, data)
            if ~strcmp(obj.FILE_PERMISSION, 'write')
                error('IMAGESTACK:ReadOnly', ...
                    'No write permission for %s.', class(obj))
            end
            obj.writeData(subs, data);
        end

        function data = getLinearizedData(~)
            error('IMAGESTACK:NotImplemented', ...
                'Linear indexing is not implemented for virtual data.')
        end

        function subs = frameind2subs(obj, frameInd)
            numDims = max(3, ndims(obj));
            subs = repmat({':'}, 1, numDims);
            subs{obj.getFrameIndexingDimension()} = frameInd;
        end
    end

    methods (Access = private)
        function [creationArgs, optionArgs] = parseConstructorInputs(~, varargin)
            creationArgs = struct('DataSize', [], 'DataType', '');
            optionArgs = struct('UseDynamicCache', false, ...
                'DynamicCacheSize', 1000, 'IsTransient', false, ...
                'DataDimensionArrangement', '', ...
                'StackDimensionArrangement', '');

            if numel(varargin) >= 2 && isnumeric(varargin{1}) ...
                    && (ischar(varargin{2}) || isstring(varargin{2}))
                creationArgs.DataSize = varargin{1};
                creationArgs.DataType = char(varargin{2});
                varargin = varargin(3:end);
            end

            if mod(numel(varargin), 2) ~= 0
                error('IMAGESTACK:InvalidInput', ...
                    'Name-value inputs must come in pairs.')
            end

            for i = 1:2:numel(varargin)
                optionArgs.(char(varargin{i})) = varargin{i+1};
            end
        end

        function applyOptions(obj, optionArgs)
            fieldNames = fieldnames(optionArgs);
            for i = 1:numel(fieldNames)
                fieldName = fieldNames{i};
                value = optionArgs.(fieldName);
                if isprop(obj, fieldName)
                    obj.(fieldName) = value;
                elseif isprop(obj, 'DataDimensionArrangement') ...
                        && strcmp(fieldName, 'DataDimensionArrangement') ...
                        && ~isempty(value)
                    obj.DataDimensionArrangement = value;
                elseif isprop(obj, 'StackDimensionArrangement') ...
                        && strcmp(fieldName, 'StackDimensionArrangement') ...
                        && ~isempty(value)
                    obj.StackDimensionArrangement = value;
                end
            end
        end

        function initializeDynamicFrameCache(obj)
            if isempty(obj.DataType) || isempty(obj.DataSize)
                return
            end
            obj.DynamicFrameCache = imagestack.utility.FrameCache(...
                obj.DataSize, obj.DataType, obj.DynamicCacheSize, ...
                'LeadingDimension', obj.getFrameIndexingDimension());
        end

        function data = getDataUsingCache(obj, subs)
            frameDim = obj.getFrameIndexingDimension();
            frameIndices = subs{frameDim};
            if ischar(frameIndices) && strcmp(frameIndices, ':')
                frameIndices = 1:obj.DataSize(frameDim);
            end

            [cachedData, hitIndices, missIndices] = ...
                obj.DynamicFrameCache.fetchData(frameIndices);

            if isempty(missIndices)
                cacheSubs = subs;
                cacheSubs{frameDim} = ':';
                data = cachedData(cacheSubs{:});
                return
            end

            readSubs = repmat({':'}, 1, numel(obj.DataSize));
            readSubs{frameDim} = missIndices;
            uncachedData = obj.readData(readSubs);
            obj.DynamicFrameCache.submitData(uncachedData, missIndices);

            if isempty(hitIndices)
                localSubs = subs;
                [~, localFrameIndices] = ismember(frameIndices, missIndices);
                localSubs{frameDim} = localFrameIndices;
                data = uncachedData(localSubs{:});
                return
            end

            combinedData = cat(frameDim, cachedData, uncachedData);
            combinedIndices = [hitIndices, missIndices];
            [~, order] = ismember(frameIndices, combinedIndices);
            finalSubs = subs;
            finalSubs{frameDim} = order;
            data = combinedData(finalSubs{:});
        end
    end

    methods (Static)
        function createFile(~, ~, ~)
            error('IMAGESTACK:NotImplemented', ...
                'This virtual adapter cannot create new files.')
        end
    end
end
