# Every example is a single .cpp linked against the openpose library.
# Binaries keep the historical "<name>.bin" naming and land in <build>/bin.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")

function(op_add_example target source output_name)
    add_executable(${target} ${source})
    target_link_libraries(${target} PRIVATE openpose)
    set_target_properties(${target} PROPERTIES OUTPUT_NAME ${output_name})
endfunction()

# Main demo
op_add_example(openpose_demo openpose/openpose.cpp openpose.bin)

# Camera calibration tool
op_add_example(openpose_calibration calibration/calibration.cpp calibration.bin)

# C++ API tutorials (01_..., 02_..., ...)
file(GLOB OP_TUTORIAL_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/tutorial_api_cpp/*.cpp")
foreach (source IN LISTS OP_TUTORIAL_SOURCES)
    get_filename_component(name ${source} NAME_WE)
    op_add_example(tutorial_${name} ${source} ${name}.bin)
endforeach ()
