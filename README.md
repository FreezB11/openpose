# OpenPose — community continuation

OpenPose is a real-time system for detecting the 2D keypoints of people in images and
video: body, feet, face and hands. It was created by researchers at Carnegie Mellon
University, and the upstream repository is no longer maintained.

**This repository is an independent, personal continuation of that project.** It exists to
keep OpenPose buildable and usable on current systems for the people who still need it.
It is not affiliated with, or endorsed by, Carnegie Mellon University or the original
authors.

## Credit

All of the algorithms, the original code and the trained models are the work of the
OpenPose authors — **Zhe Cao, Gines Hidalgo, Tomas Simon, Shih-En Wei and Yaser Sheikh**
— together with the many contributors to the upstream project. This fork only maintains
and modernizes what they built.

- Upstream project: <https://github.com/CMU-Perceptual-Computing-Lab/openpose>
- The authors' original README, with their figures and full contributor list, is kept in
  [`doc/ORIGINAL_README.md`](doc/ORIGINAL_README.md).

If you use OpenPose in research, please cite the authors' papers:

- Z. Cao, G. Hidalgo, T. Simon, S.-E. Wei, Y. Sheikh. *OpenPose: Realtime Multi-Person 2D
  Pose Estimation using Part Affinity Fields.* IEEE TPAMI, 2019 (arXiv:1812.08008).
- Z. Cao, T. Simon, S.-E. Wei, Y. Sheikh. *Realtime Multi-Person 2D Pose Estimation using
  Part Affinity Fields.* CVPR, 2017.
- T. Simon, H. Joo, I. Matthews, Y. Sheikh. *Hand Keypoint Detection in Single Images using
  Multiview Bootstrapping.* CVPR, 2017.
- S.-E. Wei, V. Ramakrishna, T. Kanade, Y. Sheikh. *Convolutional Pose Machines.* CVPR, 2016.

## License

OpenPose is licensed for **academic and non-profit, non-commercial research use only**
(see [`LICENSE`](LICENSE)); commercial use requires a separate license from Carnegie Mellon
University. Changes in this fork stay under that same license. The trained weights are
covered by it too.

**This repository does not host any model weights.** [`models/model_sources.txt`](models/model_sources.txt)
only lists places where they have been published, and `models/getModels.sh` fetches them
from there.

## Current status

Honest summary of what has and has not been verified:

| Component | State |
| --- | --- |
| New CMake build, CPU, GCC 13 | Builds the library and all 20 example binaries with no errors (tested on Ubuntu 24.04, OpenCV 4.6, CMake 3.28). |
| CUDA kernels | All 9 `.cu` files compile unchanged with CUDA 12.0 for `sm_86` (RTX 30-series). **Compile-checked only: never run on a GPU yet.** |
| Arch Linux | The instructions below are the intended path but have **not** been tested on Arch yet. |
| Running pose estimation | **Not working yet.** The library needs a network backend and none is wired in. The demo starts, then stops with a clear "no backend" message. |
| Python bindings | Not part of the new build yet. |
| Windows, macOS, OpenCL, 3D/Ceres, FLIR, Unity | Dropped from the new build. |

## Building (Arch Linux)

```sh
sudo pacman -S --needed base-devel cmake ninja opencv gflags
git clone <this repository> openpose && cd openpose

cmake -S . -B build -G Ninja -DOP_GPU_MODE=CPU
cmake --build build
```

For CUDA (for example an RTX 3050 is `sm_86`):

```sh
sudo pacman -S --needed cuda
cmake -S . -B build -G Ninja -DOP_GPU_MODE=CUDA -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build build
```

If `nvcc` rejects your default compiler as too new, install an older `gcc` package and add
`-DCMAKE_CUDA_HOST_COMPILER=/path/to/that/g++`. See [`doc/BUILDING.md`](doc/BUILDING.md)
for every option.

Binaries are written to `build/bin/` (`openpose.bin` is the main demo).

## Models

```sh
models/getModels.sh            # body25 + face + hand
models/getModels.sh --all      # also coco and mpi
```

The original host has been unreliable, so open `models/model_sources.txt` and add a mirror
you trust (with its SHA-256 if you have it). The script tries mirrors in order and verifies
checksums when they are listed.

## Roadmap

1. Make `ArrayCpuGpu` standalone so the data path no longer depends on `caffe::Blob`.
2. Add an OpenCV DNN network backend that loads the existing `.prototxt` / `.caffemodel`
   files directly, with no model conversion and no Caffe.
3. GPU inference through that backend, then validate accuracy against the old results.
4. Python bindings through `find_package(pybind11)`.
5. Continuous integration on current runners.
6. Triage and fix the issues still open upstream.

## Contributing

Issues and pull requests are welcome. Please do not attach model weights to issues or pull
requests.
