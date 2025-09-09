# User Guide

This guide explains how to use the Kiro Linux installer, what each script does, the verification and offline modes, and how this fork differs from upstream.

Overview
- Purpose: install, update, and uninstall Kiro on Linux safely and repeatably
- Entrypoints:
  - scripts/install-kiro.sh: main orchestrator (recommended)
  - scripts/clone-and-install-kiro.sh: clones repo to a temp dir and delegates to the orchestrator
  - Note: Legacy top-level wrappers were removed. Use scripts/install-kiro.sh and scripts/clone-and-install-kiro.sh.

Repository layout
- scripts/
  - install-kiro.sh: orchestrates the flow (config load, CLI parse, deps, locks, install/uninstall)
  - clone-and-install-kiro.sh: clone wrapper that forwards options to install-kiro.sh
  - lib/
    - cli.sh: parses CLI and exposes KIRO_* variables
    - config.sh: layered configuration (defaults -> system/user config -> env -> CLI)
    - deps.sh: dependency detection/auto-install via the detected package manager
    - fs.sh: temp dirs, atomic writes, and locking
    - installer.sh: install/uninstall logic (fetch metadata, download, extract, set perms, desktop entry)
    - log.sh: logging levels and JSON mode
    - net.sh: downloads with retry, HTTPS-only default, optional custom CA bundle, file: support
    - os.sh: OS and package manager detection
    - state.sh: records install state and metadata
    - sudo.sh: sudo wrapper (enforces sudo for virsh if used)
    - verify.sh: checksum and signature verification helpers
  - conf/
    - defaults.conf: default channels, dirs, flags
- tests/
  - unit/ (bats): unit tests for libs (verify/signature/version, etc.)
  - integration/: offline end-to-end install test using a signed tarball and checksum
- docs/: this user guide and other repository documentation
- CHANGELOG.md: notable changes
- Containerfile and .containerignore: local container builds only (no publishing)
- scripts/build-container.sh: helper to build the image (auto-detects engine)
- scripts/run-container.sh: helper to run the image (auto-detects X11/Wayland, optional GPU)

Common commands
- Quick install (user mode):
  - ./scripts/install-kiro.sh --user
- System-wide install (requires sudo):
  - ./scripts/install-kiro.sh
- Update:
  - ./scripts/install-kiro.sh --update
- Uninstall:
  - ./scripts/install-kiro.sh --uninstall [--clean]

Verification policy (summary)
- Default behaviors:
  - HTTPS-only downloads by default; plain HTTP is blocked (override with KIRO_ALLOW_INSECURE_HTTP=true)
  - Checksums validated when provided/available
  - Signatures verified if a certificate+signature can be resolved
- Strict mode (recommended in CI):
  - --require-verify (or KIRO_REQUIRE_VERIFY=true) enforces that at least one valid verification method (checksum or signature) must be available
- Custom CA bundle:
  - Use --ca-bundle /path/to/ca.pem (or KIRO_CA_BUNDLE) to pin trust roots for TLS

Offline/local installation
- Use --package to point to a local tarball or file: URL:
  - ./scripts/install-kiro.sh --user --require-verify --package file:/path/kiro.tar.gz --checksum file:/path/kiro.tar.gz.sha256
- If certificate.pem and signature.bin are colocated next to the archive (for URLs or file:), they will be auto-detected

CLI summary (selected)
- --user | --force | --clean | --update | --uninstall
- --checksum <hex|file:/path|url:...>
- --sig <file:/path|url:...|base64>
- --cert <file:/path|url:...>
- --require-verify (strict mode)
- --skip-verify (not recommended)
- --package <file:/path|url:...|/local/path>
- --ca-bundle /path/to/ca.pem
- See ./scripts/install-kiro.sh --help for full list

Containers (local builds only)
- Build locally (no distribution):
  - scripts/build-container.sh  # auto-detects podman/docker/nerdctl
  - or: podman build -t kiro-runtime -f Containerfile .
- Run locally with display integration:
  - scripts/run-container.sh  # auto-detects X11/Wayland and optionally GPU (/dev/dri)
  - Examples:
    - X11: xhost +local: && scripts/run-container.sh --engine podman
    - Wayland: scripts/run-container.sh --engine podman --backend wayland

What changed from upstream
- Refactored installer:
  - Main orchestrator introduced (scripts/install-kiro.sh) with clear separation of concerns via scripts/lib/*
  - Legacy top-level scripts were removed; use scripts/ paths
- Verification improvements:
  - Strict verification mode (--require-verify)
  - Offline/local installations via --package
  - Custom CA bundle support for TLS
  - Default HTTP blocking; file: scheme support
- Robustness and observability:
  - Structured logging (levels, optional JSON)
  - Locking to avoid concurrent installs; atomic writes; safer permissions
- CI and tests:
  - GitHub Actions with shellcheck/shfmt, unit tests, and kcov coverage
  - Integration test for offline install using signed package and checksum

Compatibility notes
- Flags aim to remain backward compatible; new flags are additive
- Default behaviors favor safety (HTTP blocked, verification encouraged)

Troubleshooting
- Missing dependencies: installer will attempt to install via your package manager unless --skip-deps is set
- Verification failures: provide a correct --checksum or matching --sig/--cert pair
- Offline mode: ensure certificate.pem and signature.bin are present next to the archive or pass via --sig/--cert

