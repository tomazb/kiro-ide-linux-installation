# Test coverage and improvement log for Kiro installer

This document tracks testing coverage, gaps, and planned improvements. Update this as PRs land.

Current status
- Coverage tooling: to be added (kcov/bashcov)
- Unit tests: pending
- Integration tests: pending
- E2E tests: pending

Immediate priorities
1. Add unit tests for scripts/lib/log.sh (levels, colors, JSON output)
2. Add unit tests for scripts/lib/config.sh (precedence, defaults)
3. Add unit tests for scripts/lib/cli.sh (parsing, backward compatibility)
4. Add integration test for idempotent install path with mocked downloads

Task list
- [ ] Introduce kcov in CI and collect coverage metrics
- [ ] Create coverage badge and thresholds
- [ ] Add bats unit tests for log.sh
- [ ] Add bats unit tests for config.sh
- [ ] Add bats unit tests for cli.sh
- [ ] Add integration test harness with Docker
- [ ] Add e2e matrix across common distros
- [ ] Document remaining gaps and prioritize

