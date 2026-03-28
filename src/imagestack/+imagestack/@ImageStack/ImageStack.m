classdef ImageStack < handle
%ImageStack Front-end wrapper for stack-shaped image data.
%
%   ImageStack presents a user-facing view of stack data while delegating
%   storage and indexing details to an ImageStackData backend. The front
%   end is responsible for:
%   - current channel / plane selection
%   - standard versus extended indexing behavior
%   - chunk-oriented reads
%   - simple projection helpers

    properties
        Name char = 'UNNAMED'
        Data
        CurrentChannel = 1
        CurrentPlane = 1
        ChunkLength double = inf
    end

    properties (Dependent)
        MetaData
        DimensionOrder
        DataDimensionOrder
        DataType
        DynamicCacheEnabled
    end

    properties (Dependent, SetAccess = private)
        ImageHeight
        ImageWidth
        NumChannels
        NumPlanes
        NumTimepoints
    end

    methods
        function obj = ImageStack(dataReference, varargin)
            [stackOptions, dataOptions] = obj.parseConstructorInputs(varargin{:});

            obj.Data = obj.initializeData(dataReference, dataOptions{:});
            obj.Name = stackOptions.Name;
            obj.CurrentChannel = stackOptions.CurrentChannel;
            obj.CurrentPlane = stackOptions.CurrentPlane;
        end

        function value = get.MetaData(obj)
            value = obj.Data.MetaData;
        end

        function value = get.DimensionOrder(obj)
            value = obj.Data.StackDimensionArrangement;
        end

        function value = get.DataDimensionOrder(obj)
            value = obj.Data.DataDimensionArrangement;
        end

        function value = get.DataType(obj)
            value = obj.Data.DataType;
        end

        function value = get.DynamicCacheEnabled(obj)
            if obj.isVirtualBackend()
                value = obj.Data.UseDynamicCache;
            else
                value = false;
            end
        end

        function set.DynamicCacheEnabled(obj, newValue)
            tf = obj.normalizeSwitchValue(newValue);

            if ~obj.isVirtualBackend()
                if tf
                    error('IMAGESTACK:DynamicCacheUnavailable', ...
                        'Dynamic cache is only available for virtual backends.')
                end
                return
            end

            obj.Data.setDynamicCacheEnabled(tf)
        end

        function value = get.ImageHeight(obj)
            value = obj.getDimensionLength('Y');
        end

        function value = get.ImageWidth(obj)
            value = obj.getDimensionLength('X');
        end

        function value = get.NumChannels(obj)
            value = obj.getDimensionLength('C');
        end

        function value = get.NumPlanes(obj)
            value = obj.getDimensionLength('Z');
        end

        function value = get.NumTimepoints(obj)
            value = obj.getDimensionLength('T');
        end

        function varargout = size(obj, varargin)
            [varargout{1:nargout}] = size(obj.Data, varargin{:});
        end

        function value = ndims(obj)
            value = ndims(obj.Data);
        end

        function data = getFrameSet(obj, frameInd, mode)
        %getFrameSet Read stack data through the current front-end view.
        %
        %   `standard` mode respects CurrentChannel and CurrentPlane.
        %   `extended` mode exposes the full backend arrangement.
            if nargin < 2 || isempty(frameInd)
                frameInd = ':';
            end
            if nargin < 3 || isempty(mode)
                mode = 'standard';
            end

            if ischar(frameInd) || isstring(frameInd)
                if strcmp(frameInd, 'all')
                    frameInd = ':';
                elseif strcmp(frameInd, 'cache')
                    frameInd = ':';
                end
            end

            subs = obj.buildIndexingSubs(mode);
            frameDim = obj.resolveFrameDimensionNumber(mode);
            subs{frameDim} = frameInd;
            data = obj.Data(subs{:});
        end

        function writeFrameSet(obj, imageArray, frameInd)
        %writeFrameSet Write stack data through the current front-end view.
            if nargin < 3 || isempty(frameInd)
                frameInd = ':';
            end

            if ischar(frameInd) || isstring(frameInd)
                if strcmp(frameInd, 'all')
                    frameInd = ':';
                end
            end

            subs = obj.buildIndexingSubs('standard');
            frameDim = obj.resolveFrameDimensionNumber('standard');
            subs{frameDim} = frameInd;

            obj.validateWriteFrameSetInput(imageArray, subs)
            obj.Data(subs{:}) = imageArray;
        end

        function data = getChunk(obj, chunkIndex, chunkLength, dim)
            if nargin < 3 || isempty(chunkLength)
                chunkLength = obj.ChunkLength;
            end
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end

            [frameIndices, ~] = obj.getChunkedFrameIndices(chunkLength, ...
                chunkIndex, dim);
            data = obj.getFrameSet(frameIndices, 'extended');
        end

        function projectionImage = getProjection(obj, projectionName, frameInd, dim, mode)
            if nargin < 3 || isempty(frameInd)
                frameInd = 'all';
            end
            if nargin < 4 || isempty(dim)
                if contains(obj.DimensionOrder, 'T')
                    dim = 'T';
                elseif contains(obj.DimensionOrder, 'Z')
                    dim = 'Z';
                else
                    dim = obj.DimensionOrder(end);
                end
            end
            if nargin < 5 || isempty(mode)
                mode = 'standard';
            end

            if strcmp(mode, 'extended')
                tmpStack = obj.getFrameSet(frameInd, 'extended');
            else
                tmpStack = obj.getFrameSet(frameInd, 'standard');
            end
            if ischar(dim) || isstring(dim)
                dimMode = mode;
                if ~strcmp(dimMode, 'extended')
                    dimMode = 'standard';
                end
                dim = obj.lookupDimensionNumber(char(dim), dimMode);
            end

            switch lower(projectionName)
                case {'avg', 'mean', 'average'}
                    projectionImage = mean(tmpStack, dim);
                    projectionImage = cast(projectionImage, obj.DataType);
                case {'max', 'maximum'}
                    projectionImage = max(tmpStack, [], dim);
                case {'min', 'minimum'}
                    projectionImage = min(tmpStack, [], dim);
                case {'std', 'standard_deviation'}
                    projectionImage = std(single(tmpStack), 0, dim);
                    projectionImage = cast(projectionImage, 'single');
                otherwise
                    error('IMAGESTACK:UnsupportedProjection', ...
                        'Unsupported projection "%s".', projectionName)
            end

        end

        function chunkLength = chooseChunkLength(obj, dataType, pctMemoryLoad, dim)
        %chooseChunkLength Find a conservative chunk length for processing.
            if nargin < 2 || isempty(dataType)
                dataType = obj.DataType;
            end
            if nargin < 3 || isempty(pctMemoryLoad)
                pctMemoryLoad = 1/8;
            end
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end

            dim = upper(char(dim));
            obj.validateChunkDimension(dim)

            availableMemoryBytes = obj.getAvailableMemoryBytes();
            availableMemoryBytes = max(1, floor(availableMemoryBytes * pctMemoryLoad));

            bytesPerFrame = imagestack.data.abstract.ImageStackData.getImageDataByteSize( ...
                [obj.ImageHeight, obj.ImageWidth], dataType);
            chunkLength = floor(availableMemoryBytes / bytesPerFrame);
            chunkLength = max(1, chunkLength);

            switch dim
                case 'T'
                    chunkLength = floor(chunkLength / max(1, obj.NumChannels * obj.NumPlanes));
                case 'Z'
                    chunkLength = floor(chunkLength / max(1, obj.NumChannels * obj.NumTimepoints));
                case 'C'
                    chunkLength = floor(chunkLength / max(1, obj.NumPlanes * obj.NumTimepoints));
            end

            chunkLength = max(1, chunkLength);
            chunkLength = min(chunkLength, obj.getDimensionLength(dim));
        end

        function chunkSize = getChunkSize(obj, chunkSizeBytes, dim)
            if nargin < 3 || isempty(dim)
                dim = 'T';
            end

            frameSize = [obj.ImageHeight, obj.ImageWidth];
            bytesPerFrame = imagestack.data.abstract.ImageStackData.getImageDataByteSize( ...
                frameSize, obj.DataType);
            n = floor(chunkSizeBytes / bytesPerFrame);

            switch dim
                case 'T'
                    n = max(1, floor(n / max(1, obj.NumChannels * obj.NumPlanes)));
                case 'Z'
                    n = max(1, floor(n / max(1, obj.NumChannels * obj.NumTimepoints)));
                case 'C'
                    n = max(1, floor(n / max(1, obj.NumPlanes * obj.NumTimepoints)));
            end

            chunkSize = size(obj.Data);
            dimNumber = obj.lookupDimensionNumber(dim, 'extended');
            chunkSize(dimNumber) = min(chunkSize(dimNumber), n);
        end

        function [indices, numChunks] = getChunkedFrameIndices(obj, numFramesPerChunk, chunkIndex, dim, firstIdx, lastIdx)
            if nargin < 2 || isempty(numFramesPerChunk) || isequal(numFramesPerChunk, inf)
                numFramesPerChunk = obj.ChunkLength;
            end
            if nargin < 3 || isempty(chunkIndex)
                chunkIndex = [];
            end
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
            if nargin < 5 || isempty(firstIdx)
                firstIdx = 1;
            end
            if nargin < 6 || isempty(lastIdx)
                lastIdx = inf;
            end

            dim = upper(char(dim));
            obj.validateChunkDimension(dim)

            dimLength = obj.getDimensionLength(dim);
            lastIdx = min(dimLength, lastIdx);
            if firstIdx > lastIdx
                error('IMAGESTACK:InvalidInterval', ...
                    'firstIdx must be less than or equal to lastIdx.')
            end

            numSlices = (lastIdx - firstIdx) + 1;
            numFramesPerChunk = min(numFramesPerChunk, numSlices);
            if isempty(numFramesPerChunk) || numFramesPerChunk < 1
                error('IMAGESTACK:InvalidChunkLength', ...
                    'Chunk length must be a positive integer.')
            end

            firstFrames = firstIdx:numFramesPerChunk:lastIdx;
            lastFrames = firstFrames + numFramesPerChunk - 1;
            lastFrames(end) = lastIdx;

            numChunks = numel(firstFrames);
            indices = arrayfun(@(i) firstFrames(i):lastFrames(i), ...
                1:numChunks, 'UniformOutput', false);

            if isempty(chunkIndex)
                return
            end

            if isscalar(chunkIndex)
                indices = indices{chunkIndex};
            else
                indices = indices(chunkIndex);
            end
        end
    end

    methods (Access = private)
        function [stackOptions, dataOptions] = parseConstructorInputs(~, varargin)
            stackOptions = struct('Name', 'UNNAMED', ...
                'CurrentChannel', 1, 'CurrentPlane', 1);
            dataOptions = {};

            if isempty(varargin)
                return
            end

            if mod(numel(varargin), 2) ~= 0
                error('IMAGESTACK:InvalidInput', ...
                    'Name-value inputs must come in pairs.')
            end

            for i = 1:2:numel(varargin)
                name = varargin{i};
                value = varargin{i+1};
                switch string(name)
                    case "Name"
                        stackOptions.Name = value;
                    case "CurrentChannel"
                        stackOptions.CurrentChannel = value;
                    case "CurrentPlane"
                        stackOptions.CurrentPlane = value;
                    otherwise
                        dataOptions(end+1:end+2) = {name, value}; %#ok<AGROW>
                end
            end
        end

        function dimLength = getDimensionLength(obj, dimName)
            dimIndex = obj.lookupDimensionNumber(dimName, 'extended');
            if isempty(dimIndex)
                dimLength = 1;
            else
                dimLength = obj.Data.DataSize(dimIndex);
            end
        end

        function dimNumber = lookupDimensionNumber(obj, dimName, mode)
        %lookupDimensionNumber Resolve a dimension letter to a numeric axis.
            if nargin < 3 || isempty(mode)
                mode = 'standard';
            end

            switch mode
                case 'extended'
                    dimNumber = strfind(obj.Data.DataDimensionArrangement, dimName);
                otherwise
                    dimNumber = strfind(obj.DimensionOrder, dimName);
            end
        end

        function subs = buildIndexingSubs(obj, mode)
        %buildIndexingSubs Build front-end subscripts for a read request.
            if nargin < 2 || isempty(mode)
                mode = 'standard';
            end

            switch mode
                case 'extended'
                    nDims = numel(obj.Data.DataDimensionArrangement);
                otherwise
                    nDims = numel(size(obj.Data));
            end
            subs = repmat({':'}, 1, nDims);

            if strcmp(mode, 'extended')
                return
            end

            dimC = obj.lookupDimensionNumber('C', mode);
            if ~isempty(dimC) && ~isequal(obj.CurrentChannel, ':')
                subs{dimC} = obj.CurrentChannel;
            end

            dimZ = obj.lookupDimensionNumber('Z', mode);
            if ~isempty(dimZ) && ~isequal(obj.CurrentPlane, ':')
                subs{dimZ} = obj.CurrentPlane;
            end
        end

        function frameDim = resolveFrameDimensionNumber(obj, mode)
        %resolveFrameDimensionNumber Choose the stack axis used as frames.
            if nargin < 2 || isempty(mode)
                mode = 'standard';
            end

            switch mode
                case 'extended'
                    if contains(obj.Data.DataDimensionArrangement, 'T')
                        frameDim = obj.lookupDimensionNumber('T', 'extended');
                    elseif contains(obj.Data.DataDimensionArrangement, 'Z')
                        frameDim = obj.lookupDimensionNumber('Z', 'extended');
                    else
                        frameDim = numel(obj.Data.DataDimensionArrangement);
                    end
                otherwise
                    if contains(obj.DimensionOrder, 'T')
                        frameDim = obj.lookupDimensionNumber('T');
                    elseif contains(obj.DimensionOrder, 'Z')
                        frameDim = obj.lookupDimensionNumber('Z');
                    else
                        frameDim = numel(obj.DimensionOrder);
                    end
            end
        end

        function validateWriteFrameSetInput(obj, imageArray, subs)
            expectedSize = size(obj.Data);
            for i = 1:numel(subs)
                if ~(ischar(subs{i}) || isstring(subs{i}))
                    expectedSize(i) = numel(subs{i});
                end
            end

            imageSize = size(imageArray);
            maxLen = max(numel(expectedSize), numel(imageSize));
            expectedSize(end+1:maxLen) = 1;
            imageSize(end+1:maxLen) = 1;

            assert(isequal(expectedSize, imageSize), ...
                'IMAGESTACK:InvalidWriteSize', ...
                'Input data size does not match the requested frame selection.')

            if obj.isVirtualBackend() && ~strcmp(obj.Data.DataType, class(imageArray))
                error('IMAGESTACK:InvalidWriteType', ...
                    'Input data type (%s) must match backend data type (%s).', ...
                    class(imageArray), obj.Data.DataType)
            end
        end

        function tf = isVirtualBackend(obj)
            tf = isa(obj.Data, 'imagestack.data.VirtualArray');
        end

        function tf = normalizeSwitchValue(~, value)
            if isstring(value) || ischar(value)
                switch lower(char(value))
                    case 'on'
                        tf = true;
                    case 'off'
                        tf = false;
                    otherwise
                        error('IMAGESTACK:InvalidSwitchValue', ...
                            'DynamicCacheEnabled must be set to on/off or logical.')
                end
            else
                tf = logical(value);
            end
        end

        function validateChunkDimension(~, dim)
            assert(any(strcmp(dim, {'C', 'Z', 'T'})), ...
                'dim must be ''C'', ''Z'', or ''T''')
        end

        function availableMemoryBytes = getAvailableMemoryBytes(~)
            availableMemoryBytes = [];

            try
                memoryStats = memory;
                if isstruct(memoryStats) && isfield(memoryStats, 'MemAvailableAllArrays')
                    availableMemoryBytes = double(memoryStats.MemAvailableAllArrays);
                end
            catch
            end

            if isempty(availableMemoryBytes) || ~isfinite(availableMemoryBytes) || availableMemoryBytes <= 0
                availableMemoryBytes = 512 * 1024^2;
            end
        end
    end
end
