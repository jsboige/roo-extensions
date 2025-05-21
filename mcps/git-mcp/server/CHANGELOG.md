# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.5 - 2025-05-05

### Added
- (tools) Enhance `git_commit` tool result to include commit message and committed files list (`1f74915`)

### Changed
- (core) Alphabetize tool imports and initializers in `server.ts` for better organization (`1f74915`)
- (docs) Refine `git_commit` tool description for clarity (`1f74915`)

### Other
- Bump version to 2.0.5 (`1f74915`)

## v2.0.4 - 2025-05-05

- (docs): Added smithery.yaml

## v2.0.3 - 2025-05-05

### Added

- (tools) Enhance git_commit escaping & add showSignature to git_log (`312d431`)

### Changed

- (core) Update server logic and configuration (`75b6683`)
- (tools) Update git tool implementations (`8b9ddaf`)
- (transport) Update transport implementations and add auth middleware (`a043d20`)
- (internal) Consolidate utilities and update types (`051ad9f`)
- Reorganize utilities and server transport handling (`b5c5840`)

### Documentation

- Update project structure in README and tree (`bc8f033`)
- (signing) Improve commit signing docs and add fallback logic (`de28bef`)
- Update README and file tree, remove temporary diff file (`3f86039`)

### Other

- **test**: Test automatic commit signing (commit.gpgsign=true) (`ef094d3`)
- **chore**: Update dependencies (`3cb662a`)
