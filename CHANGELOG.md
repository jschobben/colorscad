# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both colorscad and 3mfmerge changes are included here. Unless explicitly mentioned, entries apply to colorscad.

## [Unreleased]

### Fixed - 3mfmerge

- Explain how to build on non-x86_64 platforms, such as ARM

### Fixed - colorscad

- Now it really works on OSX, 0.3.1 actually didn't because of using 'sed -u'
- A few more sanity checks:
  - Check if 'openscad --info' reports 3MF support

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

[Unreleased]: https://github.com/jschobben/colorscad/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/jschobben/colorscad/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/jschobben/colorscad/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/jschobben/colorscad/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jschobben/colorscad/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jschobben/colorscad/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/jschobben/colorscad/releases/tag/v0.0.1
