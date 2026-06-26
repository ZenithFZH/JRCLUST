function success = compileCUDA(nvccPath, cudaArch)
    %COMPILECUDA Compile CUDA codes for JRCLUST
    %
    % Compile architecture-specific PTX with nvcc. MATLAB's mexcuda -ptx
    % can inject a default -gencode option that conflicts with explicit
    % -arch targets on recent releases.
    gpuD = gpuDevice(1);

    if nargin < 1
        nvccPath = '';
    end

    if nargin < 2
        cudaArch = localComputeArch(gpuD);
    else
        cudaArch = localNormalizeArch(cudaArch);
    end

    if isempty(nvccPath)
        nvccPath = localFindNvcc(gpuD);
    elseif startsWith(nvccPath, 'compute_') || startsWith(nvccPath, 'sm_')
        % Allow jrclust.CUDA.compileCUDA('compute_89') as shorthand.
        cudaArch = localNormalizeArch(nvccPath);
        nvccPath = localFindNvcc(gpuD);
    end

    basedir = fullfile(jrclust.utils.basedir(), '+jrclust', '+CUDA');
    cudaFiles = dir(fullfile(basedir, '*.cu'));
    cudaFiles = {cudaFiles.name};
    cudaInclude = localFindCudaInclude(nvccPath);

    t1 = tic;
    fprintf('Compiling CUDA codes for %s...\n', cudaArch);
    success = 1;

    startDir = pwd();
    cleanupObj = onCleanup(@() cd(startDir));
    cd(basedir);

    for i = 1:numel(cudaFiles)
        iFileCU = fullfile(basedir, cudaFiles{i});
        iFilePTX = fullfile(basedir, strrep(cudaFiles{i}, '.cu', '.ptx'));

        cmd = sprintf('"%s" -ptx -m 64 -arch=%s -I"%s" "%s" --output-file "%s"', nvccPath, cudaArch, cudaInclude, iFileCU, iFilePTX);
        fprintf('\t%s\n\t', cmd);

        try
            status = system(cmd);
        catch ME
            status = 1;
            warning('Could not compile %s with nvcc: %s\n', iFileCU, ME.message);
        end

        success = success && (status == 0);
    end

    if ~success
        warning('CUDA could not be compiled for %s but JRCLUST may work using CPU fallbacks.\n', cudaArch);
    end

    fprintf('Finished compiling, took %0.1fs\n', toc(t1));
end

function cudaArch = localComputeArch(gpuD)
    if isprop(gpuD, 'ComputeCapability')
        cc = strrep(char(gpuD.ComputeCapability), '.', '');
        cudaArch = sprintf('compute_%s', cc);
    else
        cudaArch = 'compute_86';
    end
end

function cudaArch = localNormalizeArch(cudaArch)
    cudaArch = char(cudaArch);
    cudaArch = strrep(cudaArch, '.', '');

    if startsWith(cudaArch, 'sm_')
        cudaArch = ['compute_', extractAfter(cudaArch, 'sm_')];
    elseif ~startsWith(cudaArch, 'compute_')
        cudaArch = ['compute_', cudaArch];
    end
end

function nvccPath = localFindNvcc(gpuD)
    mwNvccPath = getenv('MW_NVCC_PATH');
    if ~isempty(mwNvccPath)
        nvccPath = fullfile(mwNvccPath, 'nvcc');
        if exist(nvccPath, 'file') == 2
            return;
        end
    end

    cudaHome = getenv('CUDA_HOME');
    if ~isempty(cudaHome)
        nvccPath = fullfile(cudaHome, 'bin', 'nvcc');
        if exist(nvccPath, 'file') == 2
            return;
        end
    end

    cudaPath = getenv('CUDA_PATH');
    if ~isempty(cudaPath)
        nvccPath = fullfile(cudaPath, 'bin', 'nvcc');
        if exist(nvccPath, 'file') == 2
            return;
        end
    end

    if ispc()
        nvccPath = sprintf('C:\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\v%0.1f\\bin\\nvcc.exe', gpuD.ToolkitVersion);
        return;
    end

    nvccPath = '/usr/local/cuda/bin/nvcc';
    if exist(nvccPath, 'file') == 2
        return;
    end

    nvccPath = sprintf('/usr/local/cuda-%0.1f/bin/nvcc', gpuD.ToolkitVersion);
    if exist(nvccPath, 'file') == 2
        return;
    end

    [ecode, out] = system('which nvcc');
    if ecode == 0
        nvccPath = strip(out);
    else
        bundledNvcc = fullfile(matlabroot(), 'sys', 'cuda', 'glnxa64', 'cuda', 'bin', 'nvcc');
        if exist(bundledNvcc, 'file') == 2
            nvccPath = bundledNvcc;
        else
            nvccPath = '/usr/local/cuda/bin/nvcc';
        end
    end
end

function cudaInclude = localFindCudaInclude(nvccPath)
    nvccDir = fileparts(nvccPath);
    cudaInclude = fullfile(fileparts(nvccDir), 'include');
    if exist(fullfile(cudaInclude, 'cuda_runtime.h'), 'file') == 2
        return;
    end

    cudaHome = getenv('CUDA_HOME');
    if ~isempty(cudaHome)
        cudaInclude = fullfile(cudaHome, 'include');
        if exist(fullfile(cudaInclude, 'cuda_runtime.h'), 'file') == 2
            return;
        end
    end

    cudaPath = getenv('CUDA_PATH');
    if ~isempty(cudaPath)
        cudaInclude = fullfile(cudaPath, 'include');
        if exist(fullfile(cudaInclude, 'cuda_runtime.h'), 'file') == 2
            return;
        end
    end

    cudaInclude = '/usr/local/cuda/include';
    if exist(fullfile(cudaInclude, 'cuda_runtime.h'), 'file') == 2
        return;
    end

    bundledInclude = fullfile(matlabroot(), 'sys', 'cuda', computer('arch'), 'cuda', 'include');
    if exist(fullfile(bundledInclude, 'cuda_runtime.h'), 'file') == 2
        cudaInclude = bundledInclude;
    end
end
