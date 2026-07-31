import QtQuick
import QuickMotion

// Stand-in for masked text.
//
// TextInput cannot animate its own password bullets, so while the field is
// masked its text is drawn transparent and these are shown instead.
//
// Built on AnimatedRow rather than a Repeater for one reason: a Repeater
// destroys its delegate the instant the model shrinks, so a deleted
// character has nothing left to animate and simply blinks out. The row
// keeps it alive for the length of its exit.
Row {
    id: root

    property int count: 0
    property bool caretVisible: false

    spacing: 7

    // Pinned rather than derived from the children: the caret is taller
    // than a dot, so a self-sizing row grows when the field takes focus
    // and shifts every dot upwards.
    height: 18

    // A real model, not the count itself. An integer model never emits
    // insert or remove signals, so the row's transitions would silently
    // never run — the dots would appear and vanish instantly, exactly the
    // behaviour this component exists to avoid.
    ListModel {
        id: items
    }

    onCountChanged: {
        while (items.count < count)
            items.append({});
        while (items.count > count && items.count > 0)
            items.remove(items.count - 1);
    }

    AnimatedRow {
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        model: items
        itemWidth: 9
        gap: 7

        // Arriving dots rise into place from slightly ahead of the caret,
        // which reads as the character being pushed in rather than
        // appearing out of nowhere.
        travel: 6
        fromScale: 0

        delegate: Rectangle {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            width: 9
            height: 9
            radius: width / 2
            color: Colours.m3primary
        }
    }

    // Drawn here because TextInput's own cursor is hidden along with its
    // text while masked.
    Rectangle {
        id: caret

        anchors.verticalCenter: parent.verticalCenter

        width: 2
        height: 17
        radius: 1
        color: Colours.m3primary
        visible: root.caretVisible

        SequentialAnimation on opacity {
            running: caret.visible
            loops: Animation.Infinite

            NumberAnimation {
                to: 0
                duration: Motion.dur.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curve.effects
            }
            NumberAnimation {
                to: 1
                duration: Motion.dur.slowEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.curve.effects
            }
        }
    }
}
