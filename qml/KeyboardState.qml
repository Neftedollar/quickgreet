import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard state for the greeter: active layout and Caps Lock.
//
// Caps Lock comes from sysfs. The LED reflects the real state regardless
// of compositor and the file is world readable, so it works even though
// the greeter runs unprivileged.
//
// The layout comes from Hyprland's event socket, which emits
// "activelayout>>device,Layout" on every switch. Under any other
// compositor the layout is simply not knowable from a client, and this
// reports that rather than guessing: on a login screen an indicator that
// confidently shows the wrong layout is worse than no indicator at all.
Item {
    id: root

    property bool capsLock: false
    property bool capsLockKnown: false

    property string layoutName: ""
    readonly property bool layoutKnown: layoutName.length > 0

    // hyprctl addresses a specific device, so switching needs its name.
    property string mainKeyboard: ""

    readonly property string his: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    readonly property bool underHyprland: his.length > 0

    // Switching is only possible under Hyprland: the layout belongs to the
    // compositor and no Wayland client can change it directly.
    readonly property bool canSwitch: underHyprland && mainKeyboard.length > 0

    readonly property string layoutShort: {
        if (!layoutKnown)
            return "--";
        const n = layoutName.toLowerCase();
        if (n.includes("russian"))
            return "RU";
        if (n.includes("ukrainian"))
            return "UA";
        if (n.includes("english"))
            return "EN";
        return layoutName.slice(0, 2).toUpperCase();
    }

    // ───────────────────────── Caps Lock ─────────────────────────

    // The LED node is named after an input device number that changes
    // between boots, so resolve the path once at startup. Laptops without
    // a Caps Lock LED have no node at all, which is why the indicator is
    // hidden rather than shown permanently negative.
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/leds/*capslock*/brightness 2>/dev/null | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) {
                    capsFile.path = path;
                    capsPoll.running = true;
                    root.capsLockKnown = true;
                } else {
                    console.log("quickgreet: no Caps Lock LED; indicator disabled");
                }
            }
        }
    }

    FileView {
        id: capsFile

        onLoaded: root.capsLock = text().trim() !== "0"
    }

    // Polling a file is cheap and spawns no processes; sysfs delivers no
    // reliable change notification.
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

    // ─────────────────── opt-in fallback tracking ───────────────────

    // Only used when the operator states the layout list explicitly, since
    // it is inference rather than fact: it assumes the list, its order and
    // that Alt+Shift is the toggle. Left unset, the badge reads "--".
    readonly property string declaredLayouts: Quickshell.env("QUICKGREET_LAYOUTS") ?? ""
    property var fallbackLayouts: declaredLayouts ? declaredLayouts.split(",") : []
    property int fallbackIndex: 0

    function handleKey(event: var): void {
        if (root.underHyprland || fallbackLayouts.length < 2)
            return;
        const isToggle = (event.key === Qt.Key_Shift && (event.modifiers & Qt.AltModifier)) || (event.key === Qt.Key_Alt && (event.modifiers & Qt.ShiftModifier));
        if (!isToggle)
            return;
        fallbackIndex = (fallbackIndex + 1) % fallbackLayouts.length;
        root.layoutName = fallbackLayouts[fallbackIndex];
    }

    Component.onCompleted: {
        if (!underHyprland && fallbackLayouts.length > 0)
            layoutName = fallbackLayouts[0];
    }
}
