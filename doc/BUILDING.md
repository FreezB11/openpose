# Building

## Requirements

| Needed for | Package (Arch) | Notes |
| --- | --- | --- |
| Always | `base-devel cmake ninja` | CMake 3.20 or newer, a C++17 compiler. |
| Always | `opencv` | Components used: core, imgproc, imgcodecs, highgui, videoio, video, calib3d, objdetect. |
| Always | `gflags` | Found through its CMake config, or `find_library` as a fallback. |
| `OP_GPU_MODE=CUDA` | `cuda` | CUDA 11.x or newer. Verified compile-only with CUDA 12.0. |
| `OP_DL_BACKEND=CAFFE` | a Caffe build, `boost`, `google-glog`, `protobuf` | Legacy path, untested. |

## CMake options

| Option | Default | Meaning |
| --- | --- | --- |
| `OP_GPU_MODE` | `CPU` | `CPU` or `CUDA`. CUDA covers the rendering and post-processing kernels. |
| `OP_DL_BACKEND` | `NONE` | `NONE` builds everything but cannot run a network. `CAFFE` links an external Caffe (legacy). |
| `OP_BUILD_EXAMPLES` | `ON` | Builds the demo, the calibration tool and the C++ tutorials into `<build>/bin`. |
| `OP_ENABLE_AVX` | `ON` | AVX+FMA code paths (x86-64, CPUs from 2013 on). Turn off for older CPUs. |
| `OP_PROFILER` | `OFF` | Print timing information at runtime. |
| `BUILD_SHARED_LIBS` | `ON` | Shared or static `libopenpose`. |
| `CMAKE_CUDA_ARCHITECTURES` | `native` (CMake 3.24+) | Set explicitly (for example `86`) when no GPU is visible at configure time. |

## Using the library from another project

```cmake
find_package(OpenPose REQUIRED)
target_link_libraries(my_app PRIVATE OpenPose::openpose)
```

Install with `cmake --install build --prefix <dir>`.

## Troubleshooting

- **"OpenPose must be compiled with the USE_CAFFE macro"** at runtime: expected for now,
  because no network backend is wired in (see the roadmap in the README).
- **nvcc complains about the host compiler version:** pass `-DCMAKE_CUDA_HOST_COMPILER=<older g++>`.
- **CMake cannot find gflags:** install your distribution's gflags development package.
