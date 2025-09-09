# Security Policy and Verification

This document describes how the Kiro Linux installer validates downloads and how you can configure verification.

Scope
- Applies to the scripts in this repository (scripts/*)
- Covers checksum verification and optional signature verification
- Complements the overview in README.md

Threat model (high level)
- Protect against accidental corruption and most network tampering via HTTPS + checksums
- Provide optional cryptographic authenticity when a certificate and signature are available
- Allow explicit bypass (for controlled environments) with clear warning

Verification algorithm
1. Fetch metadata
   - Source: KIRO_METADATA_URL (see scripts/conf/defaults.conf)
   - Installer records the path of the downloaded metadata as KIRO_METADATA_FILE
2. Download archive (tar.gz)
3. Checksum verification (SHA-256)
   - Expected digest is discovered in this order:
     a) CLI flag --checksum <hex|file:/path|url:https://...> or env KIRO_CHECKSUM
     b) Remote checksum derived from the package URL: <url>.sha256 or <url>.sha256sum
   - The archive's SHA-256 is computed and compared; a mismatch aborts the install
   - If no checksum is available, a warning is emitted and the installer proceeds (unless --skip-verify was passed earlier)
4. Signature verification (optional, authenticates origin)
   - Required inputs: certificate (PEM) and signature (binary/base64)
   - Inputs are resolved in this order (first match wins):
     a) CLI flags --cert <file:/path|url:...> and --sig <file:/path|url:...|base64> (or KIRO_CERT, KIRO_SIG)
     b) Metadata-provided certificatePem and release signature
     c) Files colocated with the archive: certificate.pem and signature.bin
   - If both certificate and signature are available, OpenSSL verifies the archive (tries SHA-512, then SHA-256)
   - Failure to verify with available signature = hard failure
   - If signature is not available at all, a warning is emitted and the installer proceeds
5. Bypass
   - You can bypass verification with --skip-verify or KIRO_SKIP_VERIFY=true (not recommended)

Configuration
- CLI flags (see scripts/lib/cli.sh):
  - --checksum <hex|file:/path|url:https://...>
  - --sig <file:/path|url:...|base64>
  - --cert <file:/path|url:...>
  - --skip-verify
- Environment variables:
  - KIRO_CHECKSUM, KIRO_SIG, KIRO_CERT, KIRO_SKIP_VERIFY
  - KIRO_METADATA_URL (defaults in scripts/conf/defaults.conf)

Examples
```bash
# Strict mode: pin a known SHA-256 digest
./scripts/install-kiro.sh --checksum 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824

# Fetch checksum from a URL colocated with the release
./scripts/install-kiro.sh --checksum url:https://example.com/releases/kiro.tar.gz.sha256

# Provide signature and certificate explicitly
./scripts/install-kiro.sh --sig file:/tmp/kiro.sig --cert file:/tmp/kiro.pem

# Bypass verification (not recommended)
./scripts/install-kiro.sh --skip-verify
```

Responsible disclosure
- Please use GitHub Security Advisories (Security tab -> "Report a vulnerability") to privately disclose issues.
- Avoid filing public issues for security-sensitive topics.

Notes
- Network downloads use HTTPS with retry logic (scripts/lib/net.sh)
- Logging can be emitted in JSON or colorized text; see scripts/lib/log.sh

