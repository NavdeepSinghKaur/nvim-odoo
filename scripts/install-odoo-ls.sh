#!/usr/bin/env bash
# Installs odoo-ls (Odoo's language server) into ~/.local/share/odoo-ls/<version> and links
# ~/.local/bin/odoo_ls_server. No sudo needed.
#
# Usage: scripts/install-odoo-ls.sh [--force] [version]
#   version  default: the one pinned in scripts/odoo-ls.version
#   --force  download again even if that version is already installed
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
force=0
version=""
for arg in "$@"; do
    case "$arg" in
        --force) force=1 ;;
        -h | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) version="$arg" ;;
    esac
done
[ -n "$version" ] || version="$(tr -d '[:space:]' < "$here/odoo-ls.version")"

case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported OS (see https://github.com/odoo/odoo-ls/releases)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    arm64 | aarch64) arch=aarch64 ;;
    *) echo "Unsupported CPU (see https://github.com/odoo/odoo-ls/releases)" >&2; exit 1 ;;
esac

base="https://github.com/odoo/odoo-ls/releases/download/$version"
dest="$HOME/.local/share/odoo-ls/$version"
link="$HOME/.local/bin/odoo_ls_server"
server_archive="odoo-$os-$arch-$version.tar.gz"

link_server() {
    mkdir -p "$HOME/.local/bin"
    ln -sf "$dest/odoo_ls_server" "$link"
    echo "Installed: $link -> $dest/odoo_ls_server"
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "Add ~/.local/bin to your PATH." ;; esac
}

if [ "$force" -eq 0 ] && [ -x "$dest/odoo_ls_server" ] && [ -d "$dest/typeshed" ]; then
    echo "odoo-ls $version is already installed (use --force to download it again)."
    link_server
    exit 0
fi

sha256_of() {
    if command -v sha256sum > /dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Compare a download with the digest GitHub publishes for the release asset.
# Without a published digest (old release, API not reachable) the check is skipped with a note.
verify() {
    local file="$1" name="$2" expected actual
    expected="$(printf '%s' "$digests" | python3 -c '
import json, sys
name = sys.argv[1]
try:
    assets = json.load(sys.stdin).get("assets", [])
except ValueError:
    assets = []
for asset in assets:
    if asset.get("name") == name and (asset.get("digest") or "").startswith("sha256:"):
        print(asset["digest"][len("sha256:"):])
' "$name")"
    if [ -z "$expected" ]; then
        echo "Note: no published checksum for $name, not verified."
        return 0
    fi
    actual="$(sha256_of "$file")"
    if [ "$expected" != "$actual" ]; then
        echo "Checksum mismatch for $name: expected $expected, got $actual" >&2
        exit 1
    fi
    echo "Checksum ok: $name"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading odoo-ls $version ($os-$arch)…"
curl -fL --progress-bar "$base/$server_archive" -o "$tmp/server.tar.gz"
curl -fL --progress-bar "$base/typeshed.zip" -o "$tmp/typeshed.zip"
digests="$(curl -fsSL "https://api.github.com/repos/odoo/odoo-ls/releases/tags/$version" 2> /dev/null || true)"
verify "$tmp/server.tar.gz" "$server_archive"
verify "$tmp/typeshed.zip" "typeshed.zip"

tar -xzf "$tmp/server.tar.gz" -C "$tmp"
bin="$(find "$tmp" -type f -name odoo_ls_server | head -1)"
[ -n "$bin" ] || { echo "odoo_ls_server not found in the archive" >&2; exit 1; }
mkdir -p "$dest"
install -m 755 "$bin" "$dest/odoo_ls_server"
# the server needs typeshed/ next to it
rm -rf "$dest/typeshed"
mkdir -p "$dest/typeshed"
unzip -q "$tmp/typeshed.zip" -d "$dest/typeshed"
link_server
