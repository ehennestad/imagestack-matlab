function testToolbox(varargin)
% testToolbox - Run tests for NANSEN toolbox
   
    projectRootDirectory = imagestacktools.projectdir();

    % Important to run these before running tests
    setupImagestack()

    matbox.tasks.testToolbox(...
        projectRootDirectory, ...
        varargin{:} ...
        )
end
