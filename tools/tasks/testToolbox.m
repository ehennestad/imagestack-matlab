function testToolbox(varargin)
% testToolbox - Run the imagestack test suites under each indexing variant
%
%   testToolbox(Name=Value) runs the MatBox test task once per
%   ImageStackData indexing variant (legacy, then modern). Name-value
%   arguments are passed on to matbox.tasks.testToolbox.
%
%   The legacy pass writes its reports, coverage and test badge where
%   MatBox puts them by default. The modern pass writes its reports to a
%   "modern" subfolder of the report directory and creates no badge, so
%   it does not overwrite the legacy results. Both passes always run, and
%   the function errors if either pass has failing tests.
%
%   The indexing variant that was configured before the call is restored
%   when the function exits.

    projectRootDirectory = imagestacktools.projectdir();

    indexingVariants = ["legacy", "modern"];
    reportSubdirectory = getNameValue(varargin, "ReportSubdirectory", "");

    originalVariant = string(getpref('imagestack', 'IndexingVariant', 'legacy'));
    restoreVariant = onCleanup(@() setupImagestack(IndexingVariant=originalVariant));

    failedVariants = strings(1, 0);
    failureCauses = cell(1, 0);

    for variant = indexingVariants
        if variant == "legacy"
            testArguments = varargin;
        else
            testArguments = [varargin, { ...
                "ReportSubdirectory", fullfile(reportSubdirectory, variant), ...
                "CreateBadge", false}];
        end

        fprintf('Running tests with the %s indexing variant\n', variant)
        setupImagestack(IndexingVariant=variant);

        % Defer test failures so that every variant runs before reporting.
        try
            matbox.tasks.testToolbox(projectRootDirectory, testArguments{:})
        catch exception
            failedVariants(end+1) = variant; %#ok<AGROW>
            failureCauses{end+1} = exception; %#ok<AGROW>
        end
    end

    if ~isempty(failedVariants)
        testFailure = MException('IMAGESTACK:TestToolbox:TestsFailed', ...
            'Tests failed for the indexing variant(s): %s.', strjoin(failedVariants, ", "));
        for i = 1:numel(failureCauses)
            testFailure = testFailure.addCause(failureCauses{i});
        end
        throw(testFailure)
    end
end

function value = getNameValue(nameValuePairs, name, defaultValue)
% getNameValue - Return the last value given for a name in name-value pairs
    value = defaultValue;
    for i = 1:2:numel(nameValuePairs) - 1
        if strcmpi(nameValuePairs{i}, name)
            value = nameValuePairs{i+1};
        end
    end
end
