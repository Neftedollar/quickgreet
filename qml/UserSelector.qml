import QtQuick
import QtQuick.Layouts

// The account name, and a list to change it when there is more than one.
//
// The chevron and the whole interaction appear only when there is an actual
// choice: a single-user machine should not be offered a menu of one.
ColumnLayout {
    id: root

    required property var users
    property int currentIndex: 0
    property bool open: false

    readonly property bool selectable: users.length > 1
    readonly property var current: users.length > 0 ? users[currentIndex] : null
    readonly property string displayName: current ? current.realname : "?"

    signal selected(int index)

    spacing: 16

    // Fills the width and centres its own content, rather than relying on
    // Layout.alignment: that does not survive a ColumnLayout nested inside
    // another one, and the name silently ends up flush left.
    Item {
        id: nameRow

        Layout.fillWidth: true
        implicitHeight: 30

        activeFocusOnTab: root.selectable

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.open = !root.open;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape && root.open) {
                root.open = false;
                event.accepted = true;
            }
        }

        Rectangle {
            id: chip

            anchors.centerIn: parent
            implicitWidth: nameLayout.implicitWidth + 16
            implicitHeight: parent.height

            radius: height / 2
            color: nameArea.containsMouse && root.selectable ? Colours.m3surfaceContainerHigh : "transparent"
            border.width: nameRow.activeFocus ? 2 : 0
            border.color: Colours.m3primary

            Behavior on color {
                ColorAnimation {
                    duration: Style.dur.quick
                }
            }
        }

        RowLayout {
            id: nameLayout

            anchors.centerIn: parent
            spacing: 4

            Text {
                text: root.displayName
                color: Colours.m3onSurface
                font.family: Style.font.sans
                font.pixelSize: Style.size.title
                font.weight: Font.Medium
            }

            Text {
                text: "expand_more"
                font.family: Style.font.icons
                font.pixelSize: Style.size.icon
                color: Colours.m3onSurfaceVariant
                visible: root.selectable
                rotation: root.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Style.dur.quick
                    }
                }
            }
        }

        // Bound to the chip, not the full-width row: clicking empty space
        // beside the name should do nothing.
        MouseArea {
            id: nameArea

            anchors.fill: chip
            enabled: root.selectable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.open = !root.open;
                nameRow.forceActiveFocus();
            }
        }
    }

    Rectangle {
        id: list

        Layout.fillWidth: true
        Layout.preferredHeight: root.open ? column.implicitHeight + 12 : 0

        visible: Layout.preferredHeight > 0
        clip: true
        radius: Style.radius.panel
        color: Colours.m3surfaceContainerHigh

        Behavior on Layout.preferredHeight {
            NumberAnimation {
                duration: Style.dur.quick
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: column

            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 2

            Repeater {
                model: root.users

                delegate: Rectangle {
                    id: item

                    required property int index
                    required property var modelData

                    readonly property bool current: index === root.currentIndex

                    Layout.fillWidth: true
                    implicitHeight: Style.dim.rowSmall
                    radius: Style.radius.itemSmall
                    color: area.containsMouse || item.activeFocus ? Colours.m3surfaceContainerHighest : "transparent"

                    activeFocusOnTab: root.open

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.selected(item.index);
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Style.pad.item
                        anchors.right: parent.right
                        anchors.rightMargin: Style.pad.item
                        anchors.verticalCenter: parent.verticalCenter
                        text: item.modelData.realname
                        color: item.current ? Colours.m3primary : Colours.m3onSurface
                        font.family: Style.font.sans
                        font.pixelSize: Style.size.label
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(item.index)
                    }
                }
            }
        }
    }
}
