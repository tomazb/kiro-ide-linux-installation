#!/usr/bin/env bats

load '../test_helper'

@test "offline install with --package and signature verifies and installs to user dir" {
  bash tests/integration/scripts/install_offline.sh
}

