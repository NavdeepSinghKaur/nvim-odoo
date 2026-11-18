#!/usr/bin/env bash
# Sets up this Neovim config without questions, for people and for AI agents.
#
# Usage: scripts/install.sh [--yes] [--dry-run] [--skip-odoo-ls] [--skip-bootstrap] [--skip-font]
#   --yes             do not ask before moving an existing config out of the way
#   --dry-run         only report what is missing and what would be done
#   --skip-odoo-ls    do not download the Odoo language server
#   --skip-bootstrap  do not pre-install plugins, tools and parsers (nvim does it on first start)
#   --skip-font       do not install the Nerd Font (on WSL it goes to Windows, see install-font.sh)
#
# What it does: checks the required programs and that python3 can make a venv (Mason needs it).
# It prints the commands to install what is missing and never runs sudo itself. Then it links
# this folder as the Neovim config, installs odoo-ls into ~/.local, pre-installs plugins / Mason
# tools (including the tree-sitter CLI, which needs no Node.js or npm) / Treesitter parsers, and
# links the `odoo-nvim` command into ~/.local/bin.
#
# The last line is "RESULT: ok" or "RESULT: failed (<reason>)"; the exit code is 0 or 1.
# Honours XDG_CONFIG_HOME and NVIM_APPNAME.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
yes=0 dry=0 odoo_ls=1 bootstrap=1 font=1
for arg in "$@"; do
    case "$arg" in
        --yes | -y) yes=1 ;;
        --dry-run) dry=1 ;;
        --skip-odoo-ls) odoo_ls=0 ;;
        --skip-bootstrap) bootstrap=0 ;;
        --skip-font) font=0 ;;
        -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

fail() {
    echo "RESULT: failed ($1)"
    exit 1
}
step() { printf '\n== %s\n' "$1"; }

# ---------------------------------------------------------------- required programs
step "Checking required programs"
missing=()
too_old=0 # nvim is installed but older than needed: the package manager may not have a newer one
have() { command -v "$1" > /dev/null 2>&1; }
need() { # need <package name> <command> [alternative command...]
    local package="$1"
    shift
    for cmd in "$@"; do
        if have "$cmd"; then
            printf '  ok       %s\n' "$cmd"
            return
        fi
    done
    printf '  MISSING  %s\n' "$1"
    missing+=("$package")
}
optional() { # optional <command> <what it is for>
    if have "$1"; then printf '  ok       %s\n' "$1"; else printf '  optional %s: %s\n' "$1" "$2"; fi
}

need neovim nvim
need git git
need curl curl
need unzip unzip
need gcc cc gcc clang
need ripgrep rg
need fd fd fdfind
need tar tar
need gzip gzip
need python3 python3
if python3 -m venv --help > /dev/null 2>&1; then
    echo "  ok       python3 -m venv"
else
    echo "  MISSING  python3 -m venv"
    missing+=("python3-venv")
fi
optional docker "the Odoo commands (update, test, logs, debug) need Docker with the compose plugin"
optional lazygit "git UI on <Space>gg"
optional claude "Claude Code panel on <Space>a"
optional make "only for \`make check\` when you change this config"
clipboard=0
for tool in wl-copy xclip xsel pbcopy win32yank.exe clip.exe; do have "$tool" && clipboard=1; done
if [ "$clipboard" -eq 1 ]; then
    echo "  ok       clipboard"
else
    echo "  optional clipboard: install wl-clipboard or xclip (yank/paste with the system clipboard)"
fi

if have nvim; then
    if ! nvim --headless -u NONE -i NONE "+lua if vim.fn.has('nvim-0.12') == 0 then vim.cmd('cquit 1') end" +qa > /dev/null 2>&1; then
        printf '  TOO OLD  nvim: 0.12 or newer is needed (%s)\n' "$(nvim --version | head -1)"
        missing+=("neovim")
        too_old=1
    fi
fi

if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "Install the missing programs, then run this script again. For example:"
    list="${missing[*]}"
    packages="$list"
    if have apt-get; then
        echo "  sudo apt-get install -y $packages"
        echo "  Debian/Ubuntu note: the package for fd is 'fd-find'."
    elif have dnf; then
        echo "  sudo dnf install -y $packages"
        echo "  Fedora note: the package for fd is 'fd-find'."
    elif have pacman; then
        echo "  sudo pacman -S --needed $packages"
    elif have brew; then
        echo "  brew install $packages"
    else
        echo "  $packages"
    fi
    if [ "$too_old" -eq 1 ]; then
        echo "  Neovim 0.12 or newer: if your package manager has an older one, take the release"
        echo "  from https://github.com/neovim/neovim/releases"
    fi
    [ "$dry" -eq 1 ] || fail "missing programs: $list"
fi

# ---------------------------------------------------------------- link the config
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
target="$config_home/${NVIM_APPNAME:-nvim}"
step "Neovim config folder: $target"
if [ "$(readlink -f "$target" 2> /dev/null)" = "$(readlink -f "$repo")" ]; then
    echo "  already this folder"
elif [ "$dry" -eq 1 ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then echo "  would move the existing one to $target.bak.<date>"; fi
    echo "  would link $target -> $repo"
else
    if [ -e "$target" ] || [ -L "$target" ]; then
        backup="$target.bak.$(date +%Y%m%d-%H%M%S)"
        if [ "$yes" -eq 0 ]; then
            printf '  %s exists. Move it to %s? [y/N] ' "$target" "$backup"
            read -r answer
            case "$answer" in y | Y | yes) ;; *) fail "existing config kept; rerun with --yes to move it" ;; esac
        fi
        mv "$target" "$backup" || fail "could not move $target"
        echo "  moved the existing config to $backup"
    fi
    mkdir -p "$config_home"
    ln -s "$repo" "$target" || fail "could not link $target"
    echo "  linked $target -> $repo"
fi

# ---------------------------------------------------------------- odoo-ls
if [ "$odoo_ls" -eq 1 ]; then
    step "Odoo language server (odoo-ls $(tr -d '[:space:]' < "$repo/scripts/odoo-ls.version"))"
    if [ "$dry" -eq 1 ]; then
        echo "  would run scripts/install-odoo-ls.sh"
    else
        "$repo/scripts/install-odoo-ls.sh" || fail "odoo-ls install"
    fi
fi

# ---------------------------------------------------------------- plugins, tools, parsers
if [ "$bootstrap" -eq 1 ]; then
    step "Plugins, Mason tools and Treesitter parsers (a few minutes the first time)"
    if [ "$dry" -eq 1 ]; then
        echo "  would run: nvim --headless \"+luafile scripts/bootstrap.lua\""
    else
        nvim --headless "+luafile $repo/scripts/bootstrap.lua" || fail "bootstrap, see the STEP lines above"
    fi
fi

# ---------------------------------------------------------------- Nerd Font
# Not required: a failure here only means icons show as '?', so it never fails the install.
if [ "$font" -eq 1 ]; then
    step "Nerd Font (draws the icons)"
    if [ "$dry" -eq 1 ]; then "$repo/scripts/install-font.sh" --dry-run; else "$repo/scripts/install-font.sh"; fi ||
        echo "  optional Nerd Font not installed; icons show as '?' (see README, Requirements)"
fi

# ---------------------------------------------------------------- odoo-nvim command
step "odoo-nvim command"
if [ "$dry" -eq 1 ]; then
    echo "  would link ~/.local/bin/odoo-nvim -> $repo/scripts/odoo-nvim"
else
    mkdir -p "$HOME/.local/bin"
    ln -sf "$repo/scripts/odoo-nvim" "$HOME/.local/bin/odoo-nvim" || fail "could not link odoo-nvim"
    echo "  linked ~/.local/bin/odoo-nvim"
    case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "  Add ~/.local/bin to your PATH." ;; esac
fi

cat << 'NEXT'

Next: tell it where your Odoo project is.
  odoo-nvim setup --workspace ~/path/to/your-addons-repo     (or :Odoo setup inside nvim)
  odoo-nvim doctor                                            (checks everything)
NEXT
if [ "$dry" -eq 1 ]; then echo "RESULT: ok (dry run, nothing changed)"; else echo "RESULT: ok"; fi
