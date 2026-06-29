function hAx = addAxes(obj, axKey, varargin)
    %ADDAXES Create and store new axes for this figure
    if ~obj.isReady
        hAx = [];
        return;
    end

    if obj.hasAxes(axKey)
        hAx = obj.hAxes(axKey);
        return;
    end

    hAx = axes('Parent', obj.hFig, varargin{:});
    obj.hAxes(axKey) = hAx;
    obj.axApply(axKey, @hold, 'on');
end
