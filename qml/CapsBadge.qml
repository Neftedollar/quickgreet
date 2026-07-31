import QtQuick
import QtQuick.Layouts

// Caps Lock chip. The caller only shows it when the state is known: an
// indicator that is permanently negative because there is no LED to read
// tells the user nothing and hides the fact that it is inoperative.
Rectangle {
    implicitWidth: row.implicitWidth + Style.pad.chip
    implicitHeight: Style.dim.chip
    radius: height / 2
    color: Qt.alpha(Colours.m3error, 0.18)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "keyboard_capslock"
            font.family: Style.font.icons
            font.pixelSize: 17
            color: Colours.m3error
        }

        Text {
            text: "CAPS"
            color: Colours.m3error
            font.family: Style.font.sans
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
