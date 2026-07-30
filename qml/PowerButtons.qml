import QtQuick
import QtQuick.Layouts
import Quickshell.Io

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

        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        color: area.containsMouse ? Colours.m3surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
            color: area.containsMouse ? Colours.m3onSurface : Colours.m3onSurfaceVariant

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
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
            color: Colours.m3surfaceContainerHighest

            visible: opacity > 0
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Text {
                id: tipText

                anchors.centerIn: parent
                text: btn.tip
                color: Colours.m3onSurface
                font.family: "Rubik"
                font.pixelSize: 12
            }
        }
    }

    Process {
        id: runner

        property var pending: []

        command: pending
        running: false
    }

    function run(argv: var): void {
        runner.running = false;
        runner.pending = argv;
        runner.running = true;
    }

    PowerButton {
        icon: "bedtime"
        tip: Strings.tr("suspend")
        action: () => root.run(["systemctl", "suspend"])
    }

    PowerButton {
        icon: "restart_alt"
        tip: Strings.tr("reboot")
        action: () => root.run(["systemctl", "reboot"])
    }

    PowerButton {
        icon: "power_settings_new"
        tip: Strings.tr("shutdown")
        action: () => root.run(["systemctl", "poweroff"])
    }
}
