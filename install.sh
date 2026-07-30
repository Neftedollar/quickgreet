#!/usr/bin/env bash
# Installs quickgreet system-wide.
#
#   sudo ./install.sh              install or update
#   sudo ./install.sh --uninstall  remove everything it installed
#
# Deliberately does NOT touch the display manager. Installing only puts
# files in place; switching the login screen over is a separate, reversible
# step described in the README.

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

QML_DIR=/usr/share/quickgreet
SCRIPT_DIR=/usr/lib/quickgreet
CONF_DIR=/etc/quickgreet

if [ "$(id -u)" -ne 0 ]; then
    echo "needs root: sudo $0 $*" >&2
    exit 1
fi

uninstall() {
    echo "removing quickgreet"
    rm -rf "$QML_DIR" "$SCRIPT_DIR"
    # Configuration is left in place on purpose: it contains the admin's
    # own settings, wallpaper and colour scheme.
    echo "removed $QML_DIR and $SCRIPT_DIR"
    echo "configuration kept at $CONF_DIR; delete it by hand if unwanted"
    exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

echo "installing quickgreet"

install -d "$QML_DIR" "$SCRIPT_DIR" "$CONF_DIR"

install -m 0644 "$here"/qml/*.qml "$QML_DIR/"
install -m 0755 "$here"/scripts/*.py "$here"/scripts/*.sh "$SCRIPT_DIR/"

# Configuration is never overwritten: an upgrade must not silently discard
# whatever the administrator set up.
for f in config.example.json greetd-test.toml hyprland.conf; do
    src="$here/config/$f"
    dst="$CONF_DIR/$f"
    if [ -e "$dst" ]; then
        echo "  keeping existing $dst"
    else
        install -m 0644 "$src" "$dst"
        echo "  installed $dst"
    fi
done

if [ ! -e "$CONF_DIR/config.json" ]; then
    install -m 0644 "$here/config/config.example.json" "$CONF_DIR/config.json"
    echo "  installed $CONF_DIR/config.json"
fi

# The greeter runs as an unprivileged user and must be able to read all
# of this.
chmod 0755 "$CONF_DIR"
find "$CONF_DIR" -type f -exec chmod 0644 {} +

echo
echo "installed:"
echo "  QML       $QML_DIR"
echo "  scripts   $SCRIPT_DIR"
echo "  config    $CONF_DIR"
echo
echo "next:"
echo "  1. edit $CONF_DIR/config.json (wallpaper, locale, default session)"
echo "  2. optional colour scheme from the wallpaper:"
echo "       $SCRIPT_DIR/gen-scheme.py IMAGE > $CONF_DIR/scheme.json"
echo "  3. test on a spare console, without touching your display manager:"
echo "       sudo greetd --config $CONF_DIR/greetd-test.toml"
echo "     then switch to it with Ctrl+Alt+F3"
echo "  4. if that works, see the README for making it permanent"
