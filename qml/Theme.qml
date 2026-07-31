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
// Read once, deliberately. This process lives for seconds and is restarted
// every boot, so there is no change of theme for it to outlive — and it is
// the process holding the greetd socket, so turning a start-up read into a
// live re-parsed input needs a reason rather than an inherited habit. The
// comment justifying `watchChanges` here was copied from quickask, where it
// is true.
Singleton {
    id: root

    // Applied before any scheme file, so a machine without one still gets a
    // complete palette rather than the library's own defaults.
    //
    // Applied *again* once the configuration lands. Config reads its JSON
    // through a FileView that neither blocks nor preloads, so at completion
    // `Config.theme` is still the compiled-in default and nothing the user
    // wrote has arrived — an earlier version applied the theme here and only
    // the fonts on ready, which made the `theme` key silently do nothing.
    Component.onCompleted: _apply()

    function _apply(): void {
        Themes.use(Config.theme || "slate");
        if (Config.fontFamily)
            Type.family = Config.fontFamily;
        if (Config.iconFontFamily)
            Type.iconFamily = Config.iconFontFamily;
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                root._apply();
        }
    }

    // Waits for the config to settle before reading. Config loads its own
    // file asynchronously, so binding straight to Config.schemePath fires
    // once against the default path and logs a spurious failure before the
    // real path arrives.
    FileView {
        path: Config.ready ? Config.schemePath : ""

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
