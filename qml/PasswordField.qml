import QtQuick
import QtQuick.Layouts

// The answer field.
//
// It hands the typed text out as a signal argument rather than exposing it
// as a property. Nothing outside therefore holds a reference to the widget
// that contains the password, which is what lets the state object stay free
// of any view dependency.
Rectangle {
    id: root

    property bool busy: false
    property bool secret: true   // PAM decides: a code is not masked
    property bool reveal: false
    property bool capsLock: false

    readonly property bool masked: secret && !reveal
    readonly property alias text: input.text

    signal accepted(string answer)
    signal escaped
    signal keyPressed(var event)

    function clear(): void {
        input.text = "";
        reveal = false;
    }

    function grabFocus(): void {
        input.forceActiveFocus();
    }

    implicitHeight: Style.dim.field
    radius: height / 2
    color: Colours.m3surfaceContainerHigh
    border.width: 2
    border.color: input.activeFocus ? Colours.m3primary : "transparent"

    Behavior on border.color {
        ColorAnimation {
            duration: Style.dur.quick
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.pad.field
        anchors.rightMargin: 10
        spacing: 4

        Item {
            Layout.fillWidth: true
            implicitHeight: 26

            TextInput {
                id: input

                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.masked ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"
                color: root.masked ? "transparent" : Colours.m3onSurface
                font.family: Style.font.sans
                font.pixelSize: Style.size.body
                focus: true
                enabled: !root.busy
                selectByMouse: !root.masked
                cursorVisible: !root.masked && activeFocus
                clip: true

                onAccepted: root.accepted(text)

                Keys.onPressed: event => {
                    root.keyPressed(event);
                    if (event.key === Qt.Key_Escape) {
                        root.escaped();
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Strings.tr("password")
                color: Colours.m3onSurfaceVariant
                font: input.font
                visible: input.text.length === 0 && !input.activeFocus && root.secret
            }

            PasswordDots {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.masked
                count: input.text.length
                caretVisible: input.activeFocus && !root.busy
            }
        }

        // Caps Lock warning where the typing happens. Shown only when the
        // state is actually known.
        Text {
            text: "keyboard_capslock_badge"
            font.family: Style.font.icons
            font.pixelSize: 20
            color: Colours.m3error
            visible: root.capsLock
        }

        Text {
            text: root.reveal ? "visibility_off" : "visibility"
            font.family: Style.font.icons
            font.pixelSize: 19
            color: revealArea.containsMouse ? Colours.m3onSurface : Colours.m3outline
            visible: input.text.length > 0 && root.secret

            Behavior on color {
                ColorAnimation {
                    duration: Style.dur.quick
                }
            }

            MouseArea {
                id: revealArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.reveal = !root.reveal;
                    root.grabFocus();
                }
            }
        }

        Item {
            implicitWidth: 28
            implicitHeight: 28

            // Both icons are width-limited so a missing icon font spills
            // its ligature name no further than the button it belongs to.
            Text {
                anchors.centerIn: parent
                text: "arrow_forward"
                font.family: Style.font.icons
                font.pixelSize: Style.size.iconLarge
                color: input.text.length > 0 ? Colours.m3primary : Colours.m3outline
                visible: !root.busy
                width: 28
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.accepted(input.text)
                }
            }

            Text {
                id: spinner

                anchors.centerIn: parent
                text: "progress_activity"
                font.family: Style.font.icons
                font.pixelSize: Style.size.iconLarge
                color: Colours.m3primary
                visible: root.busy
                width: 28
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight

                RotationAnimation on rotation {
                    running: spinner.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Style.dur.spin
                }
            }
        }
    }
}
