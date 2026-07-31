import QtQuick
import QtQuick.Effects

// Round avatar, falling back to the account's initial.
//
// Most accounts have no avatar file: the only sources are system-wide, as
// reading one out of a home directory would hand an unprivileged user an
// image decoder that runs before anyone authenticates.
Item {
    id: root

    property string source: ""
    property string initial: "?"

    implicitWidth: Style.dim.avatar
    implicitHeight: Style.dim.avatar

    Rectangle {
        id: circle

        anchors.fill: parent
        radius: width / 2
        color: Colours.m3primaryContainer

        Text {
            anchors.centerIn: parent
            text: root.initial.charAt(0).toUpperCase()
            color: Colours.m3primary
            font.family: Style.font.sans
            font.pixelSize: Style.size.initial
            font.weight: Font.Medium
            visible: image.status !== Image.Ready
        }
    }

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false

        // Decode no larger than it is drawn.
        sourceSize.width: Style.dim.avatar * 2
        sourceSize.height: Style.dim.avatar * 2
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: circle
        visible: image.status === Image.Ready
    }
}
