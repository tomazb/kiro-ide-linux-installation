#!/usr/bin/env bats

load '../test_helper'

@test "offline install with --package and signature verifies and installs to user dir" {
  run bash -lc '
    set -e
    tmpd=$(mktemp -d)
    trap "rm -rf \"$tmpd\"" EXIT

    # Build mock payload
    mkdir -p "$tmpd/payload/Kiro/bin"
    cat > "$tmpd/payload/Kiro/bin/kiro" <<"EOS"
#!/usr/bin/env bash
if [[ "${1:-}" == "-v" || "${1:-}" == "--version" ]]; then
  echo 0.0.1
  exit 0
fi
printf "Kiro Mock\n"
EOS
    chmod +x "$tmpd/payload/Kiro/bin/kiro"

    # Package
    tar -C "$tmpd/payload" -czf "$tmpd/kiro.tar.gz" Kiro

    # Sign and provide certificate next to archive
    openssl genrsa -out "$tmpd/key.pem" 2048 >/dev/null 2>&1
    openssl req -x509 -new -key "$tmpd/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "$tmpd/certificate.pem" >/dev/null 2>&1
    openssl dgst -sha256 -sign "$tmpd/key.pem" -out "$tmpd/signature.bin" "$tmpd/kiro.tar.gz" >/dev/null 2>&1

    # Install to temp user directories
    export KIRO_USER_INSTALL_DIR="$tmpd/install"
    export KIRO_SYMLINK_DIR_USER="$tmpd/bin"
    export KIRO_DESKTOP_DIR_USER="$tmpd/applications"
    export KIRO_SKIP_DEPS=true

    ./scripts/install-kiro.sh --user --package "file:$tmpd/kiro.tar.gz"

    # Assertions inside the subshell for simplicity
    test -x "$tmpd/install/bin/kiro"
    test -L "$tmpd/bin/kiro"
    "$tmpd/install/bin/kiro" -v | grep -q '^0\.0\.1$'
  '

  [ "$status" -eq 0 ]
}

