import QtQuick
import QtQuick.Layouts
import QuickMotion
import Quickshell.Io
import QuickMaterial

// Power controls for the login screen.
//
// Actions fire immediately without confirmation, which is how nearly all
// greeters behave: nobody is logged in, so there is no work to lose.
//
// The user the greeter runs as needs polkit permission for these calls.
// greetd's default user usually has it; see contrib/polkit/ for a rule
// to install when it does not.
RowLayout {
    id: root

    spacing: 4

    component PowerButton: Rectangle {
        id: btn

        required property string icon
        required property string tip
        required property var action

        // Reachable from the keyboard. These were outside the tab chain
        // entirely, so shutting down or rebooting from a login screen
        // needed a pointer.
        activeFocusOnTab: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                btn.action();
                event.accepted = true;
            }
        }

        // The icon-button size from the specification, with the 48 target
        // it also specifies — the button was 36 with no expanded hit area,
        // twelve pixels under the accessibility floor.
        implicitWidth: Metrics.button
        implicitHeight: Metrics.button
        radius: Corner.full(height)
        color: "transparent"

        // A state layer rather than a colour swap. This control has no
        // container of its own, so swapping one in on hover flashed a
        // filled rectangle out of nothing; a translucent film over
        // transparency is simply a faint tint, which is what was meant.
        StateLayer {
            anchors.fill: parent
            rounding: parent.radius
            colour: Colours.on.surface
            hovered: area.containsMouse
            focused: btn.activeFocus
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: Type.iconFamily
            font.pixelSize: Metrics.icon.medium
            color: area.containsMouse ? Colours.on.surface : Colours.on.surfaceVariant

            Behavior on color {
                ColourAnim {}
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.action()
        }

        Rectangle {
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: tipText.implicitWidth + 16
            implicitHeight: 26
            radius: 8
            color: Colours.surfaceContainerHighest

            visible: opacity > 0
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                Anim {
                    role: Motion.Fade
                }
            }

            Text {
                id: tipText

                anchors.centerIn: parent
                text: btn.tip
                color: Colours.on.surface
                font.family: Config.fontFamily
                font.pixelSize: 12
            }
        }
    }

    // loginctl rather than systemctl: it is provided by both systemd and
    // elogind, so this works on Artix, Void, Devuan, Alpine and OpenRC
    // systems too, and it maps onto the same org.freedesktop.login1
    // actions the shipped polkit rule names.
    Process {
        id: runner

        property var pending: []

        command: pending
        running: false

        // Silence here means polkit refused. Without this the button is
        // indistinguishable from a broken one.
        onExited: code => {
            if (code !== 0) {
                console.warn("quickgreet: power action failed with", code);
                root.failed(code);
            }
        }
    }

    signal failed(int code)

    function run(argv: var): void {
        runner.running = false;
        runner.pending = argv;
        runner.running = true;
    }

    PowerButton {
        icon: "bedtime"
        tip: Strings.tr("suspend")
        action: () => root.run(["loginctl", "suspend"])
    }

    PowerButton {
        icon: "restart_alt"
        tip: Strings.tr("reboot")
        action: () => root.run(["loginctl", "reboot"])
    }

    PowerButton {
        icon: "power_settings_new"
        tip: Strings.tr("shutdown")
        action: () => root.run(["loginctl", "poweroff"])
    }
}
