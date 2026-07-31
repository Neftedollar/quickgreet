import QtQuick
import QtQuick.Layouts
import QuickMaterial

// Caps Lock chip. The caller only shows it when the state is known: an
// indicator that is permanently negative because there is no LED to read
// tells the user nothing and hides the fact that it is inoperative.
Rectangle {
    implicitWidth: row.implicitWidth + 2 * Metrics.pad.chip
    implicitHeight: Metrics.chip
    radius: height / 2
    color: Qt.alpha(Colours.error, 0.18)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "keyboard_capslock"
            font.family: Type.iconFamily
            font.pixelSize: 17
            color: Colours.error
        }

        Text {
            text: "CAPS"
            color: Colours.error
            font.family: Type.family
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
