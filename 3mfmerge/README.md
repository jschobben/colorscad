3MFMerge
========
This tool merges a given set of .3mf models into one.
Material color of each individual input model is set, based on the filename.
It uses [Lib3MF|https://github.com/3MFConsortium/lib3mf] to do the work.

Requirements
------------
Lib3MF v2 is required. If that is not available in your OS's package manager,
either [download the SDK binaries|https://github.com/3MFConsortium/lib3mf/releases] or build it from source.

The colorscad.sh script expects a binary called '3mfmerge' in the '3mfmerge/build/' dir.

How to build
------------
Here is how to compile 3mfmerge. As mentioned, the binary must afterwards be located at ```3mfmerge/build/3mfmerge```.

Linux users should be able to simply do this, if lib3mf v2 is properly installed:
```
mkdir build
cd build
cmake ..
cmake --build .
```

Windows users are best off installing the precompiled lib3mf release: [https://github.com/3MFConsortium/lib3mf/releases].
Download the latest lib3mf_sdk_v2.x.y.zip from there, and unzip it somewhere.
Also, make sure that the Windows-native version of CMake (>= v3.5) is installed, as well as a recent version of Visual Studio.
Then, run the following from a Windows command prompt window (not from cygwin or so):
```
set 3MF_SDK=<full path to where you unzipped the v2.x.y Lib3MF SDK>
mkdir build
cd build
cmake -G "Visual Studio 14 2015 Win64" .. -DLIB3MF_CPP_BINDINGS_DIR=%3MF_SDK%/Bindings/Cpp -DLIB3MF_LOCATION=%3MF_SDK%/Lib/lib3mf.lib
cmake --build .
copy Debug\3mfmerge.exe .
copy %3MF_SDK%\Bin\lib3mf.dll .
```

Usage
-----
```ls *.3mf | 3mfmerge OUTPUT_FILE```
Run 3mfmerge without parameters for more details.
