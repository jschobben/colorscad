# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both colorscad and 3mfmerge changes are included here. Unless explicitly mentioned, entries apply to colorscad.

## [Unreleased]

### Added

- Add option '-k' to allow keeping intermediate per-color models in a specified directory.

### Fixed

- Small improvement to "-h": highlight need to pass an extra argument.
- Clean up and add shellcheck validation for `test/run.sh`.

### Fixed - 3mfmerge

- Add workaround for CMake 4.0 dropping support for Lib3MF's use of CMake 3.0.
- CI: avoid overload of GHA macos runner

## [0.6.2] - 2025-03-30

### Added

- Allow installing colorscad + 3mfmerge via a unified CMake script in the repo root (thanks: hegjon).
- ColorSCAD is now available in Fedora Linux! Document install steps, and reword README slightly.

## [0.6.1] - 2025-03-15

### Fixed - 3mfmerge

- Search on PATH for `3mfmerge` binary, so it's no longer required to have the binary in its default location at `3mfmerge/bin/`.

## [0.6.0] - 2025-03-15

### Added

- Support using OpenSCAD binaries which are not called `openscad`, via env var `OPENSCAD_CMD` (thanks: pinkfish)

### Added - 3mfmerge

- Use system's Lib3MF, if a suitable version is installed; otherwise, fall-back to building from source as before.

## [0.5.2] - 2024-09-15

### Added

- Sort colors by color name in output, to make remapping color<->filament in a slicer less often needed (thanks: schorsch3000)
- CI workflow to run tests on OpenSCAD 2015.03/2019.05/2021.01/nightly, for Ubuntu apt/AppImage/MacOS/Windows.

### Added - 3mfmerge

- Assign 3mf component names based on r/g/b/a values, to make assigning filaments to colors easier in a slicer for instance.

### Fixed

- Improve code quality of `colorscad.sh`, add shellcheck validation (thanks: schorsch3000)

### Fixed - tests

- Use parameter --enable=predictible-output if available, to fix tests on OpenSCAD >= 2024.01.26 with lib3mf v2.

## [0.5.1] - 2021-08-22

### Fixed

- Remove dependency on GNU coreutils on macOS; now OpenSCAD is the only dependency, no more need to brew
- Robustly support input (-i) that's not in the current dir; work around inconsistent behavior among OpenSCAD versions

## [0.5.0] - 2021-08-19

### Added

- Nesting `color()` statements is now supported, and works like in the F5 preview: the outermost color applies.

## [0.4.2] - 2021-08-14

### Fixed - 3mfmerge

- Convert colors to sRGB space, as required for 3MF; previously, colors in produced 3MFs were "too dark"

### Added

- Tests, to verify proper behavior
- Some extra robustness checks

## [0.4.1] - 2021-07-09

### Fixed - 3mfmerge

- Explain how to build on non-x86_64 platforms, such as ARM

### Fixed - colorscad

- Now it really works on OSX, 0.3.1 actually didn't because of using 'sed -u'
- Make background job management more robust
- A few more sanity checks:
  - Check if 'openscad --info' reports 3MF support
  - A non-empty .csg is produced during the first step

## [0.4.0] - 2021-07-04

### Added

- Switch -v to enable verbose logging. Decrease verbosity by default, by using OpenSCAD's --quiet parameter.

### Fixed

- Improved error handling:
  - Input file does not exist
  - The wrong 'sort' command is used
  - No colors are found in the input (i.e. due to errors in the input)
  - No file or an empty file is produced by '3mfmerge'

## [0.3.1] - 2021-07-03

### Fixed

- Improve OSX compatibility
- Some refactoring

## [0.3.0] - 2021-07-02

### Added

- Several CLI parameter improvements (thanks: Colorscad Tester)
  - Proper CLI arg parsing with getopts (syntax change for specifying input/output!)
  - Add '-f' parameter to overwrite output if it exists
  - Support forwarding parameters to openscad (such as '-D')

## [0.2.0] - 2021-06-27

### Fixed - 3mfmerge

- No need to manually install lib3mf anymore: now it's fetched as source (2.1.1), and compiled as part of the build.
- Raise CMake requirement to 3.14

### Fixed - colorscad

- Improved OSX compatibility (thanks: Matt N.)

## [0.1.0] - 2020-02-19

### Added

- Add 3MF support, via lib3mf and the (included) c++ tool '3mfmerge'
- CLI interface: now need to explicitly specify output file name

### Fixed

- Mention OpenSCAD version requirements in README.md
- Do not automatically compress AMF files, since some tools (i.e. Slic3r 1.3.0) don't support compressed ones.
  Instead, just echo a one-liner that can be copy-pasted in the terminal to compress the AMF.
- More robust/verbose wrt failures, i.e. due to non-manifold geometry in the OpenSCAD model.
- Improved status output: better progress, and less noise if all goes well.


## [0.0.1] - 2020-02-16

### Added

- Everything! Only supports creating a colored .amf file.

[Unreleased]: https://github.com/jschobben/colorscad/compare/v0.6.2...HEAD
[0.6.2]: https://github.com/jschobben/colorscad/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/jschobben/colorscad/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/jschobben/colorscad/compare/v0.5.2...v0.6.0
[0.5.2]: https://github.com/jschobben/colorscad/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/jschobben/colorscad/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/jschobben/colorscad/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/jschobben/colorscad/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/jschobben/colorscad/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/jschobben/colorscad/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/jschobben/colorscad/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/jschobben/colorscad/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jschobben/colorscad/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jschobben/colorscad/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/jschobben/colorscad/releases/tag/v0.0.1
