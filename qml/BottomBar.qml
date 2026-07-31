import QtQuick
import QtQuick.Layouts

// Session picker on the left, keyboard state and power on the right.
Item {
    id: root

    required property var sessions
    property int sessionIndex: 0
    property alias sessionsExpanded: picker.expanded

    property bool capsLock: false
    property string layout: "--"
    property bool layoutKnown: false
    property bool layoutSwitchable: false

    signal sessionSelected(int index)
    signal cycleLayout

    implicitHeight: 40

    SessionPicker {
        id: picker

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        sessions: root.sessions
        currentIndex: root.sessionIndex
        onSelected: index => root.sessionSelected(index)
    }

    RowLayout {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        CapsBadge {
            visible: root.capsLock
        }

        LayoutBadge {
            layout: root.layout
            known: root.layoutKnown
            switchable: root.layoutSwitchable
            onCycle: root.cycleLayout()
        }

        Rectangle {
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            implicitWidth: 1
            implicitHeight: 22
            color: Qt.alpha(Colours.m3outline, 0.4)
            visible: Config.showPowerButtons
        }

        PowerButtons {
            visible: Config.showPowerButtons
        }
    }
}
