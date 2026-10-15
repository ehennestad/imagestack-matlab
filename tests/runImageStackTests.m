function results = runImageStackTests()
%RUNIMAGESTACKTESTS Run the ImageStack standalone test suite.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup.m'))

suite = testsuite(fullfile(fileparts(mfilename('fullpath')), '+imagestack'));
results = run(suite);
end
