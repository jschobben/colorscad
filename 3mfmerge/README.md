3MFMerge
========

This tool merges a given set of .3mf models into one.
Material color of each individual input model is set, based on the filename.
It uses [Lib3MF](https://github.com/3MFConsortium/lib3mf) to do the work.

Requirements
------------

Lib3MF v2 is used, which is downloaded to the build folder as part of the build process.
That means it doesn't have to be manually installed,
although an active internet connection is needed during the configuration stage.

The colorscad.sh script expects a binary called '3mfmerge' in the '3mfmerge/bin/' dir,
which is the default output location of the build.

How to build
------------

Here is how to compile 3mfmerge. As mentioned, the binary will be produced at ```3mfmerge/bin/3mfmerge```.

On most systems, the following should work:
```
mkdir build
cd build
cmake .. -DLIB3MF_TESTS=OFF
cmake --build .
```
Windows users should make sure that the native version of CMake (>= v3.14) is installed,
as well as a recent version of Visual Studio. VS 2015 should work.
The Windows build might fail due to some warning-as-error shenanigans in lib3mf,
when making a 32-bit build which seems to be the default.
To work around that, force a 64-bit build:
```
cmake .. -DLIB3MF_TESTS=OFF -DCMAKE_GENERATOR_PLATFORM=x64
cmake --build .
```

Usage
-----

```ls *.3mf | 3mfmerge OUTPUT_FILE```

Run 3mfmerge without parameters for more details.
