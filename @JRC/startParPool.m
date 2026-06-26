function startParPool(obj)
    %STARTPARPOOL Start the parallel pool
    if ~obj.hCfg.useParfor || ~isempty(gcp('nocreate'))
        return;
    end

    try
        nWorkers = obj.hCfg.getOr('nWorkersParfor', []);
        if isempty(nWorkers)
            parpool('Processes');
        else
            parpool('Processes', nWorkers);
        end
    catch ME
        warning('JRCLUST:ParallelPoolStartFailed', ...
                'JRCLUST could not start a parallel pool: %s', ME.message);
    end
end
