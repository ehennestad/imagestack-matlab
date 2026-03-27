classdef TiffMultiPart < imagestack.data.VirtualArray
%TiffMultiPart Generic TIFF stack adapter for single or multipart files.

    properties (Constant, Hidden)
        FILE_PERMISSION = 'read'
    end

    properties (Access = protected)
        FilePathList cell = {}
        FileInfo cell = {}
        FrameFileIndex double = []
        FrameInFileIndex double = []
    end

    methods
        function obj = TiffMultiPart(filePath, varargin)
            filePath = imagestack.virtual.TiffMultiPart.lookForMultipartFiles(filePath);
            obj@imagestack.data.VirtualArray(filePath, varargin{:})
        end
    end

    methods (Access = protected)
        function assignFilePath(obj, filePath)
            if iscell(filePath)
                obj.FilePathList = filePath(:)';
                obj.FilePath = char(obj.FilePathList{1});
            else
                obj.FilePathList = {char(filePath)};
                obj.FilePath = char(filePath);
            end
        end

        function getFileInfo(obj)
            obj.FileInfo = cell(size(obj.FilePathList));
            for i = 1:numel(obj.FilePathList)
                obj.FileInfo{i} = imfinfo(obj.FilePathList{i});
            end

            obj.assignDataSize()
            obj.assignDataType()
        end

        function createMemoryMap(~)
        end

        function assignDataSize(obj)
            numFramesPerFile = cellfun(@numel, obj.FileInfo);
            firstInfo = obj.FileInfo{1}(1);
            imageHeight = firstInfo.Height;
            imageWidth = firstInfo.Width;
            samplesPerPixel = getFieldOrDefault(firstInfo, 'SamplesPerPixel', 1);
            totalFrames = sum(numFramesPerFile);

            if samplesPerPixel > 1
                obj.DataSize = [imageHeight, imageWidth, samplesPerPixel, totalFrames];
                obj.DataDimensionArrangement = 'YXCT';
            else
                obj.DataSize = [imageHeight, imageWidth, totalFrames];
                obj.DataDimensionArrangement = 'YXT';
            end

            obj.FrameFileIndex = zeros(1, totalFrames);
            obj.FrameInFileIndex = zeros(1, totalFrames);

            insertAt = 1;
            for i = 1:numel(numFramesPerFile)
                current = insertAt:(insertAt + numFramesPerFile(i) - 1);
                obj.FrameFileIndex(current) = i;
                obj.FrameInFileIndex(current) = 1:numFramesPerFile(i);
                insertAt = current(end) + 1;
            end
        end

        function assignDataType(obj)
            obj.DataType = class(imread(obj.FilePathList{1}, 1));
        end
    end

    methods
        function data = readFrames(obj, frameInd)
            if isempty(frameInd)
                frameInd = [];
            end

            frameInd = reshape(frameInd, 1, []);
            sampleFrame = imread(obj.FilePathList{1}, 1);

            if ndims(sampleFrame) == 2
                data = zeros(size(sampleFrame, 1), size(sampleFrame, 2), ...
                    numel(frameInd), class(sampleFrame));
                for i = 1:numel(frameInd)
                    fileNum = obj.FrameFileIndex(frameInd(i));
                    frameInFile = obj.FrameInFileIndex(frameInd(i));
                    data(:, :, i) = imread(obj.FilePathList{fileNum}, frameInFile);
                end
            else
                data = zeros(size(sampleFrame, 1), size(sampleFrame, 2), ...
                    size(sampleFrame, 3), numel(frameInd), class(sampleFrame));
                for i = 1:numel(frameInd)
                    fileNum = obj.FrameFileIndex(frameInd(i));
                    frameInFile = obj.FrameInFileIndex(frameInd(i));
                    data(:, :, :, i) = imread(obj.FilePathList{fileNum}, frameInFile);
                end
            end
        end

        function writeFrames(~, ~, ~)
            error('IMAGESTACK:ReadOnly', ...
                'TiffMultiPart is read-only in the standalone toolbox.')
        end
    end

    methods (Static)
        function filepath = lookForMultipartFiles(filepath)
            if iscell(filepath) || isempty(filepath)
                return
            end

            [folder, ~, ext] = fileparts(filepath);
            listing = dir(fullfile(folder, ['*', ext]));
            listing = listing(~startsWith({listing.name}, '.'));

            if numel(listing) <= 1
                return
            end

            candidatePaths = fullfile({listing.folder}, {listing.name});
            stripped = regexprep(candidatePaths, '\d*', '');
            if numel(unique(stripped)) == 1
                filepath = candidatePaths;
            end
        end
    end
end

function value = getFieldOrDefault(S, fieldName, defaultValue)
if isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
