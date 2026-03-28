classdef MultiResolutionStack < handle
%MultiResolutionStack Simple multiresolution wrapper for ImageStack reads.

    properties (SetAccess = private)
        SourceStack imagestack.ImageStack
    end

    properties (Access = private)
        PyramidCache struct = struct()
    end

    methods
        function obj = MultiResolutionStack(sourceStack)
            obj.SourceStack = sourceStack;
            obj.PyramidCache.scale_1 = sourceStack.getFrameSet('all', 'standard');
        end

        function data = getFrameSet(obj, frameInd, varargin)
            options = obj.parseReadOptions(varargin{:});
            stackData = obj.getScaledStack(options.Scale);

            frameDim = obj.getFrameDimension(stackData);
            subs = repmat({':'}, 1, ndims(stackData));
            if nargin >= 2 && ~isempty(frameInd) && ~(ischar(frameInd) && strcmp(frameInd, 'all'))
                subs{frameDim} = frameInd;
            end

            data = stackData(subs{:});
            data = obj.applyRoi(data, options.ROI);
        end

        function data = getDisplayFrame(obj, frameInd, varargin)
            data = obj.getFrameSet(frameInd, varargin{:});
        end

        function numLevels = getNumCachedLevels(obj)
            numLevels = numel(fieldnames(obj.PyramidCache));
        end
    end

    methods (Access = private)
        function options = parseReadOptions(~, varargin)
            options = struct('Scale', 1, 'ROI', []);
            for i = 1:2:numel(varargin)
                options.(char(varargin{i})) = varargin{i+1};
            end
        end

        function stackData = getScaledStack(obj, scale)
            fieldName = obj.getScaleFieldName(scale);
            if isfield(obj.PyramidCache, fieldName)
                stackData = obj.PyramidCache.(fieldName);
                return
            end

            baseData = obj.SourceStack.getFrameSet('all', 'standard');
            stackData = obj.downsampleSpatially(baseData, scale);
            obj.PyramidCache.(fieldName) = stackData;
        end

        function data = downsampleSpatially(~, data, scale)
            if scale == 1
                return
            end

            stride = round(1 / scale);
            if ~isscalar(stride) || stride < 1 || abs(scale - 1/stride) > eps(scale)
                error('IMAGESTACK:UnsupportedScale', ...
                    'Scale must be 1 or the reciprocal of a positive integer.')
            end

            subs = repmat({':'}, 1, ndims(data));
            subs{1} = 1:stride:size(data, 1);
            subs{2} = 1:stride:size(data, 2);
            data = data(subs{:});
        end

        function data = applyRoi(~, data, roi)
            if isempty(roi)
                return
            end

            if isstruct(roi)
                xLim = roi.XLim;
                yLim = roi.YLim;
            else
                xLim = roi(1, :);
                yLim = roi(2, :);
            end

            subs = repmat({':'}, 1, ndims(data));
            subs{1} = yLim(1):yLim(2);
            subs{2} = xLim(1):xLim(2);
            data = data(subs{:});
        end

        function frameDim = getFrameDimension(~, data)
            frameDim = max(3, ndims(data));
        end

        function fieldName = getScaleFieldName(~, scale)
            fieldName = sprintf('scale_%s', strrep(num2str(scale, '%.4f'), '.', '_'));
            fieldName = regexprep(fieldName, '_+$', '');
        end
    end
end
