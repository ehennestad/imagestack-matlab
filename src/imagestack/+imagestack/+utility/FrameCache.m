classdef FrameCache < handle
%FrameCache Rolling frame cache for virtual array adapters.

    properties
        CacheLength (1,1) double {mustBePositive, mustBeInteger} = 1000
        LeadingDimension (1,1) double {mustBePositive, mustBeInteger} = 1
    end

    properties (Dependent)
        CacheRange
    end

    properties (SetAccess = private)
        DataSize
        DataType
    end

    properties (Access = private)
        Data
        CachedFrameIndices
        NextInsertIndex (1,1) double = 1
    end

    methods
        function obj = FrameCache(dataSize, dataType, cacheLength, varargin)
            arguments
                dataSize (1,:) double
                dataType (1,:) char
                cacheLength (1,1) double {mustBePositive, mustBeInteger}
            end
            arguments (Repeating)
                varargin
            end

            obj.DataSize = dataSize;
            obj.DataType = dataType;
            obj.LeadingDimension = numel(dataSize);

            if ~isempty(varargin)
                for i = 1:2:numel(varargin)
                    if strcmp(varargin{i}, 'LeadingDimension')
                        obj.LeadingDimension = varargin{i+1};
                    end
                end
            end

            % The cache never needs more slots than there are frames. A
            % leading dimension beyond the end of dataSize has length 1.
            cacheSize = dataSize;
            cacheSize(end+1:obj.LeadingDimension) = 1;
            obj.CacheLength = min(cacheLength, max(1, cacheSize(obj.LeadingDimension)));
            cacheSize(obj.LeadingDimension) = obj.CacheLength;
            obj.Data = zeros(cacheSize, dataType);
            obj.CachedFrameIndices = zeros(1, obj.CacheLength);
        end

        function cacheRange = get.CacheRange(obj)
            if ~any(obj.CachedFrameIndices)
                cacheRange = [0, 0];
            else
                validIndices = obj.CachedFrameIndices(obj.CachedFrameIndices > 0);
                cacheRange = [min(validIndices), max(validIndices)];
            end
        end

        function hitMiss = queryData(obj, frameIndices)
            hitMiss = ismember(frameIndices, obj.CachedFrameIndices);
        end

        function [frameData, hitIndices, missIndices] = fetchData(obj, frameIndices)
            hitMask = ismember(obj.CachedFrameIndices, frameIndices);
            subs = repmat({':'}, 1, max(ndims(obj.Data), obj.LeadingDimension));
            subs{obj.LeadingDimension} = hitMask;
            frameData = obj.Data(subs{:});

            hitIndices = obj.CachedFrameIndices(hitMask);
            missIndices = frameIndices(~ismember(frameIndices, hitIndices));
        end

        function invalidateData(obj, frameIndices)
        %invalidateData Forget cached frames, so that they are read again.
        %
        %   frameIndices is a vector of frame indices, or ':' for all.
            if ischar(frameIndices) && strcmp(frameIndices, ':')
                obj.CachedFrameIndices(:) = 0;
            else
                isInvalidated = ismember(obj.CachedFrameIndices, frameIndices);
                obj.CachedFrameIndices(isInvalidated) = 0;
            end
        end

        function submitData(obj, frameData, frameIndices)
            if isempty(frameIndices)
                return
            end

            nFrames = numel(frameIndices);
            insertIndices = obj.NextInsertIndex + (0:nFrames-1);
            insertIndices = mod(insertIndices-1, obj.CacheLength) + 1;

            subs = repmat({':'}, 1, max(ndims(obj.Data), obj.LeadingDimension));
            subs{obj.LeadingDimension} = insertIndices;
            obj.Data(subs{:}) = frameData;
            obj.CachedFrameIndices(insertIndices) = frameIndices;

            obj.NextInsertIndex = mod(insertIndices(end), obj.CacheLength) + 1;
        end
    end
end
