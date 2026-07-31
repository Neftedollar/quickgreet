pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import QuickMaterial

// Feeds the token library from this application's configuration.
//
// QuickMaterial owns the roles and applies them; reading files is left to
// whoever has a way to read files. QML has neither a filesystem watcher nor
// permission to read local files over XMLHttpRequest without an environment
// variable, so a library cannot do this part — but Quickshell can, in one
// property.
//
// `watchChanges` is that property. Without it the scheme is read once at
// startup, which is fine for something that starts fresh every time and
// wrong for this: the agent is registered for the whole session and will
// outlive several changes of theme.
Singleton {
    id: root

    // Applied before any scheme file, so a machine without one still gets a
    // complete palette rather than the library's own defaults.
    Component.onCompleted: {
        Themes.use(Config.theme || "slate");
        _applyFonts();
    }

    function _applyFonts(): void {
        if (Config.fontFamily)
            Type.family = Config.fontFamily;
        if (Config.iconFontFamily)
            Type.iconFamily = Config.iconFontFamily;
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                root._applyFonts();
        }
    }

    // Waits for the config to settle before reading. Config loads its own
    // file asynchronously, so binding straight to Config.schemePath fires
    // once against the default path and logs a spurious failure before the
    // real path arrives.
    FileView {
        path: Config.ready ? Config.schemePath : ""
        watchChanges: true

        onLoaded: {
            try {
                Colours.applyScheme(JSON.parse(text()));
            } catch (e) {
                console.warn("quickgreet: could not parse scheme:", e);
            }
        }

        onLoadFailed: {
            if (Config.ready)
                console.log("quickgreet: no scheme file, using the built-in palette");
        }
    }
}
