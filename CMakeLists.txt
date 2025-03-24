cmake_minimum_required(VERSION 3.14...3.28)

project(colorscad)
add_subdirectory(3mfmerge)

install(PROGRAMS colorscad.sh RENAME colorscad DESTINATION bin)