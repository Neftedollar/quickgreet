import QtQuick
import QtQuick.Layouts
import QuickMotion
import QuickMaterial

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

    implicitWidth: row.implicitWidth + 2 * Metrics.pad.chip
    implicitHeight: Metrics.chip
    radius: height / 2
    opacity: known ? 0.92 : 0.45

    color: (area.containsMouse || root.activeFocus) && root.switchable ? Colours.surfaceContainerHigh : Colours.surfaceContainer

    activeFocusOnTab: switchable

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.cycle();
            event.accepted = true;
        }
    }

    Behavior on color {
        ColourAnim {}
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "keyboard"
            font.family: Type.iconFamily
            font.pixelSize: 17
            color: Colours.on.surfaceVariant
        }

        Text {
            text: root.layout
            color: Colours.on.surface
            font: Type.labelLarge
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
