classdef Binary < imagestack.data.VirtualArray
%Binary VirtualArray adapter for raw binary stacks.

    properties (Constant, Hidden)
        FILE_PERMISSION = 'write'
        FILE_FORMATS = {'raw', 'bin', 'dat'}
    end

    properties (Access = private)
        MemMap
        IsDirty logical = false
    end

    methods
        function obj = Binary(filePath, varargin)
            obj@imagestack.data.VirtualArray(filePath, varargin{:})
        end

        function delete(obj)
            if obj.IsDirty
                obj.updateLastModified()
            end
            delete@imagestack.data.VirtualArray(obj)
        end

        function updateLastModified(obj)
            fileID = fopen(obj.FilePath, 'a+');
            cleanup = onCleanup(@() fclose(fileID));
            frewind(fileID);
            firstByte = fread(fileID, 1, 'uint8');
            frewind(fileID);
            if isempty(firstByte)
                firstByte = 0;
            end
            fwrite(fileID, firstByte, 'uint8');
            obj.IsDirty = false;
        end
    end

    methods (Access = protected)
        function assignFilePath(obj, filePath)
            filePath = char(filePath);
            if isfolder(filePath)
                listing = dir(fullfile(filePath, '*.raw'));
                if isempty(listing)
                    error('IMAGESTACK:BinaryNotFound', ...
                        'Did not find a raw file in the specified folder.')
                end
                obj.FilePath = fullfile(filePath, listing(1).name);
                return
            end

            [~, ~, ext] = fileparts(filePath);
            if any(strcmpi(strrep(ext, '.', ''), obj.FILE_FORMATS))
                obj.FilePath = filePath;
            else
                error('IMAGESTACK:UnsupportedFileType', ...
                    'Binary adapter does not support "%s".', ext)
            end
        end

        function getFileInfo(obj)
            obj.readMetadata()
            obj.assignDataSize()
            obj.assignDataType()
        end

        function assignDataSize(obj)
            obj.DataSize = double(reshape(obj.MetaData.Size, 1, []));
        end

        function assignDataType(obj)
            obj.DataType = char(obj.MetaData.Class);
        end

        function createMemoryMap(obj)
            mapFormat = {obj.DataType, round(obj.DataSize), 'ImageArray'};
            obj.MemMap = memmapfile(obj.FilePath, 'Writable', true, ...
                'Format', mapFormat);
        end
    end

    methods
        function data = readFrames(obj, frameInd)
            subs = obj.frameind2subs(frameInd);
            data = obj.MemMap.Data.ImageArray(subs{:});
        end

        function writeFrames(obj, data, frameInd)
            subs = obj.frameind2subs(frameInd);
            obj.MemMap.Data.ImageArray(subs{:}) = data;
            obj.IsDirty = true;
        end
    end

    methods (Static)
        function createFile(filePath, arraySize, arrayClass)
            bytes = imagestack.data.abstract.ImageStackData.getImageDataByteSize(...
                arraySize, arrayClass);
            fileId = fopen(filePath, 'w');
            cleanup = onCleanup(@() fclose(fileId));
            if bytes > 0
                fwrite(fileId, 0, 'uint8', bytes-1);
            end

            metadata = imagestack.metadata.StackMetadata(filePath);
            metadata.Size = arraySize;
            metadata.Class = arrayClass;
            metadata.writeToFile()
        end
    end
end
