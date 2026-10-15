function startup()
%STARTUP Add ImageStack to the search path for this MATLAB session.
%
%   Run this file from a clone of the repository before using ImageStack.
%   It adds src/imagestack and the ImageStackData class of the running
%   MATLAB release. addpath(genpath(...)) does not add that class.
%
%   See also imagestack.internal.addIndexingVariantToPath

    sourceFolder = fullfile(fileparts(mfilename("fullpath")), "src", "imagestack");
    addpath(sourceFolder)
    imagestack.internal.addIndexingVariantToPath()
end
