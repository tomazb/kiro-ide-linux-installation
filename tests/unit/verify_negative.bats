#!/usr/bin/env bats

load '../test_helper'

setup() {
  export KIRO_SKIP_VERIFY=false
}

@test "checksum mismatch aborts verify" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    echo hello > "$tmpd/file.bin"
    # Provide a wrong checksum via hex
    export KIRO_CHECKSUM=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
    source ./scripts/lib/log.sh
    source ./scripts/lib/net.sh
    source ./scripts/lib/verify.sh
    if kiro_verify_archive "$tmpd/file.bin" "file:$tmpd/file.bin"; then echo ok; else echo fail; fi'
  [ "$status" -eq 0 ]
  # Should print fail at the end
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" = "fail" ]
}

@test "signature present but invalid aborts verify" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    echo data > "$tmpd/file.bin"
    # Generate cert and sign a different file to cause invalid signature
    openssl genrsa -out "$tmpd/key.pem" 2048 >/dev/null 2>&1
    openssl req -x509 -new -key "$tmpd/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "$tmpd/cert.pem" >/dev/null 2>&1
    echo other > "$tmpd/other.bin"
    openssl dgst -sha256 -sign "$tmpd/key.pem" -out "$tmpd/sig.bin" "$tmpd/other.bin" >/dev/null 2>&1
    export KIRO_SIG="file:$tmpd/sig.bin"
    export KIRO_CERT="file:$tmpd/cert.pem"
    source ./scripts/lib/log.sh
    source ./scripts/lib/net.sh
    source ./scripts/lib/verify.sh
    if kiro_verify_archive "$tmpd/file.bin" "file:$tmpd/file.bin"; then echo ok; else echo fail; fi'
  [ "$status" -eq 0 ]
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" = "fail" ]
}

@test "colocated certificate.pem and signature.bin are detected for file: URLs" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    echo payload > "$tmpd/file.bin"
    # Create signature and cert, colocate as certificate.pem and signature.bin
    openssl genrsa -out "$tmpd/key.pem" 2048 >/dev/null 2>&1
    openssl req -x509 -new -key "$tmpd/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "$tmpd/certificate.pem" >/dev/null 2>&1
    openssl dgst -sha256 -sign "$tmpd/key.pem" -out "$tmpd/signature.bin" "$tmpd/file.bin" >/dev/null 2>&1
    # Clear env to force autodiscovery
    unset KIRO_SIG || true
    unset KIRO_CERT || true
    source ./scripts/lib/log.sh
    source ./scripts/lib/net.sh
    source ./scripts/lib/verify.sh
    kiro_verify_archive "$tmpd/file.bin" "file:$tmpd/file.bin"; echo $?'
  [ "$status" -eq 0 ]
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" -eq 0 ]
}

@test "insecure http blocked by default" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    source ./scripts/lib/log.sh
    source ./scripts/lib/net.sh
    if kiro_net_download "http://example.invalid/file" "$tmpd/out" 1; then echo ok; else echo fail; fi'
  [ "$status" -eq 0 ]
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" = "fail" ]
}

