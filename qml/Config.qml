pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// quickgreet settings.
//
// Loaded from JSON at QUICKGREET_CONFIG, defaulting to
// /etc/quickgreet/config.json. The file is entirely optional: every value
// has a sane default, because a greeter must start even when its
// configuration is missing or malformed.
//
// This singleton deliberately does not reference Strings. Language
// selection lives there, so that adding a language touches one file and
// the two singletons do not depend on each other.
Singleton {
    id: root

    readonly property string configPath: Quickshell.env("QUICKGREET_CONFIG") || "/etc/quickgreet/config.json"

    // True once the file has been read or definitively found missing.
    // Anything that acts on a configured path waits for this, otherwise it
    // acts on a default that is about to be replaced.
    property bool ready: false

    // ─────────────────────── settable from JSON ───────────────────────

    // "en", "ru", … or "auto" to follow the system. Validated by Strings;
    // an unknown value falls back to English with a warning.
    property string locale: "auto"

    // Local image path. Remote URLs are rejected: a greeter that fetches
    // over the network announces every boot to whoever hosts the image,
    // before anyone has authenticated.
    property string wallpaper: ""
    property real blur: 0.85
    property real dim: 0.72

    property string schemePath: "/etc/quickgreet/scheme.json"

    property string defaultSession: ""
    property string defaultUser: ""

    property bool showPowerButtons: true

    property string timeFormat: "HH:mm"
    property string dateFormat: "dddd, d MMMM"

    // Both are hard requirements that not every distribution packages
    // conveniently, so they are configurable rather than compiled in.
    // Which built-in QuickMaterial scheme to start from. Anything the
    // scheme file supplies is applied over the top, so this is what shows
    // on a machine with no scheme file at all.
    property string theme: "slate"

    property string fontFamily: "Rubik"
    property string iconFontFamily: "Material Symbols Rounded"

    // How long to wait for greetd before giving up on a request.
    property int timeoutSeconds: 60

    // Only these may be set from the file. Assigning to anything else —
    // a readonly property, or an internal flag like `ready` — throws out
    // of the assignment loop and silently drops every remaining key.
    readonly property var settable: ["locale", "wallpaper", "blur", "dim", "theme", "schemePath", "defaultSession", "defaultUser", "showPowerButtons", "timeFormat", "dateFormat", "fontFamily", "iconFontFamily", "timeoutSeconds"]

    // ─────────────────────── install layout ───────────────────────

    // Where the helper scripts live. Readonly and environment-only on
    // purpose: it selects the executable that receives the password, so it
    // is an install-layout detail, not something a config file may steer.
    readonly property string scriptsDir: Quickshell.env("QUICKGREET_SCRIPTS") || "/usr/lib/quickgreet"

    function script(name: string): string {
        return scriptsDir + "/" + name;
    }

    // ─────────────────────────── loading ───────────────────────────

    function apply(raw: string): void {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            console.warn("quickgreet: could not parse config:", e);
            return;
        }

        if (typeof data !== "object" || data === null) {
            console.warn("quickgreet: config is not an object");
            return;
        }

        for (const key in data) {
            if (!root.settable.includes(key)) {
                console.warn("quickgreet: ignoring unknown or protected setting:", key);
                continue;
            }

            // Each assignment is isolated: a single bad value must not
            // prevent the rest of the file from being applied.
            try {
                root[key] = data[key];
            } catch (e) {
                console.warn("quickgreet: bad value for", key + ":", e);
            }
        }

        if (root.wallpaper && /^[a-z][a-z0-9+.-]*:/i.test(root.wallpaper) && !root.wallpaper.startsWith("file:")) {
            console.warn("quickgreet: refusing remote wallpaper URL:", root.wallpaper);
            root.wallpaper = "";
        }

        if (!(root.blur >= 0 && root.blur <= 1))
            root.blur = 0.85;
        if (!(root.dim >= 0 && root.dim <= 1))
            root.dim = 0.72;
        if (!(root.timeoutSeconds > 0))
            root.timeoutSeconds = 60;
    }

    FileView {
        path: root.configPath

        // `ready` is set from a finally-style tail so a throw anywhere in
        // apply() cannot leave every consumer waiting forever.
        onLoaded: {
            try {
                root.apply(text());
            } finally {
                root.ready = true;
            }
        }

        onLoadFailed: {
            console.log("quickgreet: no config file, using defaults");
            root.ready = true;
        }
    }
}
