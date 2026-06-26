function spawnFigures(obj)
    %SPAWNFIGURES Create the standard cadre of figures
    obj.hFigs = containers.Map();
    figList = obj.hCfg.figList;
    figPos = obj.hCfg.figPos;

    if obj.hCfg.getOr('modernGuiMode', 0)
        modernFigList = obj.hCfg.getOr('modernFigList', ...
            {'FigWav', 'FigSim', 'FigProj', 'FigTime', 'FigISI', 'FigCorr', 'FigHist'});
        keepFig = ismember(figList, modernFigList);
        keepFig = keepFig | ismember(figList, {'FigWav'});
        figList = figList(keepFig);
        figPos = figPos(keepFig);
    end

    for f=1:length(figList)
        figTag = figList{f};
        figToolbar = 0;
        figMenubar = 0;
        switch figTag
            case 'FigPos'
                figTitle = 'Unit position';
                figToolbar = 1;
            case 'FigMap'
                figTitle = 'Probe map';
                figToolbar = 1;
            case 'FigWav'
                figTitle = 'Averaged waveform';
                figMenubar = 1;
            case 'FigTime'
                figTitle = 'Feature vs. time';
            case 'FigProj'
                figTitle = 'Feature projection';
            case 'FigSim'
                figTitle = 'Template-based similarity score';                                    
            case 'FigHist'
                figTitle = 'ISI histogram';                
            case 'FigISI'
                figTitle = 'Return map';                
            case 'FigCorr'
                figTitle = 'Time correlation';                
            case 'FigRD'
                if isa(obj.hClust,'jrclust.sort.TemplateClustering')
                    warning('Skipping spawning of rho-delta plot because density-peak clustering was not used.');
                    continue
                end
                figTitle = 'Unit rho-delta';                
        end
        obj.hFigs(figTag) = jrclust.views.Figure(figTag,figPos{f},sprintf('%s: %s',figTitle,obj.hCfg.sessionName),figToolbar,figMenubar);
        jrclust.utils.safeDrawnow();
    end
end
