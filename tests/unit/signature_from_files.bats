#!/usr/bin/env bats

load '../test_helper'

setup() {
  export KIRO_SKIP_VERIFY=false
}

@test "signature verify: from files via KIRO_SIG and KIRO_CERT" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    echo testdata > "$tmpd/file.bin"
    # Generate key and self-signed cert
    openssl genrsa -out "$tmpd/key.pem" 2048 >/dev/null 2>&1
    openssl req -x509 -new -key "$tmpd/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "$tmpd/cert.pem" >/dev/null 2>&1
    # Sign with sha256
    openssl dgst -sha256 -sign "$tmpd/key.pem" -out "$tmpd/sig.bin" "$tmpd/file.bin" >/dev/null 2>&1
    export KIRO_SIG="file:$tmpd/sig.bin"
    export KIRO_CERT="file:$tmpd/cert.pem"
    source ./scripts/lib/log.sh
    source ./scripts/lib/verify.sh
    kiro_verify_signature "$tmpd/file.bin" "http://example.invalid/release/file.tar.gz"; echo $?'
  [ "$status" -eq 0 ]
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" -eq 0 ]
}

