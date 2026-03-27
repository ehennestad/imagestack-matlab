classdef ImageStackDataLegacy < imagestack.data.abstract.ImageStackDataCore
%ImageStackDataLegacy ImageStackData variant backed by subsref/subsasgn.

    methods
        function varargout = subsref(obj, s)
            varargout = cell(1, nargout);
            useBuiltin = strcmp(s(1).type, '.') || numel(obj) > 1;

            if useBuiltin
                if nargout > 0
                    [varargout{:}] = builtin('subsref', obj, s);
                else
                    try
                        varargout{1} = builtin('subsref', obj, s);
                    catch ME
                        switch ME.identifier
                            case {'MATLAB:TooManyOutputs', 'MATLAB:maxlhs'}
                                try
                                    builtin('subsref', obj, s)
                                catch nestedME
                                    throwAsCaller(nestedME)
                                end
                            otherwise
                                throwAsCaller(ME)
                        end
                    end
                end
                return
            end

            if strcmp(s(1).type, '()')
                value = obj.referenceStackData(s(1).subs);
                if numel(s) == 1
                    varargout{1} = value;
                else
                    [varargout{1:nargout}] = builtin('subsref', value, s(2:end));
                end
                return
            end

            error('IMAGESTACK:IndexingNotImplemented', ...
                'Indexing type ''%s'' is not implemented.', s(1).type)
        end

        function obj = subsasgn(obj, s, data)
            switch s(1).type
                case '.'
                    obj = builtin('subsasgn', obj, s, data);

                case '()'
                    if numel(s) == 1
                        obj.assignStackData(s(1).subs, data)
                    else
                        value = obj.referenceStackData(s(1).subs);
                        value = builtin('subsasgn', value, s(2:end), data);
                        obj.assignStackData(s(1).subs, value)
                    end

                otherwise
                    error('IMAGESTACK:IndexingNotImplemented', ...
                        'Indexing type ''%s'' is not implemented.', s(1).type)
            end

            if ~nargout
                clear obj
            end
        end
    end
end
