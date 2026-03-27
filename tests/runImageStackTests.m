function results = runImageStackTests()
%RUNIMAGESTACKTESTS Run the ImageStack standalone test suite.

suite = testsuite(fullfile(fileparts(mfilename('fullpath')), '+imagestack'));
results = run(suite);
end
