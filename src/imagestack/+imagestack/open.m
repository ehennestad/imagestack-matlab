function virtualData = open(pathStr, varargin)
%OPEN Open file-backed imagestack data.

    [~, ~, ext] = fileparts(pathStr);

    switch lower(ext)
        case {'.tif', '.tiff'}
            virtualData = imagestack.virtual.TiffMultiPart(pathStr, varargin{:});
        case {'.raw', '.bin', '.dat'}
            virtualData = imagestack.virtual.Binary(pathStr, varargin{:});
        otherwise
            error('IMAGESTACK:UnsupportedFileType', ...
                'No standalone loader is available for files of type %s.', ext)
    end
end
