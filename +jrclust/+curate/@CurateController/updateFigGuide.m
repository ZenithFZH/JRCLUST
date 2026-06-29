function updateFigGuide(obj)
    %UPDATEFIGGUIDE Show curation guidance for the currently selected unit.
    if isempty(obj.selected) || ~obj.hasFig('FigGuide')
        return;
    end

    hFigGuide = obj.hFigs('FigGuide');
    if ~hFigGuide.isReady
        return;
    end

    iCluster = obj.selected(1);
    guide = buildGuide(obj.hClust, obj.hCfg, iCluster);

    hFigGuide.clf();
    hFigGuide.figApply(@set, 'Color', 'w');

    uicontrol('Parent', hFigGuide.figApply(@identity), ...
              'Style', 'text', ...
              'Units', 'normalized', ...
              'Position', [0.04 0.84 0.92 0.12], ...
              'String', guide.title, ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold', ...
              'FontSize', 11, ...
              'BackgroundColor', 'w');

    uicontrol('Parent', hFigGuide.figApply(@identity), ...
              'Style', 'edit', ...
              'Units', 'normalized', ...
              'Position', [0.04 0.22 0.92 0.58], ...
              'String', guide.text, ...
              'HorizontalAlignment', 'left', ...
              'Max', 2, ...
              'Min', 0, ...
              'Enable', 'inactive', ...
              'BackgroundColor', 'w');

    addGuideButton(hFigGuide, [0.04 0.08 0.14 0.09], 'Mark 0', ...
                   @(~, ~) annotateAndRefresh(obj, 'to_delete'));
    addGuideButton(hFigGuide, [0.20 0.08 0.14 0.09], 'Split', ...
                   @(~, ~) splitAndRefresh(obj));
    addGuideButton(hFigGuide, [0.36 0.08 0.14 0.09], 'Traces', ...
                   @(~, ~) obj.showTraces());
    addGuideButton(hFigGuide, [0.52 0.08 0.14 0.09], 'Multi', ...
                   @(~, ~) annotateAndRefresh(obj, 'multi'));
    addGuideButton(hFigGuide, [0.68 0.08 0.14 0.09], 'Single', ...
                   @(~, ~) annotateAndRefresh(obj, 'single'));
    addGuideButton(hFigGuide, [0.84 0.08 0.12 0.09], 'Refresh', ...
                   @(~, ~) obj.updateFigGuide());

    jrclust.utils.safeDrawnow();
end

function h = identity(h)
end

function addGuideButton(hFigGuide, pos, label, callback)
    uicontrol('Parent', hFigGuide.figApply(@identity), ...
              'Style', 'pushbutton', ...
              'Units', 'normalized', ...
              'Position', pos, ...
              'String', label, ...
              'Callback', callback);
end

function annotateAndRefresh(obj, note)
    obj.annotateUnit(note, 0);
    obj.updateFigGuide();
end

function splitAndRefresh(obj)
    obj.autoSplit(1);
    obj.updateFigGuide();
end

function guide = buildGuide(hClust, hCfg, iCluster)
    metrics = struct();
    metrics.nSpikes = getClusterCount(hClust, iCluster);
    metrics.centerSite = safeVectorValue(hClust, 'clusterSites', iCluster, nan);
    metrics.note = safeCellValue(hClust, 'clusterNotes', iCluster, '');
    metrics.unitISIRatio = safeVectorValue(hClust, 'unitISIRatio', iCluster, nan);
    metrics.unitVpp = safeVectorValue(hClust, 'unitVppRaw', iCluster, ...
        safeVectorValue(hClust, 'unitVpp', iCluster, nan));
    metrics.unitSNR = safeVectorValue(hClust, 'unitSNR', iCluster, nan);
    metrics.maxSimilarity = maxOtherSimilarity(hClust, iCluster);
    metrics.footprint = waveformFootprint(hClust, hCfg, iCluster);
    metrics.waveformCV = sampledWaveformCV(hClust, hCfg, iCluster);

    evidence = {};
    checklist = defaultChecklist();
    score = struct('artifact', 0, 'split', 0, 'multi', 0, 'good', 0, 'merge', 0);

    if metrics.footprint.nonLocal
        score.artifact = score.artifact + 3;
        evidence{end + 1} = sprintf('Large waveform components are outside the center-site neighborhood (%d non-neighbor site%s).', ...
                                    metrics.footprint.nNonNeighborSites, plural(metrics.footprint.nNonNeighborSites));
    end
    if metrics.footprint.nActiveSites >= 8
        score.artifact = score.artifact + 2;
        evidence{end + 1} = sprintf('Waveform footprint is broad (%d active sites above 25%% of peak).', metrics.footprint.nActiveSites);
    elseif metrics.footprint.nActiveSites >= 5
        score.multi = score.multi + 1;
        evidence{end + 1} = sprintf('Waveform footprint spans several sites (%d active sites).', metrics.footprint.nActiveSites);
    end

    if isfinite(metrics.unitISIRatio)
        if metrics.unitISIRatio >= 0.25
            score.multi = score.multi + 3;
            evidence{end + 1} = sprintf('High refractory/ISI violation ratio: %.3g.', metrics.unitISIRatio);
        elseif metrics.unitISIRatio >= 0.10
            score.multi = score.multi + 1;
            evidence{end + 1} = sprintf('Moderate refractory/ISI violation ratio: %.3g.', metrics.unitISIRatio);
        else
            score.good = score.good + 1;
        end
    end

    if isfinite(metrics.waveformCV)
        if metrics.waveformCV >= 0.55
            score.split = score.split + 2;
            evidence{end + 1} = sprintf('Sampled peak-to-peak amplitudes vary strongly (CV %.2f).', metrics.waveformCV);
        elseif metrics.waveformCV >= 0.35
            score.split = score.split + 1;
            evidence{end + 1} = sprintf('Sampled peak-to-peak amplitudes have moderate spread (CV %.2f).', metrics.waveformCV);
        else
            score.good = score.good + 1;
        end
    end

    if isfinite(metrics.maxSimilarity) && metrics.maxSimilarity >= hCfg.getOr('maxUnitSim', 0.98)
        score.merge = score.merge + 2;
        evidence{end + 1} = sprintf('Very similar to another unit (max waveform similarity %.3f).', metrics.maxSimilarity);
    end

    if isfinite(metrics.unitSNR) && metrics.unitSNR < 2
        score.artifact = score.artifact + 1;
        evidence{end + 1} = sprintf('Low SNR estimate: %.2f.', metrics.unitSNR);
    end
    if isfinite(metrics.unitVpp) && metrics.unitVpp < 25
        score.artifact = score.artifact + 1;
        evidence{end + 1} = sprintf('Small peak-to-peak amplitude: %.1f uV.', metrics.unitVpp);
    end
    if metrics.nSpikes < max(30, hCfg.getOr('minClusterSize', 30))
        score.artifact = score.artifact + 1;
        evidence{end + 1} = sprintf('Low spike count: %d.', metrics.nSpikes);
    else
        score.good = score.good + 1;
    end

    if isempty(evidence)
        evidence{1} = 'No strong warning sign from the quick rule checks.';
    end

    [category, action, confidence] = chooseGuideLabel(score, metrics);

    metricLines = {
        sprintf('Spikes: %d', metrics.nSpikes)
        sprintf('Center site: %s', valueText(metrics.centerSite))
        sprintf('Active sites: %d', metrics.footprint.nActiveSites)
        sprintf('ISI ratio: %s', valueText(metrics.unitISIRatio))
        sprintf('Waveform CV: %s', valueText(metrics.waveformCV))
        sprintf('Max similarity: %s', valueText(metrics.maxSimilarity))
        sprintf('Current note: %s', noteText(metrics.note))
        };

    guide.title = sprintf('Unit %d: %s (%s confidence)', iCluster, category, confidence);
    guide.text = strjoin([
        {sprintf('Suggested action: %s', action)}
        {''}
        {'Evidence:'}
        prefixLines(evidence, '- ')
        {''}
        {'Quick checks:'}
        prefixLines(checklist, '- ')
        {''}
        {'Metrics:'}
        prefixLines(metricLines, '- ')
        ], newline);
end

function [category, action, confidence] = chooseGuideLabel(score, metrics)
    confidence = 'low';
    if score.artifact >= 3
        category = 'likely artifact/noise';
        action = 'inspect raw traces, then mark 0 if non-local or non-spike-like';
        confidence = scoreConfidence(score.artifact);
    elseif score.split >= 2 && score.multi >= 1
        category = 'split candidate / possible multiunit';
        action = 'try Split, then compare ISI and waveform shape';
        confidence = scoreConfidence(score.split + score.multi);
    elseif score.split >= 2
        category = 'two-shape or noisy-tail candidate';
        action = 'try Split; keep the clean component if it remains local';
        confidence = scoreConfidence(score.split);
    elseif score.multi >= 2
        category = 'putative multiunit';
        action = 'try Split; if unresolved, annotate as multiunit';
        confidence = scoreConfidence(score.multi);
    elseif score.merge >= 2
        category = 'duplicate/merge candidate';
        action = 'inspect similarity and correlogram with the matching unit';
        confidence = scoreConfidence(score.merge);
    elseif score.good >= 3 && ~metrics.footprint.nonLocal
        category = 'likely good with possible minor noise';
        action = 'keep if traces, ISI, and feature plots remain clean';
        confidence = 'medium';
    else
        category = 'needs manual review';
        action = 'inspect waveform, feature projection, ISI, correlogram, and traces';
    end
end

function confidence = scoreConfidence(score)
    if score >= 4
        confidence = 'high';
    elseif score >= 2
        confidence = 'medium';
    else
        confidence = 'low';
    end
end

function checklist = defaultChecklist()
    checklist = {
        'Artifact/noise: broad or non-local footprint, saturated trace, no spike-like shape.'
        'Non-neighbor main waveform: if large components appear on separated sites, mark 0 after trace check.'
        'Two shapes: separated clouds or overlaid waveform families; split carefully.'
        'Multiunit: refractory violations or broad feature cloud that does not split cleanly.'
        'Good with noise: local stable waveform and clean ISI, with only a small outlier tail.'
        'Duplicate: high similarity to another unit; inspect correlogram before merging.'
        };
end

function lines = prefixLines(lines, prefix)
    lines = cellfun(@(s) [prefix, s], lines(:), 'UniformOutput', 0);
end

function txt = valueText(value)
    if isempty(value) || ~isfinite(value)
        txt = 'n/a';
    elseif abs(value - round(value)) < eps(value)
        txt = sprintf('%d', round(value));
    else
        txt = sprintf('%.3g', value);
    end
end

function txt = noteText(note)
    if isempty(note)
        txt = '(none)';
    else
        txt = note;
    end
end

function suffix = plural(n)
    if n == 1
        suffix = '';
    else
        suffix = 's';
    end
end

function nSpikes = getClusterCount(hClust, iCluster)
    nSpikes = safeVectorValue(hClust, 'unitCount', iCluster, nan);
    if ~isfinite(nSpikes) && isprop(hClust, 'spikesByCluster') && numel(hClust.spikesByCluster) >= iCluster
        nSpikes = numel(hClust.spikesByCluster{iCluster});
    end
    if ~isfinite(nSpikes)
        nSpikes = 0;
    end
end

function val = safeVectorValue(obj, fieldName, idx, defaultVal)
    val = defaultVal;
    if ~isprop(obj, fieldName)
        return;
    end
    x = obj.(fieldName);
    if numel(x) >= idx && ~isempty(x(idx))
        val = double(x(idx));
    end
end

function val = safeCellValue(obj, fieldName, idx, defaultVal)
    val = defaultVal;
    if ~isprop(obj, fieldName)
        return;
    end
    x = obj.(fieldName);
    if numel(x) >= idx && ~isempty(x{idx})
        val = x{idx};
    end
end

function maxSim = maxOtherSimilarity(hClust, iCluster)
    maxSim = nan;
    if ~isprop(hClust, 'waveformSim') || isempty(hClust.waveformSim)
        return;
    end
    sim = hClust.waveformSim(:, iCluster);
    if numel(sim) >= iCluster
        sim(iCluster) = nan;
    end
    sim = sim(isfinite(sim));
    if ~isempty(sim)
        maxSim = max(sim);
    end
end

function footprint = waveformFootprint(hClust, hCfg, iCluster)
    footprint = struct('nActiveSites', 0, 'nNonNeighborSites', 0, 'nonLocal', false);
    if ~isprop(hClust, 'meanWfGlobal') || isempty(hClust.meanWfGlobal)
        return;
    end

    wf = hClust.meanWfGlobal(:, :, iCluster);
    siteAmp = squeeze(max(wf, [], 1) - min(wf, [], 1));
    if isempty(siteAmp) || ~any(isfinite(siteAmp))
        return;
    end

    peakAmp = max(siteAmp);
    if peakAmp <= 0 || ~isfinite(peakAmp)
        return;
    end

    activeSites = find(siteAmp >= 0.25 * peakAmp);
    footprint.nActiveSites = numel(activeSites);

    centerSite = safeVectorValue(hClust, 'clusterSites', iCluster, nan);
    if ~isfinite(centerSite) || centerSite < 1 || centerSite > size(hCfg.siteNeighbors, 2)
        return;
    end

    neighbors = hCfg.siteNeighbors(:, centerSite);
    nonNeighborSites = setdiff(activeSites(:), neighbors(:));
    footprint.nNonNeighborSites = numel(nonNeighborSites);

    if footprint.nNonNeighborSites > 0
        footprint.nonLocal = true;
    elseif isprop(hCfg, 'siteLoc') && ~isempty(hCfg.siteLoc) && numel(activeSites) > 1
        loc = hCfg.siteLoc(activeSites, :);
        centerLoc = hCfg.siteLoc(centerSite, :);
        distFromCenter = sqrt(sum(bsxfun(@minus, loc, centerLoc) .^ 2, 2));
        footprint.nonLocal = any(distFromCenter > 2 * hCfg.getOr('evtMergeRad', 35));
    end
end

function cv = sampledWaveformCV(hClust, hCfg, iCluster)
    cv = nan;
    if ~isprop(hClust, 'spikesByCluster') || numel(hClust.spikesByCluster) < iCluster
        return;
    end

    iSpikes = hClust.spikesByCluster{iCluster};
    if numel(iSpikes) < 8
        return;
    end

    try
        iSpikes = jrclust.utils.subsample(iSpikes, min(60, numel(iSpikes)));
        centerSite = hClust.clusterSites(iCluster);
        iSites = hCfg.siteNeighbors(:, centerSite);
        waveforms = hClust.getSpikeWindows(iSpikes, iSites, 0, 1);
        vpp = squeeze(max(waveforms, [], 1) - min(waveforms, [], 1));
        if ismatrix(vpp)
            vpp = max(vpp, [], 1);
        end
        vpp = double(vpp(:));
        vpp = vpp(isfinite(vpp) & vpp > 0);
        if numel(vpp) >= 5
            cv = std(vpp) / max(mean(vpp), eps);
        end
    catch
        cv = nan;
    end
end
