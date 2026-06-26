# JRCLUST

## Note

**JRCLUST is no longer being actively maintained by the original maintainers.**

This fork modernizes JRCLUST for newer CUDA/MATLAB environments while keeping the original MATLAB workflow and file layout. It is intended for users who still rely on JRCLUST for spike sorting and manual curation on high-density silicon probes.

JRCLUST is a scalable and customizable package for spike sorting on [high-density silicon probes](https://www.nature.com/articles/nature24636). It is written in MATLAB and CUDA.

JRCLUST was originally developed by [James Jun](https://www.simonsfoundation.org/team/james-jun/). The original repository is available at [JaneliaSciComp/JRCLUST](https://github.com/JaneliaSciComp/JRCLUST).

## What This Fork Adds

This fork includes updates for newer GPU and MATLAB environments:

- CUDA compilation support for CUDA 12 and modern NVIDIA GPUs.
- CUDA kernel launch settings adjusted for Ada-generation GPUs.
- PTX kernels regenerated for `compute_89`.
- Manual curation recomputation can use MATLAB parallel workers.
- Manual split dialog includes a density-peak clustering option with CUDA support where available.
- Trace spike coloring follows cluster waveform colors.
- MATLAB R2025a/R2025b GUI compatibility improvements.
- Trace rendering is capped/downsampled for responsive remote GUI sessions.

## Tested Environment

This fork has been tested on:

- MATLAB R2025b on Linux
- NVIDIA RTX A4500 / Ada-generation GPU
- CUDA 12.8
- GPU compute capability 8.9

Other CUDA-capable NVIDIA GPUs may work, but you should compile PTX for the matching compute capability.

## Installing JRCLUST

Clone this repository:

```bash
git clone https://github.com/<your-github-username>/JRCLUST.git
cd JRCLUST
git checkout cuda12-ada-matlab2025-gui
```

In MATLAB, add JRCLUST to the path:

```matlab
addpath('/path/to/JRCLUST');
```

You may want to place that line in your MATLAB [`startup.m`](https://www.mathworks.com/help/matlab/ref/startup.html).

## CUDA Setup

For Ada-generation GPUs such as RTX A4500, select the GPU and compile CUDA kernels for `compute_89`:

```matlab
gpuDevice(1)
jrclust.CUDA.compileCUDA('compute_89')
```

If your machine has multiple GPUs, `gpuDevice(1)` selects GPU 1 for future MATLAB GPU operations in the current session. Use `gpuDevice(2)` to select GPU 2.

To check the currently selected GPU:

```matlab
g = gpuDevice;
disp(g.Name)
disp(g.ComputeCapability)
```

If using a different NVIDIA GPU, compile with the matching compute target. For example:

```matlab
jrclust.CUDA.compileCUDA('compute_86')
```

For systems where the CUDA toolkit is installed outside MATLAB, make sure `compileCUDA.m` can find `nvcc`, commonly at:

```text
/usr/local/cuda/bin/nvcc
```

## Recommended Parameters

For CUDA-enabled sorting and manual curation:

```matlab
useGPU = 1;
useParfor = 1;
nWorkersParfor = 8;
```

For MATLAB R2025a/R2025b GUI sessions, especially over remote desktop or software WebGL rendering:

```matlab
modernGuiMode = 1;
modernFigList = {'FigWav', 'FigSim', 'FigProj', 'FigTime', 'FigISI', 'FigCorr', 'FigHist'};
useModernROI = 1;

showSpikesTraces = 0;
maxSpikesTraces = 300;
showTraceProgressBox = 0;
nSkip = 10;
dispTimeLimits = [0, 0.05];
```

The trace window opens faster with spike overlays off. Press `[S]` inside the trace window to toggle colored spike overlays.

For a more detailed trace inspection, temporarily reduce `nSkip`:

```matlab
nSkip = 5;
```

For a wider trace time view, increase `dispTimeLimits`:

```matlab
dispTimeLimits = [0, 0.1];
```

Avoid `nSkip = 1` with large channel-count recordings under software WebGL unless the time window is very short.

## Typical Usage

Run spike detection and sorting:

```matlab
gpuDevice(1)
jrc detect-sort /path/to/recording.prm
```

Open manual curation:

```matlab
gpuDevice(1)
jrc manual /path/to/recording.prm
```

Open the trace viewer from the manual curation window:

```text
View > Show traces
```

Inside the trace viewer:

- `[S]` toggles colored spike overlays.
- `[F]` toggles filtering.
- `[G]` toggles the grid.
- Arrow keys move through time.
- Up/down arrows change trace scale.

## MATLAB GUI Notes

CUDA GPU computation and MATLAB GUI rendering are separate. On some remote Linux sessions, MATLAB R2025b may report WebGL/SwiftShader software rendering, for example:

```text
GraphicsRenderer: WebGL
RendererDevice: ANGLE ... SwiftShader
```

Sorting can still use the NVIDIA GPU through CUDA, but GUI windows may need lighter display settings such as:

```matlab
modernGuiMode = 1;
nSkip = 10;
maxSpikesTraces = 300;
```

If the manual GUI is slow or unstable, first check:

```matlab
rendererinfo
usejava('desktop')
usejava('awt')
getenv('DISPLAY')
```

Manual curation requires a graphical MATLAB session. It will not work properly from:

```bash
matlab -nodisplay
matlab -batch
matlab -nojvm
```

Use a real graphical session such as VNC, NoMachine, Open OnDemand, or SSH X11 forwarding.

## Test Data

During development, CUDA and CPU agreement were tested using the public JRCLUST test data from the JRCLUST test-data repository, including the sample dataset used with:

```text
JRCLUST-testdata/sample/sample.prm
```

In that test, GPU and CPU `detect-sort` produced matching spike and cluster counts, matching final clusters, and rho/delta differences within expected single-precision tolerance.

## Questions?

Original JRCLUST documentation is available here:

https://jrclust.readthedocs.io/en/latest/index.html

Original JRCLUST repository:

https://github.com/JaneliaSciComp/JRCLUST

Original JRCLUST releases:

https://github.com/JaneliaSciComp/JRCLUST/releases
