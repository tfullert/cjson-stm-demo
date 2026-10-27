cmake_minimum_required(VERSION 3.24)
project(cjson_stm_demo VERSION 1.0.0 LANGUAGES C)

# DEMO CHANGE: replace 1.7.16 with 1.7.17, then configure and rebuild.
set(CJSON_VERSION "1.7.16")

include(FetchContent)
FetchContent_Declare(cjson
    GIT_REPOSITORY https://github.com/DaveGamble/cJSON.git
    GIT_TAG "v${CJSON_VERSION}"
    GIT_SHALLOW TRUE
    # Fetch the release but use our static-library target below. This avoids
    # depending on the historical release's own CMake policies and options.
    SOURCE_SUBDIR demo-uses-source-files-only
)
FetchContent_MakeAvailable(cjson)

add_library(cjson_demo_dependency STATIC "${cjson_SOURCE_DIR}/cJSON.c")
target_include_directories(cjson_demo_dependency PUBLIC "${cjson_SOURCE_DIR}")
target_compile_definitions(cjson_demo_dependency PUBLIC CJSON_HIDE_SYMBOLS)
if(UNIX)
    target_link_libraries(cjson_demo_dependency PUBLIC m)
endif()

add_executable(cjson-demo src/main.c)
target_link_libraries(cjson-demo PRIVATE cjson_demo_dependency)
target_compile_features(cjson-demo PRIVATE c_std_99)
if(MSVC)
    # Statically link the MSVC runtime as well, for a portable demo executable.
    set_property(TARGET cjson_demo_dependency cjson-demo PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    target_compile_options(cjson-demo PRIVATE /W4)
else()
    target_compile_options(cjson-demo PRIVATE -Wall -Wextra -Wpedantic)
endif()

file(WRITE "${CMAKE_BINARY_DIR}/dependency-version.txt" "${CJSON_VERSION}\n")
include(CTest)
if(BUILD_TESTING)
    add_test(NAME normal-setting COMMAND cjson-demo --normal)
    set_tests_properties(normal-setting PROPERTIES
        PASS_REGULAR_EXPRESSION "RESULT: normal update succeeded")
endif()
message(STATUS "Demo dependency: cJSON ${CJSON_VERSION} (CVE-2023-50472)")
