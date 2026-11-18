#!/usr/bin/env bash
# Installs JetBrainsMono Nerd Font, the font that draws the icons, where the terminal can see it.
#
# Usage: scripts/install-font.sh [--dry-run]
#
#   Linux  the font goes to ~/.local/share/fonts (then fc-cache), unless a Nerd Font is there.
#   WSL    the terminal is a Windows program and only sees Windows fonts, so the font is installed
#          for the current Windows user (no admin needed): the files go to
#          %LOCALAPPDATA%\Microsoft\Windows\Fonts and are registered under HKCU.
#
# Windows Terminal (or any terminal) must still be set to "JetBrainsMono Nerd Font Mono" in its
# profile; this script prints that last step because it cannot do it safely for you.
# The font comes from the Linux copy when one exists, otherwise from the Nerd Fonts release.
# Testing: ODOO_NVIM_FONT_SOURCE=<folder with the .ttf files> skips the download and
# ODOO_NVIM_FORCE_WSL=1 / =0 overrides the WSL detection.
set -uo pipefail

dry=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1 ;;
        -h | --help) awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

have() { command -v "$1" > /dev/null 2>&1; }
say() { printf '  %s\n' "$*"; }
# the four styles the terminal needs; the Mono variant keeps icons one cell wide
styles=(Regular Bold Italic BoldItalic)
family="JetBrainsMono Nerd Font Mono"
url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

is_wsl() {
    case "${ODOO_NVIM_FORCE_WSL:-}" in 1) return 0 ;; 0) return 1 ;; esac
    grep -qi microsoft /proc/version 2> /dev/null
}

# Sets $source to the folder with the four .ttf files, downloading them when needed. It sets a
# variable instead of printing the path: inside $(...) the download folder would be made in a
# subshell, out of reach of the EXIT trap, and left behind.
workdir="" source=""
cleanup() { [ -z "$workdir" ] || rm -rf "$workdir"; }
trap cleanup EXIT
font_source() {
    local candidate dir
    for dir in "${ODOO_NVIM_FONT_SOURCE:-}" "$HOME/.local/share/fonts/JetBrainsMonoNerd" "$HOME/.local/share/fonts"; do
        [ -n "$dir" ] || continue
        candidate=1
        for style in "${styles[@]}"; do [ -f "$dir/JetBrainsMonoNerdFontMono-$style.ttf" ] || candidate=0; done
        if [ "$candidate" -eq 1 ]; then
            source="$dir"
            return 0
        fi
    done
    if ! have curl || ! have unzip; then
        say "need curl and unzip to download the font" >&2
        return 1
    fi
    workdir="$(mktemp -d)" || return 1
    say "downloading $url" >&2
    curl -fsSL -o "$workdir/font.zip" "$url" || { say "download failed" >&2; return 1; }
    unzip -qo "$workdir/font.zip" -d "$workdir/ttf" || { say "could not unzip the font" >&2; return 1; }
    source="$workdir/ttf"
}

install_linux() {
    local dest="$HOME/.local/share/fonts/JetBrainsMonoNerd" fonts
    if have fc-list; then
        fonts="$(fc-list 2> /dev/null)" # a pipe into grep -q would fail under pipefail (SIGPIPE)
        if grep -qi "nerd font" <<< "$fonts"; then
            say "ok       a Nerd Font is already installed"
            return 0
        fi
    fi
    if [ "$dry" -eq 1 ]; then
        say "would install $family into $dest"
        return 0
    fi
    font_source || return 1
    mkdir -p "$dest" || return 1
    for style in "${styles[@]}"; do cp "$source/JetBrainsMonoNerdFontMono-$style.ttf" "$dest/" || return 1; done
    if have fc-cache; then fc-cache -f "$dest" > /dev/null 2>&1; fi
    say "installed $family into $dest"
}

# Windows paths as the Windows tools print them (CRLF removed)
win() { "$@" 2> /dev/null | tr -d '\r'; }

install_windows() {
    if ! have powershell.exe || ! have reg.exe || ! have wslpath; then
        say "WSL without powershell.exe / reg.exe on the PATH: install the font on Windows by hand (README)"
        return 1
    fi
    local local_app dest dest_win system_fonts
    local_app="$(win powershell.exe -NoProfile -NonInteractive -Command '[Environment]::GetFolderPath("LocalApplicationData")')"
    [ -n "$local_app" ] || { say "could not read %LOCALAPPDATA% from Windows"; return 1; }
    dest="$(wslpath -u "$local_app")/Microsoft/Windows/Fonts"
    system_fonts="$(wslpath -u 'C:\Windows\Fonts' 2> /dev/null)"
    if compgen -G "$dest/*NerdFont*" > /dev/null || { [ -n "$system_fonts" ] && compgen -G "$system_fonts/*NerdFont*" > /dev/null; }; then
        say "ok       a Nerd Font is already installed on Windows"
        return 0
    fi
    if [ "$dry" -eq 1 ]; then
        say "would install $family for the current Windows user ($local_app\\Microsoft\\Windows\\Fonts)"
        return 0
    fi
    font_source || return 1
    mkdir -p "$dest" || return 1
    for style in "${styles[@]}"; do
        local file="JetBrainsMonoNerdFontMono-$style.ttf" label="$style"
        [ "$style" != BoldItalic ] || label="Bold Italic"
        cp "$source/$file" "$dest/" || return 1
        dest_win="$(wslpath -w "$dest/$file")"
        # a font file in the user folder only counts once it is registered under HKCU
        reg.exe add 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' /v "$family $label (TrueType)" \
            /t REG_SZ /d "$dest_win" /f > /dev/null 2>&1 || { say "could not register $file in the registry"; return 1; }
    done
    say "installed $family for the current Windows user"
}

if is_wsl; then
    echo "  WSL detected: the terminal uses Windows fonts"
    install_windows || exit 1
    say "last step, once: Windows Terminal > Settings > your WSL profile > Appearance > Font face:"
    say "  $family      (then close and reopen the terminal)"
else
    install_linux || exit 1
    say "select \"$family\" as the font in your terminal profile if icons still show as '?'"
fi
