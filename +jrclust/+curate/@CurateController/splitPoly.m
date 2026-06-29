function success = splitPoly(obj, hFig, shift)
    %SPLITPOLY Draw a polygon or rectangle around points in a feature
    %projection and split off a new cluster.
    success = 0;
    
    if numel(obj.selected) > 1
        return;
    end

    iCluster = obj.selected;

    polyPos = hFig.axApply('default', @getSplitPolygonPosition, shift);

    if isempty(polyPos) || size(polyPos, 1) < 3
        return;
    end

    XData = hFig.plotApply('foreground', @get, 'XData');
    YData = hFig.plotApply('foreground', @get, 'YData');
    splitOff = inpolygon(XData, YData, polyPos(:,1), polyPos(:,2));

    hFig.rmPlot('hPoly');
    if ~any(splitOff) || all(splitOff)
        return;
    end

    % show the consequences of the proposed split
    hFig.addPlot('hSplit', @line, XData(splitOff), YData(splitOff), ...
        'Color', obj.hCfg.colorMap(3, :), ...
        'Marker', '.', 'LineStyle', 'none');

    dlgAns = questdlg('Split?', 'Confirmation', 'No');

    hFig.rmPlot('hSplit');

    if strcmp(dlgAns, 'Yes')
        if isfield(hFig.figData, 'foreground') % FigProj
            % first rescale features in this polygon if necessary
            s = hFig.figData.initialScale/hFig.figData.boundScale;
            fgXData = hFig.figData.foreground.XData;
            xFloor = floor(fgXData);
            if strcmp(obj.hCfg.dispFeature, 'vpp')
                fgXData = (fgXData - xFloor)*s;
            else
                % remap to [-1, 1] first, then scale, then map back to [0, 1]
                fgXData = jrclust.utils.linmap(fgXData - xFloor, [0, 1], [-1, 1])*s;
                fgXData = jrclust.utils.linmap(fgXData, [-1, 1], [0, 1]);
            end
            fgXData((fgXData <= 0 | fgXData >= 1)) = nan;
            fgXData = fgXData + xFloor;

            fgYData = hFig.figData.foreground.YData;
            yFloor = floor(fgYData);
            if strcmp(obj.hCfg.dispFeature, 'vpp')
                fgYData = (fgYData - yFloor)*s;
            else
                % remap to [-1, 1] first, then scale, then map back to [0, 1]
                fgYData = jrclust.utils.linmap(fgYData - yFloor, [0, 1], [-1, 1])*s;
                fgYData = jrclust.utils.linmap(fgYData, [-1, 1], [0, 1]);
            end
            fgYData((fgYData <= 0 | fgYData >= 1)) = nan;
            fgYData = fgYData + yFloor;
            % get values of ALL foreground features in this polygon
            ii = any(inpolygon(fgXData, fgYData, polyPos(:, 1), polyPos(:, 2)), 2);
            unitPart = {find(ii)};
        else
            unitPart = {find(splitOff)};
        end
        obj.splitCluster(iCluster, unitPart);
    end
    
    success = 1;
end

function polyPos = getSplitPolygonPosition(hAx, shift)
    polyPos = [];
    hRoi = [];

    if shift
        try
            if exist('drawrectangle', 'file') == 2
                hRoi = drawrectangle(hAx, 'Color', 'r', 'FaceAlpha', 0, 'LineWidth', 0.75);
                try
                    rectPos = wait(hRoi);
                catch
                    rectPos = [];
                end
                if isempty(rectPos) && isvalid(hRoi) && isprop(hRoi, 'Position')
                    rectPos = hRoi.Position;
                end
                polyPos = rectToPolygon(rectPos);
                deleteRoi(hRoi);
                return;
            end
        catch
            deleteRoi(hRoi);
            polyPos = [];
        end

        try
            hRoi = imrect(hAx);
            try
                rectPos = wait(hRoi);
            catch
                rectPos = getPosition(hRoi);
            end
            polyPos = rectToPolygon(rectPos);
        catch
            polyPos = [];
        end
        deleteRoi(hRoi);
        return;
    end

    try
        if exist('drawpolygon', 'file') == 2
            hRoi = drawpolygon(hAx, 'Color', 'r', 'FaceAlpha', 0, 'LineWidth', 0.75);
            try
                roiPos = wait(hRoi);
            catch
                roiPos = [];
            end
            if isempty(roiPos) && isvalid(hRoi) && isprop(hRoi, 'Position')
                roiPos = hRoi.Position;
            end
            polyPos = roiPos;
            deleteRoi(hRoi);
            return;
        end
    catch
        deleteRoi(hRoi);
        polyPos = [];
    end

    try
        hRoi = impoly(hAx);
        try
            polyPos = wait(hRoi);
        catch
            polyPos = getPosition(hRoi);
        end
    catch
        polyPos = [];
    end
    deleteRoi(hRoi);
end

function polyPos = rectToPolygon(rectPos)
    if isempty(rectPos) || numel(rectPos) < 4
        polyPos = [];
        return;
    end

    xpos = [repmat(rectPos(1), 2, 1); repmat(rectPos(1) + rectPos(3), 2, 1)];
    ypos = [rectPos(2); repmat(rectPos(2) + rectPos(4), 2, 1); rectPos(2)];
    polyPos = [xpos ypos];
end

function deleteRoi(hRoi)
    try
        if ~isempty(hRoi) && isvalid(hRoi)
            delete(hRoi);
        end
    catch
        try
            delete(hRoi);
        catch
        end
    end
end
