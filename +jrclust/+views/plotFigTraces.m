function tracesFilt = plotFigTraces(hFigTraces, hCfg, tracesRaw, resetAxis, hClust)
    %PLOTFIGTRACES Plot raw traces view
    hBox = [];
    if hCfg.getOr('showTraceProgressBox', 0)
        hBox = jrclust.utils.qMsgBox('Plotting...', 0, 1);
    end

    hFigTraces.wait(1);

    sampleRate = hCfg.sampleRate / hCfg.nSkip;
    viSamples1 = 1:hCfg.nSkip:size(tracesRaw, 2);
    evtWindowSamp = round(hCfg.evtWindowSamp / hCfg.nSkip); %show 2x of range

    if strcmpi(hFigTraces.figData.filter, 'on')
        % back up old settings
        sampleRateOld = hCfg.sampleRate;
        filterTypeOld = hCfg.filterType;

        % temporarily alter settings to send traces through a filter
        hCfg.sampleRate = sampleRate;
        hCfg.useGPU = 0;
        hCfg.filterType = hCfg.dispFilter;

        if hCfg.fftThresh > 0
            tracesRaw = jrclust.filters.fftClean(tracesRaw, hCfg.fftThresh, hCfg);
        end

        tracesFilt = jrclust.filters.filtCAR(tracesRaw(:, viSamples1), [], [], 0, hCfg);
        tracesFilt = jrclust.utils.bit2uV(tracesFilt, hCfg);
        filterToggle = hCfg.filterType;

        % restore old settings
        hCfg.sampleRate = sampleRateOld;
        hCfg.useGPU = 1;
        hCfg.filterType = filterTypeOld;
    else
        tracesFilt = jrclust.utils.meanSubtract(single(tracesRaw(:, viSamples1))) * hCfg.bitScaling;
        filterToggle = 'off';
    end

    if hCfg.nSegmentsTraces == 1
        XData = ((hFigTraces.figData.windowBounds(1):hCfg.nSkip:hFigTraces.figData.windowBounds(end))-1) / hCfg.sampleRate;
        XLabel = 'Time (s)';
    else
        XData = (0:(size(tracesFilt, 2) - 1)) / (hCfg.sampleRate / hCfg.nSkip) + (hFigTraces.figData.windowBounds(1)-1) / hCfg.sampleRate;
        [multiBounds, multiRange, multiEdges] = jrclust.views.sampleSkip(hFigTraces.figData.windowBounds, hFigTraces.figData.nSamplesTotal, hCfg.nSegmentsTraces);

        tlim_show = (cellfun(@(x) x(1), multiBounds([1, end]))) / hCfg.sampleRate;
        XLabel = sprintf('Time (s), %d segments merged (%0.1f ~ %0.1f s, %0.2f s each)', hCfg.nSegmentsTraces, tlim_show, diff(hCfg.dispTimeLimits));

        mrX_edges = XData(repmat(multiEdges(:)', [3, 1]));
        mrY_edges = repmat([0; hCfg.nSites + 1; nan], 1, numel(multiEdges));

        hFigTraces.plotApply('hEdges', @set, 'XData', mrX_edges(:), 'YData', mrY_edges(:));
        csTime_bin = cellfun(@(x) sprintf('%0.1f', x(1)/hCfg.sampleRate), multiBounds, 'UniformOutput', 0);
        hFigTraces.axApply('default', @set, {'XTick', 'XTickLabel'}, {XData(multiEdges), csTime_bin});
    end

    hFigTraces.multiplot('hPlot', hFigTraces.figData.maxAmp, XData, tracesFilt', 1:hCfg.nSites);

    hFigTraces.axApply('default', @grid, hFigTraces.figData.grid);
    hFigTraces.axApply('default', @set, 'YTick', 1:hCfg.nSites);
    hFigTraces.axApply('default', @title, sprintf(hFigTraces.figData.title, hFigTraces.figData.maxAmp));
    hFigTraces.axApply('default', @xlabel, XLabel);
    hFigTraces.axApply('default', @ylabel, 'Site #');
    hFigTraces.plotApply('hPlot', @set, 'Visible', hFigTraces.figData.traces);

    % Delete spikes from other threads (TODO: break this out into a function)
    plotKeys = keys(hFigTraces.hPlots);
    chSpk = plotKeys(startsWith(plotKeys, 'chSpk'));
    if ~isempty(chSpk)
        cellfun(@(pk) hFigTraces.rmPlot(pk), chSpk);
    end

    % plot spikes
    if strcmpi(hFigTraces.figData.spikes, 'on') && ~isempty(hClust)
        recPos = find(strcmp(hFigTraces.figData.hRec.rawPath, hCfg.rawRecordings));
        if recPos == 1
            offset = 0;
        else
            % find all recordings coming before hRec and sum up nSamples
            % for each
            hRecs = arrayfun(@(iRec) jrclust.detect.newRecording(hCfg.rawRecordings{iRec}, hCfg), 1:(recPos-1), 'UniformOutput', 0);
            offset = sum(cellfun(@(hR) hR.nSamples, hRecs));
        end

	recTimes = double(hClust.spikeTimes) - double(offset);

        tStart = single(hFigTraces.figData.windowBounds(1) - 1)/hCfg.sampleRate;
        if hCfg.nSegmentsTraces > 1
            spikesInRange = inRange(recTimes, multiBounds);
            spikeSites = hClust.spikeSites(spikesInRange);
            spikeTimes = double(recTimes(spikesInRange));
            spikeTimes = round(whereMember(spikeTimes, multiRange) / hCfg.nSkip);
        else
            spikesInRange = recTimes >= hFigTraces.figData.windowBounds(1) & recTimes < hFigTraces.figData.windowBounds(end);
            spikeSites = hClust.spikeSites(spikesInRange);
            spikeTimes = double(recTimes(spikesInRange));
            spikeTimes = round((spikeTimes - hCfg.sampleRate*tStart) / hCfg.nSkip); % time offset
        end

        spikeSites = single(spikeSites);

        % check if clustered
        if isempty(hClust)
            for iSite = 1:hCfg.nSites % deal with subsample factor
                onSite = find(spikeSites == iSite);
                if isempty(onSite)
                    continue;
                end

                timesOnSite = spikeTimes(onSite);
                [mrY11, mrX11] = vr2mr3_(tracesFilt(iSite, :), timesOnSite, evtWindowSamp); %display purpose x2

                mrT11 = single(mrX11-1) / sampleRate + tStart;

                plotKey = sprintf('chSpk%d', iSite);
                hFigTraces.addPlot(plotKey, @line, ...
                                   nan, nan, 'Color', [1 0 0], 'LineWidth', 1.5);

                hFigTraces.multiplot(plotKey, hFigTraces.figData.maxAmp, mrT11, mrY11, iSite);
            end
        else % batch spikes by cluster to keep the trace GUI responsive
            inRangeClusters = hClust.spikeClusters(spikesInRange);
            spikeColors = [lines(hClust.nClusters); 0 0 0];
            uniqueClusters = unique(inRangeClusters(inRangeClusters > 0));
            winLen = evtWindowSamp(end) - evtWindowSamp(1) + 1;

            for iClu = 1:numel(uniqueClusters)
                iCluster = uniqueClusters(iClu);
                clusterMask = inRangeClusters == iCluster;
                clusterTimes = spikeTimes(clusterMask);
                clusterSites = double(spikeSites(clusterMask));
                nClusterSpikes = numel(clusterTimes);

                % One line object per cluster, with NaNs separating waveforms.
                batchX = nan(winLen + 1, nClusterSpikes);
                batchY = nan(winLen + 1, nClusterSpikes);
                for iSpike = 1:nClusterSpikes
                    iSite = clusterSites(iSpike);
                    [spikeTrace, spikeRange] = vr2mr3_( ...
                        tracesFilt(iSite, :), clusterTimes(iSpike), evtWindowSamp);
                    nSamples = numel(spikeRange);
                    batchX(1:nSamples, iSpike) = ...
                        double(spikeRange(:) - 1) / sampleRate + tStart;
                    batchY(1:nSamples, iSpike) = ...
                        double(spikeTrace(:)) / hFigTraces.figData.maxAmp + iSite;
                end

                plotKey = sprintf('chSpk%d', iCluster);
                hFigTraces.addPlot(plotKey, @line, batchX(:), batchY(:), ...
                                   'Color', spikeColors(iCluster, :), 'LineWidth', 2);
            end
        end
    end

    if resetAxis
        jrclust.views.resetFigTraces(hFigTraces, tracesRaw, hCfg);
    end

    hFigTraces.figApply(@set, 'Name', sprintf('%s: filter: %s', hCfg.configFile, filterToggle));
    hFigTraces.wait(0);

    jrclust.utils.tryClose(hBox);
end

%% LOCAL FUNCTIONS
function isInRange = inRange(vals, ranges)
    isInRange = false(size(vals));

    if ~iscell(ranges)
        ranges = {ranges};
    end

    for iRange = 1:numel(ranges)
        bounds = ranges{iRange};
        isInRange = isInRange | (vals >= bounds(1) & vals <= bounds(2));
    end
end

function loc = whereMember(needle, haystack)
    % needle = int32(needle); % ??
    % haystack = int32(haystack); % ??
    [~, loc] = ismember(int32(needle), int32(haystack));
end

function [mr, ranges] = vr2mr3_(traces, spikeTimes, evtWindow)
    % JJJ 2015 Dec 24
    % vr2mr2: quick version and doesn't kill index out of range
    % assumes vi is within range and tolerates spkLim part of being outside
    % works for any datatype

    % prepare indices
    spikeTimes = spikeTimes(:)';
    ranges = int32(bsxfun(@plus, (evtWindow(1):evtWindow(end))', spikeTimes));

    ranges(ranges < 1) = 1;
    ranges(ranges > numel(traces)) = numel(traces); %keep # sites consistent

    % build spike table
    nSpikes = numel(spikeTimes);
    mr = reshape(traces(ranges(:)), [], nSpikes);
end
