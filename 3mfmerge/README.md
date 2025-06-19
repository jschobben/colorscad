3MFMerge
========

This tool merges a given set of .3mf models into one.
Material color of each individual input model is set, based on the filename.
It uses [Lib3MF](https://github.com/3MFConsortium/lib3mf) to do the work.

Requirements
------------

Lib3MF v2 is used. If a suitable version is already installed then the system's version is used;
otherwise, it is downloaded to the build folder and built from source as part of the build process.
That means it doesn't have to be manually installed, although if it isn't then the initial build
takes longer and an active internet connection is needed during the configuration stage.

To disable this automatic downloading, and instead fail the build if Lib3MF is not installed,
add parameter `-DFETCHCONTENT_FULLY_DISCONNECTED=ON` to the `cmake ..` command described below.

The colorscad.sh script first looks for a binary called '3mfmerge' in the '3mfmerge/bin/' dir,
which is the default output location of the build. If this is not found, it will look on the PATH.

How to build
------------

Here is how to compile 3mfmerge. As mentioned, the binary will be produced at ```3mfmerge/bin/3mfmerge```.

On most systems, the following should work:
```
mkdir build
cd build
cmake ..
cmake --build .
```
Windows users should make sure that the native version of CMake (>= v3.14) is installed,
as well as a recent version of Visual Studio. VS 2015 should work.
The Windows build might fail due to some warning-as-error shenanigans in lib3mf,
when making a 32-bit build which seems to be the default.
To work around that, force a 64-bit build:
```
cmake .. -DCMAKE_GENERATOR_PLATFORM=x64
cmake --build .
```

If you have Lib3MF installed as a system package, and prefer to also properly install `3mfmerge`,
simply use cmake's standard mechanism for that:
```
cmake --install .
```
After doing this, it's safe to remove ```3mfmerge/bin```.

### Building on non-x86_64-based systems

If dependency Lib3MF is not yet installed on the system and a build from source is done (see above),
then the currently used version (v2.2.0) uses
[AutomaticComponentToolkit 1.6.0](https://github.com/Autodesk/AutomaticComponentToolkit/tree/v1.6.0)
(ACT) as part of its build system.
The Lib3MF source includes binaries of ACT for x86_64-based platforms,
which obviously won't work if your platform is for instance ARM-based.
See also [Lib3MF issue 199](https://github.com/3MFConsortium/lib3mf/issues/199).

The workaround is, of course, to use another ACT binary that matches your platform.
If possible, install ACT (>= v1.6.0) using your platform's favorite package manager.
If not available, build ACT from source, which requires Go (golang):
- clone the ACT repo, check out tag v1.6.0
- from the root of the ACT repo, run: `go build -o act Source/*.go`
- when done, copy or symlink the `act` binary to e.g. `/usr/local/bin/act`

With ACT installed, it's time for the workaround:
- make sure that running `act` works and shows v1.6.0 or up
- run the initial `cmake ..` as above
- replace the `act.linux` binary:
  `ln -sf $(which act) _deps/lib3mf-src/AutomaticComponentToolkit/bin/act.linux`
- build as usual: `cmake --build .`

Usage
-----

```ls *.3mf | 3mfmerge OUTPUT_FILE```

Run 3mfmerge without parameters for more details.
