# Changelog

All notable changes to Kleene will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-01-13

### Added
- **Nine Cells Framework** - Expanded from four quadrants to nine cells for richer narrative possibility space
- **Temperature System** - Improvisation temperature (0-10) controls adaptive storytelling depth
- **The Yabba Scenario** - Psychological thriller inspired by Wake in Fright (1971)
- **Scenario Registry System** - Centralized metadata management for all scenarios
- **Lazy Loading** - Support for large scenarios (200KB+) with on-demand node loading
- **Cinematic Headers** - Enhanced presentation format for immersive gameplay
- **Improvised Actions** - Free-text player input with creative title formatting
- **Save Auto-Approval** - Pre-tool hooks for seamless save operations

### Changed
- **Refactored game loop** - Removed agent layer for 60-70% faster turn response
- **Updated framework documentation** - Comprehensive guides for Nine Cells model
- **Enhanced presentation** - New convention guidelines for headers, traits, choices

### Fixed
- Option narrative display in kleene-play skill
- Save auto-approval now covers both Write and Bash tools

## [0.1.0] - 2025-01-11

### Added
- Initial release of Kleene plugin
- Four Quadrants framework (Option type semantics)
- Basic scenario format (YAML-based)
- Gateway command (`/kleene`) with routing
- Three bundled scenarios:
  - Dragon Quest (fantasy)
  - Altered State Nightclub (surreal mystery)
  - Corporate Banking (career drama)
- Skills:
  - `kleene-play` - Interactive gameplay
  - `kleene-generate` - Scenario generation
  - `kleene-analyze` - Structural analysis
- Framework documentation in `lib/framework/`
- Basic precondition/consequence system
- Save/load functionality

[0.2.0]: https://github.com/hiivmind/kleene/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/hiivmind/kleene/releases/tag/v0.1.0
