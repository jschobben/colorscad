cmake_minimum_required(VERSION 3.14...3.28)

# ─────────────────────────────────────────────────────────────────────────────
#  AUTO-BOOTSTRAP VCPKG & SET TOOLCHAIN
# ─────────────────────────────────────────────────────────────────────────────

# Path to the vcpkg submodule
set(VCPKG_DIR "${CMAKE_SOURCE_DIR}/vcpkg")

# Only proceed if the vcpkg toolchain file is present
if(EXISTS "${VCPKG_DIR}/scripts/buildsystems/vcpkg.cmake")

    # Bootstrap vcpkg once if the executable is missing
    if(NOT EXISTS "${VCPKG_DIR}/vcpkg" AND NOT EXISTS "${VCPKG_DIR}/vcpkg.exe")
        message(STATUS "Bootstrapping vcpkg in ${VCPKG_DIR}...")
        execute_process(
                COMMAND ${CMAKE_COMMAND}
                -P "${VCPKG_DIR}/scripts/buildsystems/bootstrap.cmake"
                WORKING_DIRECTORY "${VCPKG_DIR}"
                RESULT_VARIABLE _vcpkg_bootstrap_result
                OUTPUT_QUIET
                ERROR_QUIET
        )
        if(NOT _vcpkg_bootstrap_result EQUAL 0)
            message(FATAL_ERROR
                    "vcpkg bootstrap failed (exit code ${_vcpkg_bootstrap_result})")
        endif()
        message(STATUS "vcpkg bootstrapped successfully")
    endif()

    # Tell CMake to use the vcpkg toolchain for all find_package() calls
    set(CMAKE_TOOLCHAIN_FILE
            "${VCPKG_DIR}/scripts/buildsystems/vcpkg.cmake"
            CACHE STRING "Vcpkg toolchain file" FORCE)

else()
    message(FATAL_ERROR
            "Could not find vcpkg toolchain file in ${VCPKG_DIR}/scripts/buildsystems")
endif()

# ─────────────────────────────────────────────────────────────────────────────
#  PROJECT DEFINITION
# ─────────────────────────────────────────────────────────────────────────────

project(colorscad LANGUAGES CXX)

add_subdirectory(3mfmerge)

install(
        PROGRAMS colorscad.sh
        RENAME  colorscad
        DESTINATION bin
)