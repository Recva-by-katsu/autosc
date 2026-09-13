#!/bin/bash
# Smoke tests for the supported operating-system matrix.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/ubuntu" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
PRETTY_NAME="Ubuntu 24.04 LTS"
EOF
OS_RELEASE_FILE="$tmp/ubuntu" KATSU_CONF_DIR="$tmp/conf" \
    bash data/system-check.sh --write >/dev/null
grep -qx 'OS_ID=ubuntu' "$tmp/conf/system.conf"
grep -qx 'OS_VERSION=24.04' "$tmp/conf/system.conf"

cat > "$tmp/unsupported" <<'EOF'
ID=ubuntu
VERSION_ID="18.04"
PRETTY_NAME="Ubuntu 18.04 LTS"
EOF
if OS_RELEASE_FILE="$tmp/unsupported" bash data/system-check.sh >/dev/null 2>&1; then
    echo "unsupported release was accepted" >&2
    exit 1
fi

echo "system compatibility checks passed"
