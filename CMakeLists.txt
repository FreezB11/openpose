cmake_minimum_required(VERSION 3.20)

project(OpenPose
    VERSION 1.7.0
    DESCRIPTION "Real-time multi-person keypoint detection (community-maintained continuation)"
    LANGUAGES CXX)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# ------------------------------------------------------------------------------
# Options
# ------------------------------------------------------------------------------
set(OP_GPU_MODE "CPU" CACHE STRING "Acceleration used for rendering and post-processing: CPU or CUDA.")
set_property(CACHE OP_GPU_MODE PROPERTY STRINGS CPU CUDA)

set(OP_DL_BACKEND "NONE" CACHE STRING
    "Network inference backend: NONE (builds everything, but cannot run a network) or CAFFE (legacy, needs a Caffe build).")
set_property(CACHE OP_DL_BACKEND PROPERTY STRINGS NONE CAFFE)

option(OP_BUILD_EXAMPLES "Build the demo and the C++ tutorial examples." ON)
option(OP_ENABLE_AVX "Compile the AVX+FMA code paths (x86-64 only; needs a CPU from 2013 or newer)." ON)
option(OP_PROFILER "Print speed information at runtime." OFF)
option(BUILD_SHARED_LIBS "Build libopenpose as a shared library." ON)

if (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif ()

# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------
find_package(Threads REQUIRED)

find_package(OpenCV REQUIRED COMPONENTS
    core imgproc imgcodecs highgui videoio video calib3d objdetect)

find_package(gflags CONFIG QUIET)
if (NOT TARGET gflags::gflags AND NOT TARGET gflags)
    find_path(GFLAGS_INCLUDE_DIR gflags/gflags.h)
    find_library(GFLAGS_LIBRARY gflags)
    if (NOT GFLAGS_INCLUDE_DIR OR NOT GFLAGS_LIBRARY)
        message(FATAL_ERROR "gflags not found. Install it (Arch: `pacman -S gflags`).")
    endif ()
    add_library(gflags::gflags UNKNOWN IMPORTED)
    set_target_properties(gflags::gflags PROPERTIES
        IMPORTED_LOCATION "${GFLAGS_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${GFLAGS_INCLUDE_DIR}")
elseif (NOT TARGET gflags::gflags)
    add_library(gflags::gflags ALIAS gflags)
endif ()

# ------------------------------------------------------------------------------
# Library sources
# ------------------------------------------------------------------------------
file(GLOB_RECURSE OP_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/openpose/*.cpp")
# OpenCL support was dropped (it only ever worked with the old Caffe/Greentea fork).
list(FILTER OP_SOURCES EXCLUDE REGEX "(/opencl\\.cpp|CL\\.cpp)$")

add_library(openpose ${OP_SOURCES})
add_library(OpenPose::openpose ALIAS openpose)

target_include_directories(openpose PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_compile_features(openpose PUBLIC cxx_std_17)
target_link_libraries(openpose PUBLIC ${OpenCV_LIBS} gflags::gflags Threads::Threads)
set_target_properties(openpose PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    POSITION_INDEPENDENT_CODE ON)

if (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(openpose PRIVATE -Wall -Wextra)
endif ()

if (OP_ENABLE_AVX AND CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    target_compile_definitions(openpose PUBLIC WITH_AVX)
    # The intrinsics in the code are AVX (_mm256_dp_ps, ...) plus FMA (_mm256_fmadd_ps); no AVX2.
    target_compile_options(openpose PUBLIC -mavx -mfma)
endif ()

if (OP_PROFILER)
    target_compile_definitions(openpose PUBLIC PROFILER_ENABLED)
endif ()

# ------------------------------------------------------------------------------
# GPU mode
# ------------------------------------------------------------------------------
if (OP_GPU_MODE STREQUAL "CUDA")
    enable_language(CUDA)
    find_package(CUDAToolkit REQUIRED)

    if (NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
        # "native" needs CMake >= 3.24; otherwise fall back to Turing + Ampere.
        if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.24)
            set(CMAKE_CUDA_ARCHITECTURES native)
        else ()
            set(CMAKE_CUDA_ARCHITECTURES 75 86)
        endif ()
    endif ()
    set(CMAKE_CUDA_STANDARD 17)
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)

    file(GLOB_RECURSE OP_CUDA_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/openpose/*.cu")
    target_sources(openpose PRIVATE ${OP_CUDA_SOURCES})
    target_compile_definitions(openpose PUBLIC USE_CUDA)
    target_link_libraries(openpose PUBLIC CUDA::cudart)
elseif (OP_GPU_MODE STREQUAL "CPU")
    # CPU_ONLY is the macro the legacy Caffe headers look for; USE_CPU_ONLY is OpenPose's own.
    target_compile_definitions(openpose PUBLIC USE_CPU_ONLY CPU_ONLY)
else ()
    message(FATAL_ERROR "OP_GPU_MODE must be CPU or CUDA (got '${OP_GPU_MODE}').")
endif ()

# ------------------------------------------------------------------------------
# Network backend
# ------------------------------------------------------------------------------
if (OP_DL_BACKEND STREQUAL "CAFFE")
    # Legacy path. Needs a Caffe build that exports its headers and libcaffe, plus
    # Boost, glog and protobuf. It is not exercised by the maintainers' CI.
    find_package(Caffe REQUIRED)
    find_package(Boost REQUIRED COMPONENTS system filesystem thread)
    find_package(glog CONFIG REQUIRED)
    find_package(Protobuf REQUIRED)
    target_compile_definitions(openpose PUBLIC USE_CAFFE)
    target_include_directories(openpose PUBLIC ${Caffe_INCLUDE_DIRS})
    target_link_libraries(openpose PUBLIC ${Caffe_LIBS} Boost::system Boost::filesystem Boost::thread
        glog::glog protobuf::libprotobuf)
elseif (NOT OP_DL_BACKEND STREQUAL "NONE")
    message(FATAL_ERROR "OP_DL_BACKEND must be NONE or CAFFE (got '${OP_DL_BACKEND}').")
else ()
    message(WARNING
        "OP_DL_BACKEND=NONE: the library builds, but no network backend is available, "
        "so pose estimation cannot run yet.")
endif ()

# ------------------------------------------------------------------------------
# Examples
# ------------------------------------------------------------------------------
if (OP_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif ()

# ------------------------------------------------------------------------------
# Install + package config
# ------------------------------------------------------------------------------
install(TARGETS openpose
    EXPORT OpenPoseTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY include/openpose DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT OpenPoseTargets
    NAMESPACE OpenPose::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/OpenPose)

configure_package_config_file(
    cmake/OpenPoseConfig.cmake.in
    "${CMAKE_CURRENT_BINARY_DIR}/OpenPoseConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/OpenPose)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/OpenPoseConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)
install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/OpenPoseConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/OpenPoseConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/OpenPose)
