import QtQuick
import QtQuick.Layouts

// Active keyboard layout; click or Space to switch.
//
// Dimmed and inert when the compositor does not report a layout. It shows
// "--" rather than a guess: on a login screen an indicator that confidently
// names the wrong layout is worse than no indicator at all.
Rectangle {
    id: root

    property string layout: "--"
    property bool known: false
    property bool switchable: false

    signal cycle

    implicitWidth: row.implicitWidth + Style.pad.chip
    implicitHeight: Style.dim.chip
    radius: height / 2
    opacity: known ? 0.92 : 0.45

    color: (area.containsMouse || root.activeFocus) && root.switchable ? Colours.m3surfaceContainerHigh : Colours.m3surfaceContainer

    activeFocusOnTab: switchable

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.cycle();
            event.accepted = true;
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.dur.quick
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "keyboard"
            font.family: Style.font.icons
            font.pixelSize: 17
            color: Colours.m3onSurfaceVariant
        }

        Text {
            text: root.layout
            color: Colours.m3onSurface
            font.family: Style.font.sans
            font.pixelSize: Style.size.label
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.switchable
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cycle()
    }
}
