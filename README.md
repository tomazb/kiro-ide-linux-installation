# Kiro Linux Installation

Automated installer for [Kiro](https://kiro.dev/), an AI-powered development environment. This repository provides scripts to easily install, update, and manage Kiro on any Linux distribution.

Note: The refactored, safer, and idempotent installer lives under scripts/. Legacy top-level scripts have been removed; use the scripts/ paths.

Fork notice: this repository is a maintained fork of the upstream at https://github.com/abhilashiig/kiro-ide-linux-installation.

## Quick Installation

The easiest way to install Kiro is using our clone-and-install script:

```bash
curl -fsSL https://raw.githubusercontent.com/tomazb/kiro-ide-linux-installation/main/scripts/clone-and-install-kiro.sh | bash
```

This single command will:

- Clone this repository to a temporary directory
- Run the refactored installer automatically
- Clean up temporary files when done

## Installation Options

### System-wide Installation (default)

```bash
./scripts/install-kiro.sh
```

Installs Kiro to `/opt/kiro` (requires sudo)

### User-only Installation

```bash
./scripts/install-kiro.sh --user
```

Installs Kiro to `~/.local/share/kiro` (no sudo required)

### Force Reinstall

```bash
./scripts/install-kiro.sh --force
```

Reinstalls even if the same version is already installed

## Managing Kiro

### Update Kiro

```bash
./scripts/install-kiro.sh --update
```

The script automatically checks for updates and installs the latest version

### Uninstall Kiro

```bash
# Remove installation only
./scripts/install-kiro.sh --uninstall

# Remove installation and user data
./scripts/install-kiro.sh --uninstall --clean
```

## What This Does

The installation script handles everything automatically:

- Downloads the latest Kiro release
- Checks and installs required dependencies
- Sets up proper file permissions
- Creates desktop entries for easy access
- Configures system paths
- Manages version updates

## Advanced Usage

For more installation options, run:

```bash
./scripts/install-kiro.sh --help
```

## Compatibility and recommended environments

Best supported (fully automated dependencies and standard install flow):

- Ubuntu/Debian (apt)
- Fedora/RHEL/CentOS (dnf/yum)
- Arch Linux (pacman)
- openSUSE (zypper)

Other environments and caveats:

- Alpine Linux (apk): the installer does not auto-install dependencies with apk. Ensure these are present before running: bash, curl or wget, jq, openssl, tar, coreutils (sha256sum). Prefer the offline (--package) mode if needed. The Kiro app itself may require glibc on musl-based systems.
- WSL/headless servers: desktop entry creation is optional; the core installation works. If update-desktop-database is absent, the step is skipped.
- SELinux/restricted hosts: setting SUID on chrome-sandbox (4755) may be denied by policy; a warning is logged and installation proceeds.
- PATH: system installs symlink to /usr/local/bin; user installs symlink to ~/.local/bin. Ensure those locations are in PATH.

## Requirements

- `git` (for cloning the repository)
- `curl` or `wget` (for downloading)
- `bash` (for running the scripts)

The installer will automatically check and install other required dependencies.

## Build a container image locally (no binary distribution)

You can build a local container image that installs Kiro inside the image using this repository’s installer. This does not distribute Kiro binaries; the image is built on your machine.

Example using Podman:

```bash
# Build
podman build -t kiro-runtime -f Containerfile .

# Run with helper (X11 default)
xhost +local:
scripts/run-container.sh --engine podman --image kiro-runtime --tag latest  # auto-detects X11/Wayland

# Force Wayland backend (override auto-detection)
scripts/run-container.sh --engine podman --backend wayland
```

Notes:
- This will download Kiro during the image build and install it to /opt/kiro, with /usr/local/bin/kiro symlink.
- Running GUI apps in containers depends on host display and GPU setup; you may need additional flags on some hosts.
- No images are published by this repository; you control builds and distribution yourself.
- You can also build via helper: scripts/build-container.sh (auto-detects engine and platform)

See the full user guide in docs/USER_GUIDE.md for details.

## Security and Verification

This installer prioritizes integrity checks and optional cryptographic verification when downloading releases.

- HTTPS is used for all network requests
- SHA-256 checksums are validated when available
- Optional signature verification is performed when a certificate and signature are available (from metadata or colocated files)
- Verification can be customized or bypassed explicitly (not recommended)

Verification flow (high level):
1. The installer fetches release metadata from `KIRO_METADATA_URL` (see scripts/conf/defaults.conf)
2. It downloads the release archive
3. It attempts to obtain an expected SHA-256 digest, in this order:
   - From `--checksum <hex|file:/path|url:https://...>` (or `KIRO_CHECKSUM`)
   - From a remote checksum file derived from the package URL: `<url>.sha256` or `<url>.sha256sum`
4. If a checksum is available, it is compared with the computed digest; mismatches abort the install
5. Signature verification is then attempted if a certificate and signature are available:
   - Certificate and signature are sourced from (first match wins):
     - CLI flags `--cert <file:/path|url:...>` and `--sig <file:/path|url:...|base64>`
     - Environment variables `KIRO_CERT` / `KIRO_SIG`
     - Installer metadata (certificatePem and release signature)
     - Files colocated with the archive: `certificate.pem` and `signature.bin`
   - If both are present, the installer verifies the archive using OpenSSL (supports SHA-512 or SHA-256 signatures)
   - If signature verification fails, the install aborts; if not available, the installer proceeds with a warning

To bypass verification explicitly (not recommended), pass `--skip-verify` or set `KIRO_SKIP_VERIFY=true`.
To enforce verification (require either a checksum or a valid signature), pass `--require-verify` or set `KIRO_REQUIRE_VERIFY=true`.

Examples:
```bash
# Pin a checksum from a URL
./scripts/install-kiro.sh --checksum url:https://example.com/releases/kiro.tar.gz.sha256

# Pin a literal hexadecimal checksum
./scripts/install-kiro.sh --checksum 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824

# Provide a signature and certificate from local files
./scripts/install-kiro.sh --sig file:/path/to/signature.bin --cert file:/path/to/certificate.pem

# Offline/local install from an explicit package (with optional checksum/signature)
./scripts/install-kiro.sh --package file:/tmp/kiro.tar.gz --checksum file:/tmp/kiro.tar.gz.sha256
# If certificate.pem and signature.bin are next to the archive, they are auto-detected

# Bypass verification (not recommended)
./scripts/install-kiro.sh --skip-verify
```

Note: plain HTTP downloads are blocked by default. To allow (not recommended), set KIRO_ALLOW_INSECURE_HTTP=true.
To pin a custom CA bundle for HTTPS downloads, pass --ca-bundle /path/to/ca-bundle.pem (or set KIRO_CA_BUNDLE). The file must be readable by the installer.

For full details, see docs/SECURITY.md.

See the full user guide in docs/USER_GUIDE.md.

## License

This installer script is provided as-is. Kiro itself is a product of AWS and subject to its own licensing terms.
