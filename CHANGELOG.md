# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/jschobben/colorscad/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/jschobben/colorscad/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/jschobben/colorscad/releases/tag/v0.0.1
