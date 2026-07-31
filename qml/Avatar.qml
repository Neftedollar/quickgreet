import QtQuick
import QtQuick.Effects
import QuickMaterial

// Round avatar, falling back to the account's initial.
//
// Most accounts have no avatar file: the only sources are system-wide, as
// reading one out of a home directory would hand an unprivileged user an
// image decoder that runs before anyone authenticates.
Item {
    id: root

    property string source: ""
    property string initial: "?"

    implicitWidth: Metrics.avatar.large
    implicitHeight: Metrics.avatar.large

    Rectangle {
        id: circle

        anchors.fill: parent
        radius: width / 2
        color: Colours.primaryContainer

        Text {
            anchors.centerIn: parent
            text: root.initial.charAt(0).toUpperCase()
            color: Colours.primary
            font: Type.headlineMedium
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
        sourceSize.width: Metrics.avatar.large * 2
        sourceSize.height: Metrics.avatar.large * 2
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: circle
        visible: image.status === Image.Ready
    }
}
