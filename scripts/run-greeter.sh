#!/usr/bin/env bash
# Launches the greeter's compositor with a usable environment.
#
# This is what greetd runs. It exists mainly to resolve a cursor theme
# before any client starts: a cursor theme that is configured but not
# installed is worse than none at all. The compositor falls back to a
# built-in pointer while clients keep drawing their own, so two cursors
# appear and the fallback visibly lags behind.
#
# Hyprland's `env` directive cannot run a command, so the theme has to be
# chosen out here and exported before the compositor comes up.

set -u

CONF="${QUICKGREET_HYPRLAND_CONF:-/etc/quickgreet/hyprland.conf}"

# The compositor is overridable so the greeter is not welded to Hyprland.
# Only Hyprland can report or switch the keyboard layout, so the badge
# goes inert elsewhere, but everything else works under cage, sway or
# labwc. Word splitting here is intended: the value is a command line.
COMPOSITOR="${QUICKGREET_COMPOSITOR:-Hyprland -c $CONF}"

# Themes to prefer when several are installed, most neutral first. Any
# installed theme beats none, so this is only about which one looks least
# out of place — the fallback below accepts whatever exists.
PREFERRED=(
    Adwaita
    breeze_cursors
    Breeze_Light
    default
    DMZ-White
    Vanilla-DMZ
    capitaine-cursors
    Qogir
)

ICON_DIRS=(
    "${XDG_DATA_HOME:-$HOME/.local/share}/icons"
    "$HOME/.icons"
    /usr/local/share/icons
    /usr/share/icons
)

# A directory is a cursor theme only if it actually contains cursors;
# plenty of icon themes have no pointer at all.
has_cursors() {
    [ -d "$1/cursors" ] && [ -n "$(ls -A "$1/cursors" 2>/dev/null)" ]
}

find_theme() {
    local dir name

    for name in "${PREFERRED[@]}"; do
        for dir in "${ICON_DIRS[@]}"; do
            has_cursors "$dir/$name" && { echo "$name"; return 0; }
        done
    done

    # Nothing preferred is present: take the first theme that exists.
    for dir in "${ICON_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        for candidate in "$dir"/*; do
            has_cursors "$candidate" && { basename "$candidate"; return 0; }
        done
    done

    return 1
}

if theme=$(find_theme); then
    export XCURSOR_THEME="$theme"
    export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
    echo "quickgreet: cursor theme $theme" >&2
else
    # No cursor theme anywhere. Leave the variables unset rather than
    # naming something absent, so the compositor uses its own default
    # instead of failing to load a named theme and doubling the pointer.
    unset XCURSOR_THEME
    echo "quickgreet: no cursor theme installed, using compositor default" >&2
fi

# Keep the compositor's output somewhere that outlives the session. Its
# own log lives under the greeter's XDG_RUNTIME_DIR, which logind removes
# the moment the session ends, so a startup failure leaves nothing to read.
LOG="${QUICKGREET_LOG:-/var/log/quickgreet.log}"
if : >>"$LOG" 2>/dev/null; then
    echo "--- $(date +%FT%T%z) greeter starting ---" >>"$LOG"
    exec $COMPOSITOR >>"$LOG" 2>&1
fi

# Falling back silently is what made a startup failure unreadable in the
# first place, so say why before giving up on the log.
echo "quickgreet: cannot write $LOG; compositor output will be discarded" >&2
exec $COMPOSITOR
