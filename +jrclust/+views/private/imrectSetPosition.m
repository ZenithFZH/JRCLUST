function imrectSetPosition(hFig, plotKey, xpos, ypos)
    %IMRECTSETPOSITION
    imPos = hFig.plotApply(plotKey, @getPosition);
    if isempty(imPos)
        imPos = hFig.plotApply(plotKey, @get, 'Position');
    end
    if isempty(imPos)
        return;
    end

    if ~isempty(xpos)
        imPos(1) = min(xpos);
        imPos(3) = abs(diff(xpos));
    end
    if ~isempty(ypos)
        imPos(2) = min(ypos);
        imPos(4) = abs(diff(ypos));
    end
    hFig.plotApply(plotKey, @setPosition, imPos);
    hFig.plotApply(plotKey, @set, 'Position', imPos);
end
