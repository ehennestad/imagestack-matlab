classdef StackMetadata < handle
%StackMetadata Metadata container for imagestack data.

    properties (Access = protected)
        Filename char = ''
    end

    properties
        DimensionArrangement char = ''
        Size = []
        Class char = ''

        SizeX (1,1) double = 1
        SizeY (1,1) double = 1
        SizeZ (1,1) double = 1
        SizeC (1,1) double = 1
        SizeT (1,1) double = 1

        PhysicalSizeX (1,1) double = 1
        PhysicalSizeY (1,1) double = 1
        PhysicalSizeZ (1,1) double = 1
        PhysicalSizeXUnit char = 'pixel'
        PhysicalSizeYUnit char = 'pixel'
        PhysicalSizeZUnit char = 'pixel'

        TimeIncrement (1,1) double = 1
        TimeIncrementUnit char = 'N/A'

        StartTime = datetime.empty
        SpatialPosition = [0, 0, 0]

        ChannelDescription = []
        ChannelIndicator = []
        ChannelColor = zeros(0, 3)

        FrameTimes = []
        FramePositions = []
    end

    properties (Dependent, Transient)
        ImageSize
        SampleRate
        SpatialLength
        SpatialUnits
    end

    methods
        function obj = StackMetadata(filePath)
            if nargin > 0 && ~isempty(filePath)
                obj.assignFilepath(filePath)
                obj.readFromFile()
            end
        end

        function sampleRate = get.SampleRate(obj)
            if contains(obj.TimeIncrementUnit, 'second')
                sampleRate = 1 / obj.TimeIncrement;
            else
                sampleRate = nan;
            end
        end

        function set.SampleRate(obj, newValue)
            obj.TimeIncrement = 1 ./ newValue;
            obj.TimeIncrementUnit = 'second';
        end

        function imageSize = get.ImageSize(obj)
            imageSize = [obj.SizeX .* obj.PhysicalSizeX, ...
                obj.SizeY .* obj.PhysicalSizeY];
        end

        function set.ImageSize(obj, newValue)
            if numel(newValue) == 1
                newValue = [newValue, newValue];
            end

            obj.PhysicalSizeX = newValue(1) ./ obj.SizeX;
            obj.PhysicalSizeY = newValue(2) ./ obj.SizeY;
        end

        function spatialLength = get.SpatialLength(obj)
            spatialLength = [obj.PhysicalSizeX, obj.PhysicalSizeY, ...
                obj.PhysicalSizeZ];
        end

        function spatialUnits = get.SpatialUnits(obj)
            spatialUnits = {obj.PhysicalSizeXUnit, obj.PhysicalSizeYUnit, ...
                obj.PhysicalSizeZUnit};
        end

        function assignFilepath(obj, filepath)
            [folderPath, filename, ~] = fileparts(filepath);
            obj.Filename = fullfile(folderPath, [filename, '.yaml']);
        end

        function readFromFile(obj)
            if isempty(obj.Filename) || ~isfile(obj.Filename)
                return
            end

            S = jsondecode(fileread(obj.Filename));
            obj.fromStruct(S)
        end

        function writeToFile(obj)
            if isempty(obj.Filename)
                return
            end

            S = obj.toStruct();
            fid = fopen(obj.Filename, 'w');
            cleanup = onCleanup(@() fclose(fid));
            fwrite(fid, jsonencode(S, PrettyPrint=true));
        end

        function deleteFile(obj)
            if ~isempty(obj.Filename) && isfile(obj.Filename)
                delete(obj.Filename)
            end
        end

        function save(obj)
            obj.writeToFile()
        end

        function updateTimeUnit(~)
        end

        function updateFromSource(obj, S)
            propertyNames = {'PhysicalSizeX', 'PhysicalSizeXUnit', ...
                'PhysicalSizeY', 'PhysicalSizeYUnit', 'PhysicalSizeZ', ...
                'PhysicalSizeZUnit', 'TimeIncrement', 'TimeIncrementUnit', ...
                'StartTime', 'SpatialPosition', 'DimensionArrangement'};

            obj.fromStruct(S, propertyNames)
        end

        function uiset(~, ~, ~)
        end
    end

    methods (Access = protected)
        function S = toStruct(obj)
            propertyNames = obj.getPropertyNames();
            S = struct();
            for i = 1:numel(propertyNames)
                propertyName = propertyNames{i};
                propertyValue = obj.(propertyName);
                if isa(propertyValue, 'datetime')
                    if isempty(propertyValue)
                        propertyValue = '';
                    else
                        propertyValue = char(string(propertyValue, ...
                            'yyyy-MM-dd''T''HH:mm:ss.SSS'));
                    end
                end
                S.(propertyName) = propertyValue;
            end
        end

        function fromStruct(obj, S, propertyNames)
            if nargin < 3
                propertyNames = fieldnames(S);
            end

            for i = 1:numel(propertyNames)
                propertyName = propertyNames{i};
                if isfield(S, propertyName) && isprop(obj, propertyName)
                    propertyValue = S.(propertyName);
                    if strcmp(propertyName, 'StartTime')
                        if isempty(propertyValue)
                            propertyValue = datetime.empty;
                        else
                            propertyValue = datetime(propertyValue, ...
                                'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss.SSS');
                        end
                    elseif strcmp(propertyName, 'SpatialPosition') ...
                            && isstruct(propertyValue)
                        propertyValue = struct2array(orderfields(propertyValue));
                    elseif any(strcmp(propertyName, ...
                            {'Size', 'SpatialPosition', 'FrameTimes', 'FramePositions'}))
                        propertyValue = reshape(propertyValue, 1, []);
                    end
                    obj.(propertyName) = propertyValue;
                end
            end
        end

        function propertyNames = getPropertyNames(~)
            propertyNames = {'DimensionArrangement', 'Size', 'Class', ...
                'SizeX', 'SizeY', 'SizeZ', 'SizeC', 'SizeT', ...
                'PhysicalSizeX', 'PhysicalSizeY', 'PhysicalSizeZ', ...
                'PhysicalSizeXUnit', 'PhysicalSizeYUnit', ...
                'PhysicalSizeZUnit', 'TimeIncrement', ...
                'TimeIncrementUnit', 'StartTime', 'SpatialPosition', ...
                'ChannelDescription', 'ChannelIndicator', ...
                'ChannelColor', 'FrameTimes', 'FramePositions'};
        end
    end
end
