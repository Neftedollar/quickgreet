import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard state for the greeter: active layout and Caps Lock.
//
// Caps Lock comes from sysfs. The LED reflects the real state regardless
// of which compositor is running, and the file is world readable, so it
// works even though the greeter runs as an unprivileged user.
//
// The layout comes from Hyprland's event socket, which emits
// "activelayout>>device,Layout" on every switch. Running under any other
// compositor, we fall back to counting the Alt+Shift combination
// ourselves — a client cannot query the layout on its own.
Item {
    id: root

    property bool capsLock: false
    property string layoutName: ""

    // hyprctl addresses a specific device, so switching needs its name.
    property string mainKeyboard: ""

    readonly property string his: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    readonly property bool underHyprland: his.length > 0

    // Switching is only possible under Hyprland: the layout belongs to
    // the compositor and no Wayland client can change it directly.
    readonly property bool canSwitch: underHyprland && mainKeyboard.length > 0

    // Short badge text: "Russian" -> RU, "English (US)" -> EN
    readonly property string layoutShort: {
        const n = layoutName.toLowerCase();
        if (n.includes("russian"))
            return "RU";
        if (n.includes("english"))
            return "EN";
        if (n.length === 0)
            return "--";
        return layoutName.slice(0, 2).toUpperCase();
    }

    // ───────────────────────── Caps Lock ─────────────────────────

    // The LED node is named after an input device number that changes
    // between boots, so resolve the path once at startup.
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*capslock*/brightness 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) {
                    capsFile.path = path;
                    capsPoll.running = true;
                } else {
                    console.warn("quickgreet: no Caps Lock LED found");
                }
            }
        }
    }

    FileView {
        id: capsFile

        onLoaded: root.capsLock = text().trim() !== "0"
    }

    // Polling a file is cheap and spawns no processes; sysfs does not
    // deliver reliable change notifications.
    Timer {
        id: capsPoll

        interval: 200
        repeat: true
        running: false
        onTriggered: capsFile.reload()
    }

    // ────────────────────────── layout ──────────────────────────

    // One-shot query for the initial state; updates arrive as events.
    Process {
        running: root.underHyprland
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main?.active_keymap)
                        root.layoutName = main.active_keymap;
                    if (main?.name)
                        root.mainKeyboard = main.name;
                } catch (e) {
                    console.warn("quickgreet: could not parse hyprctl devices:", e);
                }
            }
        }
    }

    Socket {
        connected: root.underHyprland
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr/${root.his}/.socket2.sock`

        parser: SplitParser {
            onRead: line => {
                if (!line.startsWith("activelayout>>"))
                    return;
                const payload = line.slice("activelayout>>".length);
                const comma = payload.indexOf(",");
                if (comma >= 0)
                    root.layoutName = payload.slice(comma + 1);
            }
        }
    }

    // No result is read back: the new layout arrives through the event
    // socket, exactly as it does for a keyboard-initiated switch.
    Process {
        id: switcher

        command: ["hyprctl", "switchxkblayout", root.mainKeyboard, "next"]
    }

    function cycleLayout(): void {
        if (!canSwitch)
            return;
        switcher.running = false;
        switcher.running = true;
    }

    // ─────────────────── fallback without Hyprland ───────────────────

    // Works because the greeter always holds focus and the toggle
    // combination is known in advance.
    property var fallbackLayouts: (Quickshell.env("QUICKGREET_LAYOUTS") ?? "English (US),Russian").split(",")
    property int fallbackIndex: 0

    function handleKey(event: var): void {
        if (root.underHyprland)
            return;
        const isToggle = (event.key === Qt.Key_Shift && (event.modifiers & Qt.AltModifier)) || (event.key === Qt.Key_Alt && (event.modifiers & Qt.ShiftModifier));
        if (!isToggle)
            return;
        fallbackIndex = (fallbackIndex + 1) % fallbackLayouts.length;
        root.layoutName = fallbackLayouts[fallbackIndex];
    }

    Component.onCompleted: {
        if (!underHyprland)
            layoutName = fallbackLayouts[0];
    }
}
