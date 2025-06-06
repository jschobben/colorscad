ColorSCAD
=========

This script helps with exporting an OpenSCAD model to AMF or 3MF format, with color information preserved.
The colors are simply assigned using OpenSCAD's color() statement, so generally speaking the output will look like the
preview (F5) view in OpenSCAD.

Requirements
------------

This script requires the Bash shell, and of course OpenSCAD.
AMF export should work with OpenSCAD version 2015.03, but was mostly tested on 2019.05.
3MF export requires version 2019.05 or newer, and also requires some preparation steps (compilation).

Platform-wise, it should run anywhere Bash runs (that includes i.e. cygwin).
No assumptions are made about OS-specific directories, such as /tmp/ and the like.

The platform-native OpenSCAD binary needs to be available for this script to work.
If it is called `openscad` and available on the PATH, then it should work out-of-the-box.

In case the binary has a strange name, then set environment variable `OPENSCAD_CMD` to its name.
This may be a full path, or just the name.

Unless `OPENSCAD_CMD` is set to a full path, the binary needs to be reachable via the PATH.
On Windows Cygwin users may need to first run something like:<br>
```export PATH=/cygdrive/c/Program\ Files/OpenSCAD:$PATH```<br>
Similarly, Mac users can try:<br>
```export PATH=/Applications/OpenSCAD.app/Contents/MacOS:$PATH```

This script should mostly work on Bash 3 (i.e. Mac's non-Homebrew default), although for best results Bash 4 is recommended.

Installation
------------

**On Fedora Linux:**

ColorSCAD is included in the standard repository on Fedora Linux 41 and later:
```
sudo dnf install colorscad
```

**On other systems:**

ColorSCAD can be installed using the standard CMake installation procedure
(which will in most cases install it to `/usr/local/bin/`), by following these steps from the repo root:
```
mkdir build
cd build
cmake ..
cmake --build .
sudo cmake --install .
```
This will also take care of building and installing `3mfmerge`.

**From source:**

It's possible to use ColorSCAD directly from source, without installation.
In that case, to enable 3MF export the c++ `3mfmerge` tool first needs to be compiled;
see [3mfmerge/README.md](3mfmerge/README.md) for details.

Usage
-----

To call ColorSCAD from source, use `<path>/colorscad.sh`;
when it is installed (as on Fedora Linux, or by manual installation), simply call it as `colorscad`, without `.sh`.

Basic usage:
```
colorscad -i <input scad file> -o <output file> [OTHER OPTIONS...] [-- OPENSCAD OPTIONS...]
```

The output file must have as extension either `.amf` or `.3mf`.

For more detailed usage info that lists all the options, run `colorscad -h`.

How it works
------------

First, the model is analysed to find out which colors (RGBA values) it uses.
Then, OpenSCAD is used to generate an intermediate .amf or .3mf file for each color,
containing only geometry with that color.
Finally, all per-color intermediate files are combined, with color info added.

Or, in a bit more detail:
1) Convert the model to .csg format, mostly to resolve the various ways color() can be used into r/g/b/a parameters.
2) Call OpenSCAD to export a .stl, but redefine the color() module to echo its parameters and do nothing else.
3) Check that the produced .stl is empty; if not, complain about it and stubbornly refuse to continue.
4) Loop over the captured set of r/g/b/a values. For each of them, call OpenSCAD with another redefined color() module
   that only outputs when its r/g/b/a parameters match. Use multiple OpenSCAD processes here to speed things up a bit.
5) Combine all the individual intermediate files, assigning material color.

Preparations
------------

There is no need to make any ColorSCAD-specific changes to your .scad file(s), however they do need to follow these rules:
1) All geometry has a color assigned.
   Geometry without a color would end up having *every other* color assigned. The script detects this case though, and refuses to run.
2) Don't use too many colors, or be prepared to have a lot of patience.
   No fancy gradients, please. If you must, it's recommended to use Linux or macOS since it runs much faster than on Windows.
3) Let's avoid weird geometry such as overlapping color volumes...
   Avoid using multiple colors in an `intersection()` or `difference()`, if unavoidable then just wrap it in a `color()` statement.

Tests
-----

To make sure everything works as expected, run the tests by executing the script in `test/run.sh`.
It tests two things: handling of strange situations, and that generated AMF/3MF models are as expected.
On older OpenSCAD versions, or on newer versions compiled without 3MF support,
additional parameters need to be given to make the tests pass.
If applicable, the test script will alert about this.

Make sure your `3mfmerge` binary is up-to-date before running the tests (see above).

Limitations
-----------

The .amf merging method is, hmm, a bit creative. The produced .amf should probably be one "object with multiple colored
volumes", but instead it contains a separate object for each color. Reason: lazy shell-script .amf merge
implementation is too slow to renumber vertices, which is needed for "single object with multiple volumes" format.

Merging .3mf files uses the official library for it,
although this means having a dependency which is not (yet) commonly available in all Linux distributions.
It's downloaded locally as part of the `3mfmerge` build, so this should not be a big issue.

When there are a lot of colors, on Windows this script runs much slower than on Linux
(probably due to process creation costs).

Probably some weird output may be produced if color volumes overlap.

In fact, weird behavior may occur at any time! Hopefully the tests will catch it.
If it doesn't seem to work for your .scad for any non-obvious reason, let's hear about it.
