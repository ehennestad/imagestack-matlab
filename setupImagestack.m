function generatedRoot = setupImagestack(options)
%SETUPIMAGESTACK Configure the active ImageStackData indexing variant.

arguments
    options.IndexingVariant (1,1) string ...
        {mustBeMember(options.IndexingVariant, ["legacy", "modern"])} = "legacy"
    options.AddPaths (1,1) logical = true
end

repoRoot = fileparts(mfilename('fullpath'));
sourceRoot = fullfile(repoRoot, 'src', 'imagestack');
generatedRoot = fullfile(prefdir, 'imagestack-matlab');
selectorDir = fullfile(generatedRoot, '+imagestack', '+data', '+abstract');

if ~isfolder(selectorDir)
    mkdir(selectorDir)
end

selectorPath = fullfile(selectorDir, 'ImageStackData.m');
selectorClassName = sprintf('imagestack.data.abstract.ImageStackData%s', ...
    upperFirst(options.IndexingVariant));
selectorContents = composeSelectorClass(selectorClassName, options.IndexingVariant);

if isfile(selectorPath)
    existingContents = fileread(selectorPath);
else
    existingContents = '';
end

if ~strcmp(existingContents, selectorContents)
    fid = fopen(selectorPath, 'w');
    cleaner = onCleanup(@() fclose(fid));
    assert(fid ~= -1, 'IMAGESTACK:SetupFailed', ...
        'Could not write the active ImageStackData selector.')
    fwrite(fid, selectorContents, 'char');
    clear cleaner
end

setpref('imagestack', 'IndexingVariant', char(options.IndexingVariant))
setpref('imagestack', 'GeneratedRoot', generatedRoot)

if options.AddPaths
    if ~contains(path, generatedRoot)
        addpath(generatedRoot, '-begin')
    end
    if ~contains(path, sourceRoot)
        addpath(sourceRoot)
    end
end
end

function text = composeSelectorClass(targetClassName, variant)
text = sprintf([ ...
    'classdef ImageStackData < %s\n' ...
    '%%ImageStackData Active ImageStackData selector for %s indexing.\n' ...
    'end\n'], targetClassName, variant);
end

function value = upperFirst(value)
value = char(value);
value(1) = upper(value(1));
end
