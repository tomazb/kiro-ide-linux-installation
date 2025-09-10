#!/usr/bin/env bash
# Integration script: offline install with --package, checksum + signature
set -Ee -o pipefail

# Work dir auto-cleaned
workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT

# Build payload
mkdir -p "${workdir}/payload/Kiro/bin"
cat > "${workdir}/payload/Kiro/bin/kiro" <<'EOS'
#!/usr/bin/env bash
if [[ "${1:-}" == "-v" || "${1:-}" == "--version" ]]; then
  echo 0.0.1
  exit 0
fi
printf "Kiro Mock\n"
EOS
chmod +x "${workdir}/payload/Kiro/bin/kiro"

tar -C "${workdir}/payload" -czf "${workdir}/kiro.tar.gz" Kiro

# Sign and checksum
openssl genrsa -out "${workdir}/key.pem" 2048 >/dev/null 2>&1
openssl req -x509 -new -key "${workdir}/key.pem" -subj "/CN=Kirolabs Test" -days 1 -out "${workdir}/certificate.pem" >/dev/null 2>&1
openssl dgst -sha256 -sign "${workdir}/key.pem" -out "${workdir}/signature.bin" "${workdir}/kiro.tar.gz" >/dev/null 2>&1
hash=$(sha256sum "${workdir}/kiro.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "${hash}" "kiro.tar.gz" > "${workdir}/kiro.tar.gz.sha256"

# Install to temp paths (user mode)
export KIRO_USER_INSTALL_DIR="${workdir}/install"
export KIRO_SYMLINK_DIR_USER="${workdir}/bin"
export KIRO_DESKTOP_DIR_USER="${workdir}/applications"
export KIRO_SKIP_DEPS=true

./scripts/install-kiro.sh --user --require-verify \
  --package "file:${workdir}/kiro.tar.gz"

# Assertions
[ -x "${workdir}/install/bin/kiro" ]
[ -L "${workdir}/bin/kiro" ]
"${workdir}/install/bin/kiro" -v | grep -q '^0\.0\.1$'

