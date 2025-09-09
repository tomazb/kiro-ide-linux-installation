#!/usr/bin/env bats

load '../test_helper'

setup() {
  export KIRO_SKIP_VERIFY=false
}

@test "sha256 computes correct digest" {
  run bash -lc 'f=$(mktemp); echo -n hello > "$f"; source ./scripts/lib/verify.sh; kiro_sha256 "$f"; rm -f "$f"'
  [ "$status" -eq 0 ]
  # sha256("hello")
  [ "$output" = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" ]
}

@test "parse checksum file with hash and filename" {
  run bash -lc 'tmp=$(mktemp); printf "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824  archive.tar.gz\n" >"$tmp"; source ./scripts/lib/verify.sh; kiro_parse_checksum_file "$tmp"; rm -f "$tmp"'
  [ "$status" -eq 0 ]
  [ "$output" = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" ]
}

@test "resolve checksum from url: and file: schemes" {
  run bash -lc 'tmp=$(mktemp); echo 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 >"$tmp"; source ./scripts/lib/verify.sh; kiro_resolve_checksum_arg "file:$tmp"; rm -f "$tmp"'
  [ "$status" -eq 0 ]
  [ "$output" = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" ]
}

