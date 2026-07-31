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

    // Each character arrives as a different shape and resolves to a dot.
    // Off gives plain circles.
    property bool shapes: true

    spacing: 7

    // Pinned rather than derived from the children: the caret is taller
    // than a dot, so a self-sizing row grows when the field takes focus
    // and shifts every dot upwards.
    height: 18

    // A real model, not the count itself. An integer model never emits
    // insert or remove signals, so the row's transitions would silently
    // never run.
    ListModel {
        id: items
    }

    // Position in the whole sequence rather than in the model, so the
    // shape of a character does not change when an earlier one is deleted.
    property int typed: 0

    onCountChanged: {
        while (items.count < count) {
            items.append({
                seq: typed
            });
            typed++;
        }
        while (items.count > count && items.count > 0)
            items.remove(items.count - 1);
        if (count === 0)
            typed = 0;
    }

    AnimatedRow {
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        model: items
        itemWidth: 11
        gap: 7
        travel: 6
        jitter: 0.25

        delegate: MotionShape {
            required property var model

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            width: 11
            height: 11
            color: Colours.m3primary

            kind: root.shapes ? kindFor(model.seq) : MotionShape.Circle
            settlesToCircle: root.shapes
            // Resolves as the second beat of the arrival lands, so the
            // size change covers the swap.
            settleDelay: 260
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

        Blink {
            target: caret
            running: caret.visible
        }
    }
}
