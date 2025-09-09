#!/usr/bin/env bats

load '../test_helper'

@test "version comparator: 1.2.3 >= 1.2.3" {
  run bash -lc 'source ./scripts/lib/version.sh; kiro_version_sort_ge 1.2.3 1.2.3; echo $?'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "version comparator: 1.2.4 >= 1.2.3" {
  run bash -lc 'source ./scripts/lib/version.sh; kiro_version_sort_ge 1.2.4 1.2.3; echo $?'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "version comparator: 1.2.3 !>= 1.2.4" {
  run bash -lc 'source ./scripts/lib/version.sh; set +e; kiro_version_sort_ge 1.2.3 1.2.4; rc=$?; echo "$rc"; exit 0'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

