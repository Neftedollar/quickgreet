import QtQuick
import QtQuick.Layouts
import QuickMotion
import QuickMaterial

// The card: who is logging in, what PAM is asking, and the answer field.
//
// It never exposes the typed text as a property. `submitted` carries it out
// as an argument and the field is cleared straight after, so no reference to
// the widget holding a password escapes this component.
Rectangle {
    id: root

    required property var users
    property int userIndex: 0

    // What PAM last asked for. Empty means the ordinary password round.
    property string promptText: ""
    property bool promptSecret: true

    property bool busy: false
    property bool capsLock: false
    property string message: ""
    property bool messageIsError: false

    readonly property bool userListOpen: users_.open

    signal submitted(string answer)
    signal userSelected(int index)
    signal escaped

    function reject(): void {
        field.clear();
        field.grabFocus();
        shake.restart();
    }

    function clearField(): void {
        field.clear();
    }

    function grabFocus(): void {
        field.grabFocus();
    }

    function closeLists(): void {
        users_.open = false;
    }

    function forwardKey(event: var): void {}

    implicitWidth: Metrics.dialogWidth
    implicitHeight: column.implicitHeight + 44
    radius: Shape.extraLarge
    color: Colours.surfaceContainer
    border.width: 1
    border.color: Qt.alpha(Colours.outline, 0.25)

    opacity: 0
    scale: 0.96
    Component.onCompleted: intro.start()

    ParallelAnimation {
        id: intro

        Anim {
            target: root
            property: "opacity"
            from: 0
            to: 1
            role: Motion.Fade
        }

        // Reveal already overshoots: the curve carries the settle that
        // OutBack's overshoot parameter used to approximate by hand.
        Anim {
            target: root
            property: "scale"
            from: 0.96
            to: 1
            role: Motion.Reveal
        }
    }

    // Anchored, so the shake moves the offset rather than x: animating x
    // while centreIn is active does nothing at all, silently.
    Shake {
        id: shake

        target: root
    }

    ColumnLayout {
        id: column

        anchors.centerIn: parent
        width: parent.width - 2 * Metrics.pad.card
        spacing: 16

        Avatar {
            Layout.alignment: Qt.AlignHCenter
            source: users_.current && users_.current.avatar ? "file://" + users_.current.avatar : ""
            initial: users_.displayName
        }

        UserSelector {
            id: users_

            Layout.fillWidth: true
            users: root.users
            currentIndex: root.userIndex
            onSelected: index => root.userSelected(index)
        }

        // PAM's own wording for anything beyond the first password round.
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.promptText
            color: Colours.on.surfaceVariant
            font: Type.labelLarge
            visible: text.length > 0
        }

        PasswordField {
            id: field

            Layout.fillWidth: true
            busy: root.busy
            secret: root.promptSecret
            capsLock: root.capsLock

            onAccepted: answer => root.submitted(answer)
            onEscaped: root.escaped()
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font: Type.labelLarge

            text: root.message
            color: root.messageIsError ? Colours.error : Colours.on.surfaceVariant
            opacity: text.length > 0 ? 1 : 0

            Behavior on opacity {
                Anim {
            role: Motion.Fade
        }
            }
        }
    }
}
