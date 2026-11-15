#!/usr/bin/env bash
# Sets up this Neovim config without questions, for people and for AI agents.
#
# Usage: scripts/install.sh [--yes] [--dry-run] [--skip-odoo-ls] [--skip-bootstrap]
#   --yes             do not ask before moving an existing config out of the way
#   --dry-run         only report what is missing and what would be done
#   --skip-odoo-ls    do not download the Odoo language server
#   --skip-bootstrap  do not pre-install plugins, tools and parsers (nvim does it on first start)
#
# What it does: checks the required programs (and prints the command to install the missing
# ones: it never runs sudo itself), links this folder as the Neovim config, installs odoo-ls
# into ~/.local, pre-installs plugins / Mason tools / Treesitter parsers, and links the
# `odoo-nvim` command into ~/.local/bin.
#
# The last line is "RESULT: ok" or "RESULT: failed (<reason>)"; the exit code is 0 or 1.
# Honours XDG_CONFIG_HOME and NVIM_APPNAME.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
yes=0 dry=0 odoo_ls=1 bootstrap=1
for arg in "$@"; do
    case "$arg" in
        --yes | -y) yes=1 ;;
        --dry-run) dry=1 ;;
        --skip-odoo-ls) odoo_ls=0 ;;
        --skip-bootstrap) bootstrap=0 ;;
        -h | --help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
need tree-sitter-cli tree-sitter
need nodejs node
need python3 python3
optional docker "the Odoo commands (update, test, logs, debug) need Docker with the compose plugin"
optional lazygit "git UI on <Space>gg"
optional claude "Claude Code panel on <Space>a"

if have nvim; then
    if ! nvim --headless -u NONE -i NONE "+lua if vim.fn.has('nvim-0.11') == 0 then vim.cmd('cquit 1') end" +qa > /dev/null 2>&1; then
        printf '  TOO OLD  nvim: 0.11 or newer is needed (%s)\n' "$(nvim --version | head -1)"
        missing+=("neovim>=0.11")
    fi
fi

if [ "${#missing[@]}" -gt 0 ]; then
    echo
    echo "Install the missing programs, then run this script again. For example:"
    list="${missing[*]}"
    # the names above are the common package names; two differ on some systems
    if have apt-get; then
        echo "  sudo apt-get install -y $list"
        echo "  Debian/Ubuntu notes: the package for fd is 'fd-find'; tree-sitter-cli comes from"
        echo "  'npm install -g tree-sitter-cli'; if the packaged neovim is older than 0.11, take the"
        echo "  release from https://github.com/neovim/neovim/releases"
    elif have dnf; then
        echo "  sudo dnf install -y $list"
        echo "  Fedora note: the package for fd is 'fd-find'."
    elif have pacman; then
        echo "  sudo pacman -S --needed $list"
    elif have brew; then
        echo "  brew install $list"
    else
        echo "  $list"
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
