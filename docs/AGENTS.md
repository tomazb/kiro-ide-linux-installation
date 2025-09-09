# Agent collaboration and responsibilities for Kiro installer scripts

This document outlines how agents and contributors should collaborate on the Kiro Linux installer. It complements the README and provides guidance on modular design, testing, and release workflows.

Principles
- Follow SOLID and DRY principles. Keep modules single-responsibility and avoid duplication.
- Prefer safe, idempotent operations. All steps must be re-runnable without side effects.
- Keep the entrypoints (scripts/install-kiro.sh, scripts/clone-and-install-kiro.sh) thin; push logic into scripts/lib/*.

Repository layout (proposed)
- scripts/install-kiro.sh: Main orchestrator
- scripts/clone-and-install-kiro.sh: Compatibility wrapper that delegates to the orchestrator
- scripts/lib/*.sh: Libraries (logging, config, CLI parsing, FS utilities, network, versioning, state, rollback, deps, sudo helpers, hooks, progress)
- scripts/conf/defaults.conf: Built-in defaults that can be overridden via env/config/CLI
- docs/: Additional docs (MIGRATION.md, SECURITY.md, OPERATIONS.md)
- tests/: bats unit tests, integration, and e2e suites

Coding standards
- Bash: set -Eeuo pipefail and safe IFS. Quote all variables. Avoid eval. No unbounded globbing. Use readonly constants.
- Linting: shellcheck must pass cleanly; shfmt for formatting.
- Logging: provide levels (TRACE, DEBUG, INFO, WARN, ERROR) and optional JSON.

Testing & coverage
- Provide unit tests for each library using bats.
- Integration tests run end-to-end; include an offline path using a signed tarball and checksum (see tests/integration).
- Use kcov (in CI) to gather coverage. Keep docs/TEST-IMPROVEMENTS.md current with coverage gaps and tasks.
- CI enforces strict verification (KIRO_REQUIRE_VERIFY=true); tests should provide checksum and/or signature.

Release & versioning
- Maintain backward compatibility for CLI flags. Emit deprecation warnings when renaming.
- Tag releases and attach checksums. Document changes in CHANGELOG.

Security
- Verify downloads via checksum and/or signature; prefer providing both in CI. Use atomic file operations. Implement rollback.
- Block plain HTTP downloads by default (KIRO_ALLOW_INSECURE_HTTP can override for exceptional cases).
- Support custom CA bundle (--ca-bundle|KIRO_CA_BUNDLE) for TLS trust pinning.
- Respect user preference to use sudo for any virsh operations (not currently used but enforced globally).

Contributing
- Open PRs against the refactoring branch. Ensure tests and coverage thresholds pass.
- Run local checks:
  - Lint: bash scripts/lint.sh (shellcheck + shfmt)
  - Unit + integration tests: ./scripts/test.sh
- For offline test, see tests/integration/scripts/install_offline.sh

