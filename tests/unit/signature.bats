#!/usr/bin/env bats

load '../test_helper'

setup() {
  export KIRO_SKIP_VERIFY=false
}

@test "signature verify: sha256 over file using self-signed cert" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT
    echo testdata > "$tmpd/file.bin"
    cat >"$tmpd/test.sh" <<"EOS"
set -e
file="$1"
# Generate key and self-signed cert
openssl genrsa -out "$TMPDIR/key.pem" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "$TMPDIR/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "$TMPDIR/cert.pem" >/dev/null 2>&1
# Sign with sha256
openssl dgst -sha256 -sign "$TMPDIR/key.pem" -out "$TMPDIR/sig.bin" "$file" >/dev/null 2>&1
sig_b64=$(base64 < "$TMPDIR/sig.bin" | tr -d "\n")
cert_pem=$(cat "$TMPDIR/cert.pem")
export KIRO_SIGNATURE_B64="$sig_b64"
export KIRO_CERT_PEM_CONTENT="$cert_pem"
source ./scripts/lib/log.sh
source ./scripts/lib/verify.sh
kiro_verify_signature "$file" "http://example.invalid/"; echo $?
EOS
    TMPDIR="$tmpd" bash "$tmpd/test.sh" "$tmpd/file.bin"'
  echo "status=$status output=$output"
  [ "$status" -eq 0 ]
  last_line_index=$(( ${#lines[@]} - 1 ))
  [ "${lines[$last_line_index]}" -eq 0 ]
}

