function gettingStarted()
    % GETTINGSTARTED Open the getting started guide for the toolbox
    %
    %   GETTINGSTARTED() opens the getting started guide for the toolbox.
    %
    %   Example:
    %       imagestack.gettingStarted()
    %
    %   See also imagestack.toolboxdir, imagestack.toolboxversion

    % Display welcome message
    fprintf('Welcome to ImageStack!\n\n');
    fprintf('A class based data model representing image stacks in 5 dimensions\n\n');
    
    % Display version information
    fprintf('Version: %s\n', imagestack.toolboxversion());
    
    % Display directory information
    fprintf('Toolbox directory: %s\n\n', imagestack.toolboxdir());
    
    % Display available functions
    fprintf('Available functions:\n');
    fprintf('  - imagestack.toolboxdir\n');
    fprintf('  - imagestack.toolboxversion\n');
    fprintf('  - imagestack.gettingStarted\n\n');
    
    % Display examples
    fprintf('Examples:\n');
    examplesDir = fullfile(imagestack.toolboxdir(), 'code', 'examples');
    if exist(examplesDir, 'dir')
        exampleFiles = dir(fullfile(examplesDir, '*.m'));
        if ~isempty(exampleFiles)
            for i = 1:length(exampleFiles)
                fprintf('  - %s\n', exampleFiles(i).name);
            end
        else
            fprintf('  No examples found.\n');
        end
    else
        fprintf('  Examples directory not found.\n');
    end
    
    % Display documentation
    fprintf('\nDocumentation:\n');
    docsDir = fullfile(imagestack.toolboxdir(), 'docs');
    if exist(docsDir, 'dir')
        fprintf('  Documentation is available in the docs directory:\n');
        fprintf('  %s\n', docsDir);
    else
        fprintf('  Documentation directory not found.\n');
    end
    
    fprintf('\nFor more information, see the README.md file in the toolbox directory.\n');
end
