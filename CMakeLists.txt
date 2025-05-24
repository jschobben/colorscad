cmake_minimum_required(VERSION 3.14...3.28)

# Set the path to vcpkg submodule
set(VCPKG_DIR "${CMAKE_SOURCE_DIR}/vcpkg")

# Bootstrap vcpkg if needed
if (NOT EXISTS "${VCPKG_DIR}/vcpkg")
    message(STATUS "Bootstrapping vcpkg...")
    if (UNIX)
        execute_process(
                COMMAND ${CMAKE_COMMAND} -E env bash "${VCPKG_DIR}/bootstrap-vcpkg.sh"
                WORKING_DIRECTORY ${VCPKG_DIR}
        )
    elseif (WIN32)
        execute_process(
                COMMAND "${VCPKG_DIR}/bootstrap-vcpkg.bat"
                WORKING_DIRECTORY ${VCPKG_DIR}
        )
    endif()
endif()

# Set vcpkg toolchain file for CMake to use
if (EXISTS "${VCPKG_DIR}/scripts/buildsystems/vcpkg.cmake")
    set(CMAKE_TOOLCHAIN_FILE "${VCPKG_DIR}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
else()
    message(FATAL_ERROR "vcpkg failed to bootstrap or install packages.")
endif()

project(colorscad)
add_subdirectory(3mfmerge)

install(PROGRAMS colorscad.sh RENAME colorscad DESTINATION bin)