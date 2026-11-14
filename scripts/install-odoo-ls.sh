#!/usr/bin/env bash
# Installs odoo-ls (Odoo's language server) into ~/.local/share/odoo-ls/<version> and links
# ~/.local/bin/odoo_ls_server. No sudo needed. Usage: scripts/install-odoo-ls.sh [version]
set -euo pipefail
version="${1:-1.6.2}"
case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) echo "Unsupported OS (see https://github.com/odoo/odoo-ls/releases)"; exit 1 ;; esac
case "$(uname -m)" in x86_64 | amd64) arch=x86_64 ;; arm64 | aarch64) arch=aarch64 ;; *) echo "Unsupported CPU"; exit 1 ;; esac
base="https://github.com/odoo/odoo-ls/releases/download/$version"
dest="$HOME/.local/share/odoo-ls/$version"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$dest" "$HOME/.local/bin"
echo "Downloading odoo-ls $version ($os-$arch)…"
curl -fL "$base/odoo-$os-$arch-$version.tar.gz" -o "$tmp/server.tar.gz"
curl -fL "$base/typeshed.zip" -o "$tmp/typeshed.zip"
tar -xzf "$tmp/server.tar.gz" -C "$tmp"
bin="$(find "$tmp" -type f -name odoo_ls_server | head -1)"
[ -n "$bin" ] || { echo "odoo_ls_server not found in the archive"; exit 1; }
install -m 755 "$bin" "$dest/odoo_ls_server"
rm -rf "$dest/typeshed" && mkdir -p "$dest/typeshed" && unzip -q "$tmp/typeshed.zip" -d "$dest/typeshed" # the server needs typeshed/ next to it
ln -sf "$dest/odoo_ls_server" "$HOME/.local/bin/odoo_ls_server"
echo "Installed: $HOME/.local/bin/odoo_ls_server -> $dest/odoo_ls_server"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "Add ~/.local/bin to your PATH." ;; esac
