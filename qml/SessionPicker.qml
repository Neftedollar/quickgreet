import QtQuick
import QtQuick.Layouts
import QuickMotion

// Session dropdown.
//
// Expands upwards: the button sits in the bottom bar, where there is no
// room below it. Click-outside dismissal is wired up by the caller,
// since the overlay has to cover the whole window.
Item {
    id: root

    required property var sessions
    property int currentIndex: 0
    property bool expanded: false

    readonly property var current: sessions.length > 0 ? sessions[currentIndex] : null
    readonly property string currentName: current ? current.name : Strings.tr("noSessions")

    signal selected(int index)

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // Reachable without a mouse: a greeter must work when the touchpad is
    // dead or no pointer is attached at all.
    activeFocusOnTab: sessions.length > 1

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && root.expanded) {
            root.expanded = false;
            event.accepted = true;
        } else if (root.expanded && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
            const step = event.key === Qt.Key_Down ? 1 : -1;
            const next = (root.currentIndex + step + root.sessions.length) % root.sessions.length;
            root.selected(next);
            event.accepted = true;
        }
    }

    function toggle(): void {
        if (sessions.length > 0)
            expanded = !expanded;
    }

    // currentIndex is deliberately left alone: it is bound to state owned
    // by the caller, and assigning to it here would break that binding.
    function choose(index: int): void {
        expanded = false;
        root.selected(index);
    }

    Rectangle {
        id: button

        anchors.fill: parent

        implicitWidth: buttonRow.implicitWidth + 28
        implicitHeight: 40
        radius: height / 2
        color: root.expanded || buttonArea.containsMouse || root.activeFocus ? Colours.m3surfaceContainerHigh : Colours.m3surfaceContainer
        border.width: root.activeFocus ? 2 : 0
        border.color: Colours.m3primary
        opacity: 0.92

        Behavior on color {
            ColourAnim {}
        }

        RowLayout {
            id: buttonRow

            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "desktop_windows"
                font.family: Config.iconFontFamily
                font.pixelSize: 18
                color: Colours.m3onSurfaceVariant
            }

            Text {
                text: root.currentName
                color: Colours.m3onSurface
                font.family: Config.fontFamily
                font.pixelSize: 14
            }

            Text {
                text: "expand_more"
                font.family: Config.iconFontFamily
                font.pixelSize: 16
                color: Colours.m3onSurfaceVariant
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {
                        role: Motion.Resize
                    }
                }
            }
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.toggle();
                root.forceActiveFocus();
            }
        }
    }

    Rectangle {
        id: popup

        anchors.bottom: button.top
        anchors.bottomMargin: 8
        // The button lives in the bottom-left corner, so the list grows
        // to the right; centring it would push a wide list off screen.
        anchors.left: button.left

        // Width follows the longest entry rather than the button: with a
        // short name selected the list would otherwise shrink and clip
        // every other entry.
        implicitWidth: Math.max(button.width, listCol.implicitWidth + 16)
        implicitHeight: listCol.implicitHeight + 16
        radius: 16
        color: Colours.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.m3outline, 0.3)

        visible: opacity > 0
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.94
        transformOrigin: Item.Bottom

        Behavior on opacity {
            Anim {
                role: Motion.Fade
            }
        }

        Behavior on scale {
            Anim {
                role: Motion.Reveal
            }
        }

        ColumnLayout {
            id: listCol

            anchors.centerIn: parent
            spacing: 2

            // Width is intentionally not set here. It is derived from the
            // content and read back through implicitWidth above; an
            // explicit width would close the loop and collapse the rows.

            Repeater {
                model: root.sessions

                delegate: Rectangle {
                    id: item

                    required property int index
                    required property var modelData

                    readonly property bool isCurrent: index === root.currentIndex

                    Layout.fillWidth: true

                    // Required: the RowLayout below is stretched with
                    // anchors and therefore reports no width upwards.
                    // Without this the row has zero implicitWidth, the
                    // list cannot size itself and text spills outside.
                    implicitWidth: itemRow.implicitWidth + 24
                    implicitHeight: 38
                    radius: 12
                    color: itemArea.containsMouse ? Colours.m3surfaceContainerHighest : "transparent"

                    Behavior on color {
                        ColourAnim {}
                    }

                    RowLayout {
                        id: itemRow

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: item.isCurrent ? "radio_button_checked" : "radio_button_unchecked"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 16
                            color: item.isCurrent ? Colours.m3primary : Colours.m3outline
                        }

                        // No elide and no fillWidth: the entry must report
                        // its natural width so the list can size to it.
                        Text {
                            text: item.modelData.name
                            color: item.isCurrent ? Colours.m3primary : Colours.m3onSurface
                            font.family: Config.fontFamily
                            font.pixelSize: 13
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: item.modelData.type === "x11" ? "X11" : "Wayland"
                            color: Colours.m3outline
                            font.family: Config.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: itemArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(item.index)
                    }
                }
            }
        }
    }
}
