function variant = indexingVariant()
%INDEXINGVARIANT Name of the ImageStackData variant for the running MATLAB release.
%
%   variant = imagestack.internal.indexingVariant() returns "modern" on
%   R2021b and later, where ImageStackData indexes through
%   matlab.mixin.indexing.RedefinesParen, and "legacy" on earlier releases,
%   where it overloads subsref and subsasgn.
%
%   See also imagestack.internal.addIndexingVariantToPath

    if isMATLABReleaseOlderThan("R2021b")
        variant = "legacy";
    else
        variant = "modern";
    end
end
