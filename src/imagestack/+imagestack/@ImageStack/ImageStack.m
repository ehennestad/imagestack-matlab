classdef ImageStack < handle
%ImageStack Wrapper for in-memory image stack data.

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
            [stackOptions, dataOptions] = obj.parseInputs(varargin{:});

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

            subs = obj.getDefaultSubs(mode);
            frameDim = obj.getFrameDimensionNumber(mode);
            subs{frameDim} = frameInd;
            data = obj.Data(subs{:});
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
                dim = obj.getDimensionNumber(char(dim), dimMode);
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
            dimNumber = obj.getDimensionNumber(dim, 'extended');
            chunkSize(dimNumber) = min(chunkSize(dimNumber), n);
        end

        function [indices, numChunks] = getChunkedFrameIndices(obj, numFramesPerChunk, chunkIndex, dim)
            if nargin < 4 || isempty(dim)
                dim = 'T';
            end
            if nargin < 3 || isempty(chunkIndex)
                chunkIndex = 1;
            end
            if nargin < 2 || isempty(numFramesPerChunk) || isequal(numFramesPerChunk, inf)
                numFramesPerChunk = obj.getDimensionLength(dim);
            end

            numFrames = obj.getDimensionLength(dim);
            numChunks = ceil(numFrames / numFramesPerChunk);
            firstIdx = (chunkIndex - 1) * numFramesPerChunk + 1;
            lastIdx = min(numFrames, chunkIndex * numFramesPerChunk);
            indices = firstIdx:lastIdx;
        end
    end

    methods (Access = private)
        function [stackOptions, dataOptions] = parseInputs(~, varargin)
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
            dimIndex = strfind(obj.Data.DataDimensionArrangement, dimName);
            if isempty(dimIndex)
                dimLength = 1;
            else
                dimLength = obj.Data.DataSize(dimIndex);
            end
        end

        function dimNumber = getDimensionNumber(obj, dimName, mode)
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

        function subs = getDefaultSubs(obj, mode)
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

            dimC = obj.getDimensionNumber('C', mode);
            if ~isempty(dimC) && ~isequal(obj.CurrentChannel, ':')
                subs{dimC} = obj.CurrentChannel;
            end

            dimZ = obj.getDimensionNumber('Z', mode);
            if ~isempty(dimZ) && ~isequal(obj.CurrentPlane, ':')
                subs{dimZ} = obj.CurrentPlane;
            end
        end

        function frameDim = getFrameDimensionNumber(obj, mode)
            if nargin < 2 || isempty(mode)
                mode = 'standard';
            end

            switch mode
                case 'extended'
                    if contains(obj.Data.DataDimensionArrangement, 'T')
                        frameDim = obj.getDimensionNumber('T', 'extended');
                    elseif contains(obj.Data.DataDimensionArrangement, 'Z')
                        frameDim = obj.getDimensionNumber('Z', 'extended');
                    else
                        frameDim = numel(obj.Data.DataDimensionArrangement);
                    end
                otherwise
                    if contains(obj.DimensionOrder, 'T')
                        frameDim = obj.getDimensionNumber('T');
                    elseif contains(obj.DimensionOrder, 'Z')
                        frameDim = obj.getDimensionNumber('Z');
                    else
                        frameDim = numel(obj.DimensionOrder);
                    end
            end
        end
    end
end
