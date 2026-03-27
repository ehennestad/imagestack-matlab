classdef MockVirtualArray < imagestack.data.VirtualArray

    properties (Constant, Hidden)
        FILE_PERMISSION = 'write'
    end

    properties (Access = private)
        MatFile
    end

    methods (Access = protected)
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
            obj.MatFile = matfile(obj.FilePath, 'Writable', true);
        end
    end

    methods
        function data = readFrames(obj, frameIndex)
            subs = obj.frameind2subs(frameIndex);
            data = obj.MatFile.ImageArray(subs{:});
        end

        function writeFrames(obj, data, frameIndex)
            subs = obj.frameind2subs(frameIndex);
            obj.MatFile.ImageArray(subs{:}) = data;
        end
    end

    methods (Static)
        function createFile(filePath, dataSize, dataType)
            ImageArray = zeros(dataSize, dataType); %#ok<NASGU>
            save(filePath, 'ImageArray', '-v7.3')

            metadata = imagestack.metadata.StackMetadata(filePath);
            metadata.Size = dataSize;
            metadata.Class = dataType;
            metadata.writeToFile()
        end
    end
end
