#!/usr/bin/env bash
# Install the Swamp Club theme for Ghostty.
#
#   curl -fsSL https://raw.githubusercontent.com/sntxrr/ghostty-swamp-club/main/install.sh | bash
#
# What it does, in order:
#   1. writes the theme to ~/.config/ghostty/themes/swamp-club
#      (the only place Ghostty looks for user themes, on every OS)
#   2. finds your Ghostty config, backs it up, and sets `theme = swamp-club`
#      (replacing an existing `theme =` line if there is one)
#   3. runs `ghostty +validate-config` when the CLI is on PATH
#
# Flags:  --dry-run        show what would change, write nothing
#         --config PATH    use this config file instead of auto-detecting
#         --theme-only     install the theme file, leave your config alone
set -euo pipefail

THEME_URL="https://raw.githubusercontent.com/sntxrr/ghostty-swamp-club/main/themes/swamp-club"
XDG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_DIR="$XDG/ghostty/themes"
CONFIG=""
DRY_RUN=0
THEME_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    DRY_RUN=1 ;;
        --theme-only) THEME_ONLY=1 ;;
        --config)     CONFIG="$2"; shift ;;
        -h|--help)    sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

# Prefer a local copy when run from a clone; otherwise fetch from GitHub.
here=""
if here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"; then :; else here=""; fi
if [ -n "$here" ] && [ -f "$here/themes/swamp-club" ]; then
    theme="$(cat "$here/themes/swamp-club")"
else
    theme="$(curl -fsSL "$THEME_URL")"
fi
[ -n "$theme" ] || { echo "error: theme file is empty" >&2; exit 1; }

# Ghostty reads both of these on macOS and only the XDG one elsewhere.
if [ -z "$CONFIG" ]; then
    mac_cfg="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
    if [ -f "$XDG/ghostty/config" ]; then
        CONFIG="$XDG/ghostty/config"
    elif [ "$(uname -s)" = "Darwin" ] && [ -f "$mac_cfg" ]; then
        CONFIG="$mac_cfg"
    else
        CONFIG="$XDG/ghostty/config"
    fi
fi

if [ "$DRY_RUN" = 1 ]; then
    echo "--- dry run ---"
    echo "would write  $THEME_DIR/swamp-club"
    if [ "$THEME_ONLY" = 0 ]; then
        echo "would edit   $CONFIG"
        if [ -f "$CONFIG" ] && grep -Eq '^[[:space:]]*theme[[:space:]]*=' "$CONFIG"; then
            echo "  replacing:  $(grep -E '^[[:space:]]*theme[[:space:]]*=' "$CONFIG" | head -1)"
        else
            echo "  appending:  theme = swamp-club"
        fi
    fi
    exit 0
fi

mkdir -p "$THEME_DIR"
printf '%s\n' "$theme" > "$THEME_DIR/swamp-club"
echo "wrote  $THEME_DIR/swamp-club"

if [ "$THEME_ONLY" = 0 ]; then
    mkdir -p "$(dirname "$CONFIG")"
    [ -f "$CONFIG" ] || : > "$CONFIG"
    backup="$CONFIG.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG" "$backup"
    if grep -Eq '^[[:space:]]*theme[[:space:]]*=' "$CONFIG"; then
        # Replace the first live `theme =` line in place; drop any later duplicates.
        awk 'BEGIN{done=0}
             /^[[:space:]]*theme[[:space:]]*=/ { if (!done) { print "theme = swamp-club"; done=1 }; next }
             { print }' "$backup" > "$CONFIG"
    else
        printf '\n# Swamp Club -- https://github.com/sntxrr/ghostty-swamp-club\ntheme = swamp-club\n' >> "$CONFIG"
    fi
    echo "wrote  $CONFIG  (theme = swamp-club)"
    echo "backup $backup"
fi

if command -v ghostty >/dev/null 2>&1; then
    if ghostty +validate-config >/dev/null 2>&1; then
        echo "valid  ghostty +validate-config passed"
    else
        echo "warn   ghostty +validate-config reported a problem:" >&2
        ghostty +validate-config >&2 || true
    fi
fi

echo
echo "Reload Ghostty to apply:  Cmd+Shift+,  on macOS   /   Ctrl+Shift+,  elsewhere"
