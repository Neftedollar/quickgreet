import QtQuick

// Stand-in for masked text.
//
// TextInput cannot animate its own password bullets, so while the field is
// masked its text is drawn transparent and these are shown instead. Each
// dot is a freshly created delegate, which is what makes
// Component.onCompleted fire exactly once per keystroke.
Row {
    id: root

    property int count: 0
    property bool caretVisible: false

    spacing: 7

    // Pinned rather than derived from the children: the caret is taller
    // than a dot, so a self-sizing row grows when the field takes focus and
    // shifts every dot upwards.
    height: 18

    Repeater {
        model: root.count

        delegate: Rectangle {
            id: dot

            anchors.verticalCenter: parent.verticalCenter

            width: Style.dim.dot
            height: Style.dim.dot
            radius: width / 2
            color: Colours.m3primary

            scale: 0
            opacity: 0

            Component.onCompleted: pop.start()

            // Targets are named explicitly: `parent` does not resolve
            // inside an animation, which is not a visual item.
            ParallelAnimation {
                id: pop

                NumberAnimation {
                    target: dot
                    property: "scale"
                    from: 0
                    to: 1
                    duration: Style.dur.pop
                    easing.type: Easing.OutBack
                    easing.overshoot: 3.5
                }

                NumberAnimation {
                    target: dot
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 120
                }
            }
        }
    }

    // Drawn here because TextInput's own cursor is hidden along with its
    // text while masked.
    Rectangle {
        id: caret

        width: 2
        height: 17
        radius: 1
        color: Colours.m3primary
        anchors.verticalCenter: parent.verticalCenter
        visible: root.caretVisible

        SequentialAnimation on opacity {
            running: caret.visible
            loops: Animation.Infinite

            NumberAnimation {
                to: 0
                duration: Style.dur.blink
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                to: 1
                duration: Style.dur.blink
                easing.type: Easing.InOutQuad
            }
        }
    }
}
