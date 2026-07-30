pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colour palette.
//
// Reads a Material You style scheme from Config.schemePath. The format
// matches what caelestia writes, so its generated schemes can be dropped
// in directly, but nothing here depends on caelestia being installed.
//
// The m3 prefix is mandatory, not stylistic: QML parses identifiers of
// the form on + Uppercase as signal handlers, so a property literally
// named `onSurface` or `onPrimary` fails to compile.
Singleton {
    id: root

    property bool loaded: false
    property string mode: "dark"

    // Neutral defaults, used until a scheme loads or when none exists.
    property color m3background: "#101418"
    property color m3onBackground: "#e0e2e8"
    property color m3surface: "#101418"
    property color m3surfaceContainer: "#1c2024"
    property color m3surfaceContainerHigh: "#262a2e"
    property color m3surfaceContainerHighest: "#313539"
    property color m3onSurface: "#e0e2e8"
    property color m3onSurfaceVariant: "#c0c7cd"
    property color m3primary: "#a3c9e9"
    property color m3onPrimary: "#04314c"
    property color m3primaryContainer: "#22485f"
    property color m3error: "#ffb4ab"
    property color m3outline: "#8a9297"

    readonly property var keys: ["background", "onBackground", "surface", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "onSurface", "onSurfaceVariant", "primary", "onPrimary", "primaryContainer", "error", "outline"]

    function apply(raw: string): bool {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            console.warn("quickgreet: could not parse scheme:", e);
            return false;
        }

        const c = data.colours ?? data.colors;
        if (!c)
            return false;

        if (data.mode)
            root.mode = data.mode;

        for (const key of root.keys) {
            const val = c[key];
            if (!val)
                continue;
            root["m3" + key] = val.startsWith("#") ? val : "#" + val;
        }

        root.loaded = true;
        return true;
    }

    FileView {
        path: Config.schemePath
        onLoaded: root.apply(text())
        onLoadFailed: console.log("quickgreet: no scheme file, using default palette")
    }
}
