ColorSCAD
=========
This script helps with exporting an OpenSCAD model to AMF format, with color information preserved. The colors are simply assigned
using OpenSCAD's color() statement, so generally speaking the output will look like the preview (F5) view in OpenSCAD.

It should work with OpenSCAD version 2015.03, but was mostly tested on 2019.05.

Usage
-----
./colorscad.sh <\input scad file\> \<output file\> [MAX_PARALLEL_JOBS]

The output file must not yet exist, and must have as extension '.amf'.
MAX_PARALLEL_JOBS defaults to 8, reduce if you're low on RAM.

How it works
------------
First, the model is analysed to find out which colors (RGBA values) it uses. Then, OpenSCAD is used to generate an .amf
file for each color, containing only geometry with that color. Finally, all per-color .amf files are combined, with
color info added.

Or, in a bit more detail:
1) Convert the model to .csg format, mostly to resolve the various ways color() can be used into r/g/b/a parameters.
2) Call OpenSCAD to export a .stl, but redefine the color() module to echo its parameters and do nothing else.
3) Check that the produced .stl is empty; if not, complain about it and stubbornly refuse to continue.
4) Loop over the captured set of r/g/b/a values. For each of them, call OpenSCAD with another redefined color() module
   that only outputs when its r/g/b/a parameters match. Use multiple OpenSCAD processes here to speed things up a bit.
5) Combine all the individual .amf files, assigning material color.

Preparations
------------
There is no need to make any ColorSCAD-specific changes to your .scad file(s), however they do need to follow these rules:
1) All geometry has a color assigned.
   Geometry without a color would end up having *every other* color assigned. The script detects this case though, and refuses to run.
2) No geometry has multiple colors assigned.
   Such geometry will not appear at all in the output. The script does not detect this (yet).
3) Don't use too many colors, or be prepared to have a lot of patience.
   No fancy gradients, please.
4) Let's avoid weird geometry such as overlapping color volumes...

Limitations
-----------
The .amf merging method is, hmm, a bit creative. The produced .amf should probably be one "object with multiple colored
volumes", but instead it contains a separate object for each color. Reason: lazy shell-script .amf merge
implementation is too slow to renumber vertices, which is needed for "single object with multiple volumes" format.

Importing some files (such as .stl geometry) might not work.

Also, it's aimed at .amf, no .3mf so far (probably a lib3mf-based merge tool can be made).

And probably some weird output may be produced if color volumes overlap.

In fact, weird behavior may occur at any time! More testing is needed.
If it doesn't seem to work for your .scad for any non-obvious reason, let's hear about it.
