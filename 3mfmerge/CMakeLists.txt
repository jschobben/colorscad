cmake_minimum_required(VERSION 3.14...3.28)

project(3mfmerge)

# The generator expression $<0:> at the end, is only there to prevent multi-config generators such
# as MSVC's nmake from adding 'Debug' and the like
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin$<0:>)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin$<0:>)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(FetchContent)
set(FETCHCONTENT_QUIET FALSE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

find_package(LIB3MF 2)

add_executable(${PROJECT_NAME} 3mfmerge.cpp)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_11)
target_link_libraries(${PROJECT_NAME} PRIVATE lib3mf)
