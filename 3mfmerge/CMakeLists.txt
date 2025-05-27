cmake_minimum_required(VERSION 3.14...3.28)
project(3mfmerge LANGUAGES CXX)

# Output binaries into ./bin (all configurations)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/bin)

# Enforce C++11
set(CMAKE_CXX_STANDARD      11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS    OFF)

# Find lib3mf (installed via vcpkg manifest in the superproject)
find_package(lib3mf CONFIG REQUIRED)

# Build
add_executable(${PROJECT_NAME}
        3mfmerge.cpp
)
target_link_libraries(${PROJECT_NAME}
        PRIVATE lib3mf::lib3mf
)

# Install
install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION bin
)

# Copy lib3mf’s runtime libraries alongside the executable
copy_lib3mf_libraries(${PROJECT_NAME})