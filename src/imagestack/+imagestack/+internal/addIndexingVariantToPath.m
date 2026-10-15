function addIndexingVariantToPath()
%ADDINDEXINGVARIANTTOPATH Add the ImageStackData class of this MATLAB release to the path.
%
%   imagestack.internal.addIndexingVariantToPath() adds the folder that
%   defines imagestack.data.abstract.ImageStackData for the running release
%   (see imagestack.internal.indexingVariant).
%
%   MATLAB looks up the superclass when it loads a class, so this must run
%   before any stack data backend is used. The folders of both variants are
%   below a folder named resources, which genpath skips, so adding the
%   toolbox with addpath(genpath(...)) adds neither.
%
%   See also imagestack.internal.indexingVariant

    toolboxFolder = fileparts(fileparts(fileparts(mfilename("fullpath"))));
    addpath(fullfile(toolboxFolder, "resources", "indexing", ...
        imagestack.internal.indexingVariant()))
end
