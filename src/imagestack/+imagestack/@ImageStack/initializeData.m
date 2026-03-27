function imageStackData = initializeData(~, dataReference, varargin)
%initializeData Initialize an ImageStackData object from a data reference.

    if isa(dataReference, 'imagestack.data.abstract.ImageStackData')
        imageStackData = dataReference;
        return
    end

    if isempty(dataReference) && isa(dataReference, 'double')
        imageStackData = imagestack.data.MatlabArray(nan(512, 512));
        return
    end

    if isnumeric(dataReference) || islogical(dataReference)
        imageStackData = imagestack.data.MatlabArray(dataReference, ...
            varargin{:});
        return
    end

    if isa(dataReference, 'char') || isa(dataReference, 'string')
        if isfolder(dataReference)
            error('IMAGESTACK:FolderInputNotSupported', ...
                'Folder inputs are not supported yet: %s', ...
                char(dataReference))
        end

        imageStackData = imagestack.open(char(dataReference), varargin{:});
        return
    end

    if isa(dataReference, 'cell')
        error('IMAGESTACK:FileInputNotSupported', ...
            'Cell-array file inputs are not implemented yet.')
    end

    error('IMAGESTACK:InvalidInput', ...
        'dataReference is not valid for imagestack.ImageStack.')
end
