pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// quickgreet settings.
//
// Loaded from JSON at QUICKGREET_CONFIG, defaulting to
// /etc/quickgreet/config.json. The file is entirely optional: every
// value has a sane default, because a greeter must start even when its
// configuration is missing or malformed.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("QUICKGREET_CONFIG") || "/etc/quickgreet/config.json"

    // UI language: "en", "ru", or "auto" to follow the system locale.
    property string locale: "en"

    // Background. An empty string falls back to the palette's base colour.
    property string wallpaper: ""
    property real blur: 0.85
    property real dim: 0.72

    // Material You style palette: {"mode", "colours": {...}}.
    // Compatible with caelestia's generated schemes, but not tied to it.
    property string schemePath: "/etc/quickgreet/scheme.json"

    // Helper scripts. Packages install them here; running from a source
    // checkout, test.sh points this at ./scripts instead.
    property string scriptsDir: Quickshell.env("QUICKGREET_SCRIPTS") || "/usr/lib/quickgreet"

    // Initial selection. Empty means "first entry in the list".
    property string defaultSession: ""
    property string defaultUser: ""

    property bool showPowerButtons: true

    // Qt date/time format strings.
    property string timeFormat: "HH:mm"
    property string dateFormat: "dddd, d MMMM"

    readonly property string effectiveLocale: {
        if (locale !== "auto")
            return locale;
        const sys = Qt.locale().name;  // e.g. "ru_RU"
        return sys.startsWith("ru") ? "ru" : "en";
    }

    function script(name: string): string {
        return scriptsDir + "/" + name;
    }

    function apply(raw: string): void {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            console.warn("quickgreet: could not parse config.json:", e);
            return;
        }

        for (const key in data) {
            if (root.hasOwnProperty(key))
                root[key] = data[key];
            else
                console.warn("quickgreet: unknown setting:", key);
        }
    }

    FileView {
        path: root.configPath
        onLoaded: root.apply(text())
        onLoadFailed: console.log("quickgreet: no config file, using defaults")
    }
}
