import QtQuick
import QtQuick.Effects

// Blurred, dimmed wallpaper, or a flat colour when there is no usable
// image. Self-contained: it reads its own settings and reports nothing.
Item {
    id: root

    Image {
        id: image

        anchors.fill: parent
        source: Config.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false

        // Bounded decode. Without a cap a large or malicious image is
        // expanded to its full pixel count in the process that holds the
        // greetd socket, before anyone has authenticated.
        sourceSize.width: 3840
        sourceSize.height: 2160

        onStatusChanged: if (status === Image.Error)
            console.warn("quickgreet: cannot load wallpaper:", source)
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        blurEnabled: true
        blur: Config.blur
        blurMax: 48
        autoPaddingEnabled: false
        visible: image.status === Image.Ready
    }

    // Keeps text legible over arbitrary wallpapers, and is the whole
    // background when there is no image to dim.
    Rectangle {
        anchors.fill: parent
        color: Colours.m3background
        opacity: image.status === Image.Ready ? Config.dim : 1
    }
}
