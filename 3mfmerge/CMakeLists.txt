cmake_minimum_required(VERSION 3.5)

project(3mfmerge)
set(CMAKE_CXX_STANDARD 11)
add_executable(3mfmerge "${CMAKE_CURRENT_SOURCE_DIR}/3mfmerge.cpp")
find_library(LIB3MF_LOCATION 3mf)
find_path(LIB3MF_CPP_BINDINGS_DIR NAMES lib3mf_implicit.hpp PATH_SUFFIXES include/Bindings/Cpp)
target_link_libraries(3mfmerge ${LIB3MF_LOCATION})
target_include_directories(3mfmerge PRIVATE "${LIB3MF_CPP_BINDINGS_DIR}")
