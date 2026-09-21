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
        ColorModel char = 'Grayscale'
        CustomColorModel = []
        DataIntensityLimits = []
    end

    properties (Dependent)
        MetaData
        DimensionOrder
        DataDimensionOrder
        DataType
        DynamicCacheEnabled
        IsVirtual
        HasStaticCache
    end

    properties (Dependent, SetAccess = private)
        ImageHeight
        ImageWidth
        NumChannels
        NumPlanes
        NumTimepoints
        FrameSize
        NumFrames
        DataTypeIntensityLimits
    end

    properties (Access = private)
        ProjectionCache struct = struct()
        StaticCacheData = []
        StaticCacheFrameIndices = []
    end

    methods
        function obj = ImageStack(dataReference, varargin)
            [stackOptions, dataOptions] = obj.parseConstructorInputs(varargin{:});

            obj.Data = obj.initializeData(dataReference, dataOptions{:});
            obj.Name = stackOptions.Name;
            obj.CurrentChannel = stackOptions.CurrentChannel;
            obj.CurrentPlane = stackOptions.CurrentPlane;
        end

        function set.Data(obj, newValue)
            if ~isa(newValue, 'imagestack.data.abstract.ImageStackData')
                error('IMAGESTACK:InvalidData', ...
                    ['Data must be an ImageStackData object, for example ', ...
                    'imagestack.data.MatlabArray. Got a value of class %s.'], ...
                    class(newValue))
            end
            obj.Data = newValue;

            % Projections, intensity limits and the static cache describe
            % the previous data. MATLAB assigns the backend back to this
            % property after an indexed write such as
            % stack.Data(:, :, 1) = image, so those writes clear them too.
            % A write through a separate reference to the backend handle
            % cannot be detected here.
            obj.clearDerivedCaches()
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

        function value = get.IsVirtual(obj)
            value = obj.isVirtualBackend();
        end

        function value = get.HasStaticCache(obj)
            value = ~isempty(obj.StaticCacheData);
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

        function value = get.FrameSize(obj)
            value = [obj.ImageHeight, obj.ImageWidth];
        end

        function value = get.NumFrames(obj)
            % Kept for NANSEN compatibility: selected channels times
            % selected planes times timepoints. Prefer NumChannels,
            % NumPlanes and NumTimepoints, which are defined per axis.
            value = obj.getSelectionLength(obj.CurrentChannel, 'C') * ...
                obj.getSelectionLength(obj.CurrentPlane, 'Z') * ...
                obj.NumTimepoints;
        end

        function value = get.DataTypeIntensityLimits(obj)
            value = imagestack.data.abstract.ImageStackData.getImageIntensityLimits( ...
                obj.DataType);
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
        %   frameInd selects timepoints. A stack without a T dimension is
        %   indexed along planes instead, and a stack without T and Z
        %   along channels.
        %
        %   `standard` mode respects CurrentChannel and CurrentPlane.
        %   `extended` mode returns all channels and planes.
        %   Both modes return data in stack dimension order.
        %
        %   frameInd can also be 'all', or 'cache' to return the data stored
        %   with addToStaticCache. Cached data is returned as stored, so
        %   mode, CurrentChannel and CurrentPlane do not apply to it. With
        %   nothing cached, 'cache' reads all frames.
            if nargin < 2 || isempty(frameInd)
                frameInd = ':';
            end
            if nargin < 3 || isempty(mode)
                mode = 'standard';
            end

            useStaticCache = false;
            if ischar(frameInd) || isstring(frameInd)
                if strcmp(frameInd, 'all')
                    frameInd = ':';
                elseif strcmp(frameInd, 'cache')
                    useStaticCache = obj.HasStaticCache;
                    frameInd = ':';
                end
            end

            if ~useStaticCache
                subs = obj.buildAccessSubs(frameInd, mode);
                data = obj.Data(subs{:});
            else
                data = obj.StaticCacheData;
            end
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

            subs = obj.buildAccessSubs(frameInd, 'standard');

            obj.validateWriteFrameSetInput(imageArray, subs)
            obj.Data(subs{:}) = imageArray;
            obj.clearDerivedCaches()
        end

        function data = getChunk(obj, chunkIndex, chunkLength, dim)
            if nargin < 3 || isempty(chunkLength)
                chunkLength = obj.ChunkLength;
            end
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end

            dim = upper(char(dim));
            [frameIndices, ~] = obj.getChunkedFrameIndices(chunkLength, ...
                chunkIndex, dim);

            % Index the requested axis directly. getFrameSet always indexes
            % the access axis, which differs from dim when chunking along C,
            % or along Z in a stack that also has T. A stack without the
            % requested axis is a single chunk.
            subs = obj.buildIndexingSubs('extended');
            axisNumber = obj.getStackAxisNumber(dim);
            if ~isempty(axisNumber)
                subs{axisNumber} = frameIndices;
            end
            data = obj.Data(subs{:});
        end

        function projectionImage = getProjection(obj, projectionName, frameInd, dim, mode)
            if nargin < 3 || isempty(frameInd)
                frameInd = 'all';
            end
            if nargin < 4 || isempty(dim)
                dim = obj.getAccessAxisName();
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
                dimName = upper(char(dim));
                dim = obj.getStackAxisNumber(dimName);
                if isempty(dim)
                    error('IMAGESTACK:UnknownDimension', ...
                        'Cannot project along dimension "%s". The stack dimensions are %s.', ...
                        dimName, obj.DimensionOrder)
                end
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

        function dataSize = getFrameSetSize(obj, frameInd, mode)
        %getFrameSetSize Return the size of a requested frame set.
            if nargin < 2 || isempty(frameInd)
                frameInd = ':';
            end
            if nargin < 3 || isempty(mode)
                mode = 'standard';
            end

            useStaticCache = false;
            if ischar(frameInd) || isstring(frameInd)
                if strcmp(frameInd, 'all')
                    frameInd = ':';
                elseif strcmp(frameInd, 'cache')
                    useStaticCache = obj.HasStaticCache;
                    frameInd = ':';
                end
            end

            if ~useStaticCache
                subs = obj.buildAccessSubs(frameInd, mode);
                dataSize = obj.getIndexedDataSize(size(obj.Data), subs);
            else
                dataSize = size(obj.StaticCacheData);
            end
        end

        function projectionImage = getFullProjection(obj, projectionName)
        %getFullProjection Return a cached projection for the current view.
            cacheKey = obj.getProjectionCacheKey(projectionName);
            if isfield(obj.ProjectionCache, cacheKey)
                projectionImage = obj.ProjectionCache.(cacheKey);
                return
            end

            projectionImage = obj.getProjection(projectionName, 'all', [], 'standard');
            obj.ProjectionCache.(cacheKey) = projectionImage;
        end

        function frameIndices = getMovingWindowFrameIndices(obj, frameNum, windowLength, dim)
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end

            dim = upper(char(dim));
            obj.validateChunkDimension(dim)
            numFrames = obj.getDimensionLength(dim);

            % The window holds exactly windowLength indices, or every index
            % when the dimension is shorter. An even window cannot be
            % centered on frameNum, so it takes the extra index after it.
            % Near either end the window is shifted inward, not shortened.
            numIndices = min(windowLength, numFrames);
            numBefore = floor((numIndices-1)/2);
            firstIndex = frameNum - numBefore;
            firstIndex = min(max(firstIndex, 1), numFrames-numIndices+1);
            frameIndices = firstIndex:(firstIndex+numIndices-1);
        end

        function dimNumber = getDimensionNumber(obj, dimName)
            dimNumber = obj.getStackAxisNumber(upper(char(dimName)));
        end

        function limits = getDataIntensityLimits(obj)
            if ~isempty(obj.DataIntensityLimits)
                limits = obj.DataIntensityLimits;
                return
            end

            if isprop(obj.MetaData, 'DataIntensityLimits') ...
                    && ~isempty(obj.MetaData.DataIntensityLimits)
                limits = obj.MetaData.DataIntensityLimits;
            else
                data = obj.getFullImage();
                limits = double([min(data(:)), max(data(:))]);
                if any(~isfinite(limits)) || isempty(limits)
                    limits = double(obj.DataTypeIntensityLimits);
                end
            end

            obj.DataIntensityLimits = limits;
        end

        function sampleRate = getSampleRate(obj)
            sampleRate = obj.MetaData.SampleRate;
        end

        function data = getFullImage(obj)
            data = obj.getFrameSet('all', 'extended');
        end

        function addToStaticCache(obj, imData, frameIndices)
        %addToStaticCache Store image data for getFrameSet(obj, 'cache').
        %
        %   The cache holds one array and a new call replaces it. It is
        %   cleared when Data is replaced or written to.
            if nargin < 3
                frameIndices = [];
            end

            obj.StaticCacheData = imData;
            obj.StaticCacheFrameIndices = frameIndices;
            obj.clearProjectionCache()
        end

        function byteSize = getCacheByteSize(obj)
            byteSize = 0;

            if obj.HasStaticCache
                byteSize = byteSize + imagestack.data.abstract.ImageStackData.getImageDataByteSize( ...
                    size(obj.StaticCacheData), class(obj.StaticCacheData));
            end

            if obj.IsVirtual && obj.Data.UseDynamicCache
                bytesPerFrame = imagestack.data.abstract.ImageStackData.getImageDataByteSize( ...
                    obj.FrameSize, obj.DataType);
                byteSize = byteSize + bytesPerFrame * obj.Data.DynamicCacheSize;
            end
        end

        function insertImage(obj, imageData, insertInd)
        %insertImage Insert image data as new timepoints of an in-memory stack.
        %
        %   imageData must match the stack in every dimension except T.
        %   insertInd is the timepoint the first inserted image gets and
        %   defaults to the end of the stack. A stack without a T dimension,
        %   such as a single image, becomes a time series.
            if nargin < 3 || isempty(insertInd)
                insertInd = obj.NumTimepoints + 1;
            end

            if obj.IsVirtual
                error('IMAGESTACK:InsertNotSupported', ...
                    'insertImage is only implemented for in-memory stacks.')
            end

            if obj.NumPlanes > 1
                error('IMAGESTACK:InsertNotSupported', ...
                    'insertImage does not yet support multi-plane stacks.')
            end

            % imageData arrives in stack dimension order and the backend
            % stores data dimension order. They must agree, otherwise the
            % image would need permuting before it is inserted.
            if ~strcmp(obj.DataDimensionOrder, obj.DimensionOrder)
                error('IMAGESTACK:InsertNotSupported', ...
                    ['insertImage does not yet support a backend whose data ', ...
                    'dimension order (%s) differs from the stack order (%s).'], ...
                    obj.DataDimensionOrder, obj.DimensionOrder)
            end

            obj.Data.insertImageData(imageData, insertInd)
            obj.clearDerivedCaches()
        end

        function downsampledStack = downsampleT(obj, n, method)
            if nargin < 3 || isempty(method)
                method = 'mean';
            end

            if n < 1 || mod(n, 1) ~= 0
                error('IMAGESTACK:InvalidDownsampleFactor', ...
                    'Downsample factor must be a positive integer.')
            end

            numOutputFrames = floor(obj.NumTimepoints / n);
            if numOutputFrames < 1
                error('IMAGESTACK:InvalidDownsampleFactor', ...
                    'Downsample factor exceeds the number of timepoints.')
            end

            frameDim = obj.getAccessAxisNumber();
            reducedFrames = cell(1, numOutputFrames);
            for i = 1:numOutputFrames
                frameIndices = (i-1) * n + (1:n);
                frameBlock = obj.getFrameSet(frameIndices, 'standard');
                reducedFrames{i} = obj.reduceFrameBlock(frameBlock, frameDim, method);
            end

            reducedData = cat(frameDim, reducedFrames{:});
            downsampledStack = imagestack.ImageStack(reducedData, ...
                'DataDimensionArrangement', obj.DimensionOrder);
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
            dim = upper(char(dim));
            obj.validateChunkDimension(dim)

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

            % size(obj.Data) is in stack order, so the axis number must be
            % too. A stack without the requested axis is a single chunk.
            chunkSize = size(obj.Data);
            axisNumber = obj.getStackAxisNumber(dim);
            if ~isempty(axisNumber)
                chunkSize(axisNumber) = min(chunkSize(axisNumber), n);
            end
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
            % size(obj.Data) has one entry per stack dimension, including a
            % trailing singleton that size() drops from a MATLAB array.
            axisNumber = obj.getStackAxisNumber(dimName);
            if isempty(axisNumber)
                dimLength = 1;
            else
                stackSize = size(obj.Data);
                dimLength = stackSize(axisNumber);
            end
        end

        function axisNumber = getStackAxisNumber(obj, dimName)
        %getStackAxisNumber Resolve a dimension letter to its stack axis.
        %
        %   obj.Data is indexed in stack dimension order in both standard
        %   and extended mode, so every axis number used by the front end
        %   is resolved against DimensionOrder. Returns [] when the stack
        %   has no such dimension.
            axisNumber = strfind(obj.DimensionOrder, dimName);
        end

        function axisName = getAccessAxisName(obj)
        %getAccessAxisName Letter of the axis that frameInd indexes.
        %
        %   getFrameSet, writeFrameSet and getFrameSetSize index timepoints
        %   (T) when present, otherwise planes (Z), otherwise channels (C).
        %   Returns '' for a single image, which has no such axis.
            axisName = '';
            for candidate = 'TZC'
                if contains(obj.DimensionOrder, candidate)
                    axisName = candidate;
                    return
                end
            end
        end

        function axisNumber = getAccessAxisNumber(obj)
        %getAccessAxisNumber Stack axis number of the access axis, [] if none.
            axisNumber = obj.getStackAxisNumber(obj.getAccessAxisName());
        end

        function subs = buildIndexingSubs(obj, mode)
        %buildIndexingSubs Build front-end subscripts for a read request.
            if nargin < 2 || isempty(mode)
                mode = 'standard';
            end

            subs = repmat({':'}, 1, numel(obj.DimensionOrder));

            if strcmp(mode, 'extended')
                return
            end

            dimC = obj.getStackAxisNumber('C');
            if ~isempty(dimC) && ~isequal(obj.CurrentChannel, ':')
                subs{dimC} = obj.CurrentChannel;
            end

            dimZ = obj.getStackAxisNumber('Z');
            if ~isempty(dimZ) && ~isequal(obj.CurrentPlane, ':')
                subs{dimZ} = obj.CurrentPlane;
            end
        end

        function subs = buildAccessSubs(obj, frameInd, mode)
        %buildAccessSubs Subscripts selecting frameInd along the access axis.
            subs = obj.buildIndexingSubs(mode);
            accessAxis = obj.getAccessAxisNumber();

            if ~isempty(accessAxis)
                subs{accessAxis} = frameInd;
            else
                % A single image has no access axis, so its only index is 1.
                isWholeImage = (ischar(frameInd) && strcmp(frameInd, ':')) ...
                    || isequal(frameInd, 1);
                if ~isWholeImage
                    error('IMAGESTACK:FrameIndexOutOfRange', ...
                        'The stack is a single image, so the only valid frame index is 1.')
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

        function count = getSelectionLength(obj, selection, dimName)
            if ischar(selection) || isstring(selection)
                if strcmp(selection, ':')
                    count = obj.getDimensionLength(dimName);
                    return
                end
            end

            count = max(1, numel(selection));
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

        function dataSize = getIndexedDataSize(~, baseSize, subs)
            dataSize = zeros(1, numel(subs));
            for i = 1:numel(subs)
                if ischar(subs{i}) || isstring(subs{i})
                    dataSize(i) = baseSize(i);
                else
                    dataSize(i) = numel(subs{i});
                end
            end

            while numel(dataSize) > 2 && dataSize(end) == 1
                dataSize(end) = [];
            end
        end

        function cacheKey = getProjectionCacheKey(obj, projectionName)
            channelKey = regexprep(mat2str(obj.CurrentChannel), '[^0-9A-Za-z]', '_');
            planeKey = regexprep(mat2str(obj.CurrentPlane), '[^0-9A-Za-z]', '_');
            projectionKey = regexprep(lower(char(projectionName)), '[^0-9A-Za-z]', '_');
            cacheKey = sprintf('%s_c%s_z%s', projectionKey, channelKey, planeKey);
        end

        function clearDerivedCaches(obj)
        %clearDerivedCaches Drop everything computed or copied from Data.
            obj.clearProjectionCache()
            obj.DataIntensityLimits = [];
            obj.StaticCacheData = [];
            obj.StaticCacheFrameIndices = [];
        end

        function clearProjectionCache(obj)
            obj.ProjectionCache = struct();
        end

        function reducedBlock = reduceFrameBlock(obj, frameBlock, dim, method)
            switch lower(method)
                case {'mean', 'avg', 'average'}
                    reducedBlock = mean(frameBlock, dim);
                    reducedBlock = cast(reducedBlock, obj.DataType);
                case {'max', 'maximum'}
                    reducedBlock = max(frameBlock, [], dim);
                case {'min', 'minimum'}
                    reducedBlock = min(frameBlock, [], dim);
                otherwise
                    error('IMAGESTACK:UnsupportedDownsampleMethod', ...
                        'Unsupported downsample method "%s".', method)
            end
        end
    end
end
