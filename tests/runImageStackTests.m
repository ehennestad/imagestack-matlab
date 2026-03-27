function results = runImageStackTests(indexingVariant)
%RUNIMAGESTACKTESTS Run the ImageStack standalone test suite.

if nargin == 0
    indexingVariant = "legacy";
end

repoRoot = fileparts(fileparts(mfilename('fullpath')));
if ~contains(path, repoRoot)
    addpath(repoRoot)
end

setupImagestack(IndexingVariant=indexingVariant, AddPaths=true)

suite = testsuite(fullfile(fileparts(mfilename('fullpath')), '+imagestack'));
results = run(suite);
end
