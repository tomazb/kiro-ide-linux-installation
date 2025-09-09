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
- Integration tests run end-to-end without network by using cached artifacts.
- Use kcov or bashcov to gather coverage. Keep a running TEST-IMPROVEMENTS.md with coverage gaps and tasks.

Release & versioning
- Maintain backward compatibility for CLI flags. Emit deprecation warnings when renaming.
- Tag releases and attach checksums. Document changes in CHANGELOG.

Security
- Verify downloads via signature or checksums. Use atomic file operations. Implement rollback.
- Respect user preference to use sudo for any virsh operations (not currently used but enforced globally).

Contributing
- Open PRs against the refactoring branch. Ensure tests and coverage thresholds pass.

