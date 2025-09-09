# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning where applicable.

## Unreleased
### Added
- CI with shellcheck, shfmt, bats, and kcov (coverage artifact)
- CI container smoke build job on pull_request to detect Containerfile regressions
- Strict verification flag (--require-verify) and enforcement in CI
- Offline/local install support via --package; auto-detect colocated certificate.pem and signature.bin
- Custom CA bundle support via --ca-bundle | KIRO_CA_BUNDLE
- Integration test for offline install (tests/integration)
- docs/USER_GUIDE.md with repository layout, verification, offline mode, containers, and upstream differences
- Containerfile, .containerignore, and helper scripts:
  - scripts/build-container.sh (auto-detect engine, platform for docker/nerdctl, BuildKit/buildx when available)
  - scripts/run-container.sh (auto-detect X11/Wayland; optional GPU auto-detect; engine auto-detect)

### Changed
- Refactored installer into scripts/install-kiro.sh orchestrator with libraries under scripts/lib/*
- Legacy top-level scripts removed; use scripts/ paths
- Default policy blocks plain HTTP; file: URL support for local copies
- README: Security and Verification; Compatibility; Containers; fork notice; links to docs/SECURITY.md and docs/USER_GUIDE.md
- Moved documentation into docs/ (except README.md); updated references

### Fixed
- Signature verification exit-code handling in verify.sh
- Find precedence in diagnostics; safer offline state composition

