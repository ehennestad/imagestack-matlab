function testToolbox(varargin)
% testToolbox - Run tests for NANSEN toolbox

    projectRootDirectory = imagestacktools.projectdir();

    % genpath(src) skips the folder that holds the ImageStackData class of
    % this release, so add it before running tests
    run(fullfile(projectRootDirectory, 'startup.m'))

    matbox.tasks.testToolbox(...
        projectRootDirectory, ...
        varargin{:}, ...
        CoverageFileList=listCoverageFiles(projectRootDirectory) ...
        )
end

function fileList = listCoverageFiles(projectRootDirectory)
%listCoverageFiles List the source files that can run on this MATLAB release.
%
%   Each release uses one ImageStackData variant (see
%   imagestack.internal.indexingVariant). The files of the other variant
%   are never loaded, so they are left out of the coverage report.

    listing = dir(fullfile(projectRootDirectory, 'src', '**', '*.m'));
    fileList = string(fullfile({listing.folder}, {listing.name}));

    variantClassNames = struct( ...
        legacy="ImageStackDataLegacy", modern="ImageStackDataModern");
    variants = string(fieldnames(variantClassNames))';
    unusedVariant = variants(variants ~= imagestack.internal.indexingVariant());

    toolboxFolder = fullfile(projectRootDirectory, 'src', 'imagestack');
    unusedFiles = [ ...
        fullfile(toolboxFolder, '+imagestack', '+data', '+abstract', ...
            variantClassNames.(unusedVariant) + ".m"), ...
        fullfile(toolboxFolder, 'resources', 'indexing', unusedVariant, ...
            '+imagestack', '+data', '+abstract', 'ImageStackData.m')];

    assert(all(ismember(unusedFiles, fileList)), ...
        'IMAGESTACK:CoverageFileNotFound', ...
        'A file of the unused indexing variant was not found:\n%s', ...
        strjoin(unusedFiles(~ismember(unusedFiles, fileList)), newline))
    fileList = setdiff(fileList, unusedFiles, 'stable');
end
