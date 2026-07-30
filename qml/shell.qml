import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// quickgreet — a greetd greeter built on Quickshell.
//
// Run against the real greetd protocol by launching this config from a
// greetd session; run ./test.sh for a mock mode that exercises the UI
// without performing an actual login.
ShellRoot {
    id: shell

    readonly property bool mockMode: Quickshell.env("QUICKGREET_MOCK") === "1"

    FloatingWindow {
        id: win

        title: "quickgreet"
        color: Colours.m3background
        visible: true

        implicitWidth: shell.mockMode ? 1280 : 1920
        implicitHeight: shell.mockMode ? 800 : 1080

        // ─────────────────────── background ───────────────────────

        Image {
            id: bg

            anchors.fill: parent
            source: Config.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false

            // Bounded decode. Without a cap a large or malicious image is
            // expanded to its full pixel count in the process that holds
            // the greetd socket, before anyone has authenticated.
            sourceSize.width: 3840
            sourceSize.height: 2160

            onStatusChanged: if (status === Image.Error)
                console.warn("quickgreet: cannot load wallpaper:", source)
        }

        MultiEffect {
            anchors.fill: parent
            source: bg
            blurEnabled: true
            blur: Config.blur
            blurMax: 48
            autoPaddingEnabled: false
            visible: bg.status === Image.Ready
        }

        // Keeps text legible over arbitrary wallpapers, and is the whole
        // background when there is no usable image.
        Rectangle {
            anchors.fill: parent
            color: Colours.m3background
            opacity: bg.status === Image.Ready ? Config.dim : 1
        }

        // Dismisses open dropdowns on a click anywhere else.
        //
        // The z values matter: declared later in the file, this overlay
        // would otherwise sit above the card and swallow clicks meant for
        // the user list, which then looked alive but could never be used.
        MouseArea {
            anchors.fill: parent
            z: 1
            visible: sessionPicker.expanded || userList.open
            onClicked: {
                sessionPicker.expanded = false;
                userList.open = false;
            }
        }

        // ───────────────────────── clock ─────────────────────────

        ColumnLayout {
            id: clockBlock

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.11
            spacing: 2

            opacity: 0
            Component.onCompleted: introClock.start()

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.now, Config.timeFormat)
                color: Colours.m3onSurface
                font.family: Config.fontFamily
                font.pixelSize: 92
                font.weight: Font.Light
            }

            // The locale comes from the active language rather than the
            // system: the greeter may be configured to a different one.
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const d = clock.now.toLocaleDateString(Qt.locale(Strings.qtLocale), Config.dateFormat);
                    return d.charAt(0).toUpperCase() + d.slice(1);
                }
                color: Colours.m3onSurfaceVariant
                font.family: Config.fontFamily
                font.pixelSize: 17
            }
        }

        NumberAnimation {
            id: introClock

            target: clockBlock
            property: "opacity"
            from: 0
            to: 1
            duration: 500
            easing.type: Easing.OutCubic
        }

        // ────────────────────── login card ──────────────────────

        Rectangle {
            id: card

            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.height * 0.06
            z: 2

            implicitWidth: 380
            implicitHeight: cardCol.implicitHeight + 44
            radius: 28
            color: Colours.m3surfaceContainer
            border.width: 1
            border.color: Qt.alpha(Colours.m3outline, 0.25)

            opacity: 0
            scale: 0.96
            Component.onCompleted: intro.start()

            ParallelAnimation {
                id: intro

                NumberAnimation {
                    target: card
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 420
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: card
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: 420
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.7
                }
            }

            // Shake on a rejected password. horizontalCenterOffset is the
            // property to animate: the card is positioned with anchors, so
            // animating x while centerIn is active does nothing.
            SequentialAnimation {
                id: shake

                loops: 2

                NumberAnimation {
                    target: card
                    property: "anchors.horizontalCenterOffset"
                    to: -9
                    duration: 55
                }
                NumberAnimation {
                    target: card
                    property: "anchors.horizontalCenterOffset"
                    to: 9
                    duration: 55
                }
                NumberAnimation {
                    target: card
                    property: "anchors.horizontalCenterOffset"
                    to: 0
                    duration: 55
                }
            }

            ColumnLayout {
                id: cardCol

                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 16

                // ─────────── avatar ───────────

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 76
                    implicitHeight: 76

                    Rectangle {
                        id: avatarBg

                        anchors.fill: parent
                        radius: width / 2
                        color: Colours.m3primaryContainer

                        Text {
                            anchors.centerIn: parent
                            text: auth.displayName.charAt(0).toUpperCase()
                            color: Colours.m3primary
                            font.family: Config.fontFamily
                            font.pixelSize: 34
                            font.weight: Font.Medium
                            visible: avatarImg.status !== Image.Ready
                        }
                    }

                    Image {
                        id: avatarImg

                        anchors.fill: parent
                        source: auth.avatar
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false

                        // Decode no larger than it is drawn.
                        sourceSize.width: 152
                        sourceSize.height: 152
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImg
                        maskEnabled: true
                        maskSource: avatarBg
                        visible: avatarImg.status === Image.Ready
                    }
                }

                // ─────────── user name and chooser ───────────

                Item {
                    id: nameRow

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: nameLayout.implicitWidth + 16
                    implicitHeight: 30

                    readonly property bool selectable: auth.users.length > 1

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: nameArea.containsMouse && nameRow.selectable ? Colours.m3surfaceContainerHigh : "transparent"
                        border.width: nameRow.activeFocus ? 2 : 0
                        border.color: Colours.m3primary

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    RowLayout {
                        id: nameLayout

                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: auth.displayName
                            color: Colours.m3onSurface
                            font.family: Config.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "expand_more"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 18
                            color: Colours.m3onSurfaceVariant
                            visible: nameRow.selectable
                            rotation: userList.open ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    activeFocusOnTab: nameRow.selectable

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            userList.open = !userList.open;
                            event.accepted = true;
                        }
                    }

                    MouseArea {
                        id: nameArea

                        anchors.fill: parent
                        enabled: nameRow.selectable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            userList.open = !userList.open;
                            nameRow.forceActiveFocus();
                        }
                    }
                }

                // ─────────── user list ───────────

                Rectangle {
                    id: userList

                    property bool open: false

                    Layout.fillWidth: true
                    Layout.preferredHeight: open ? usersCol.implicitHeight + 12 : 0

                    visible: Layout.preferredHeight > 0
                    clip: true
                    radius: 14
                    color: Colours.m3surfaceContainerHigh

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        id: usersCol

                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 2

                        Repeater {
                            model: auth.users

                            delegate: Rectangle {
                                id: userItem

                                required property int index
                                required property var modelData

                                readonly property bool current: index === auth.userIndex

                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 10
                                color: userArea.containsMouse || userItem.activeFocus ? Colours.m3surfaceContainerHighest : "transparent"

                                activeFocusOnTab: userList.open

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        auth.chooseUser(userItem.index);
                                        event.accepted = true;
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: userItem.modelData.realname
                                    color: userItem.current ? Colours.m3primary : Colours.m3onSurface
                                    font.family: Config.fontFamily
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: userArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: auth.chooseUser(userItem.index)
                                }
                            }
                        }
                    }
                }

                // ─────────── prompt label ───────────

                // PAM decides what it is asking for. Anything beyond the
                // first password round is labelled with PAM's own wording.
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: auth.promptText
                    color: Colours.m3onSurfaceVariant
                    font.family: Config.fontFamily
                    font.pixelSize: 13
                    visible: text.length > 0
                }

                // ─────────── password field ───────────

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: height / 2
                    color: Colours.m3surfaceContainerHigh
                    border.width: 2
                    border.color: pwd.activeFocus ? Colours.m3primary : "transparent"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 10
                        spacing: 4

                        // The field keeps handling input, selection and IME;
                        // while masked its own text is drawn transparent and
                        // the dots below stand in for it, so each character
                        // can animate as it arrives. TextInput cannot animate
                        // its own password bullets.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 26

                            TextInput {
                                id: pwd

                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: auth.masked ? TextInput.Password : TextInput.Normal
                                passwordCharacter: "•"
                                color: auth.masked ? "transparent" : Colours.m3onSurface
                                font.family: Config.fontFamily
                                font.pixelSize: 16
                                focus: true
                                enabled: !greetd.busy
                                selectByMouse: !auth.masked
                                cursorVisible: !auth.masked && activeFocus
                                clip: true

                                onAccepted: auth.submit(text)

                                Keys.onPressed: event => {
                                    kb.handleKey(event);
                                    if (event.key === Qt.Key_Escape) {
                                        auth.abort();
                                        event.accepted = true;
                                    }
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Strings.tr("password")
                                color: Colours.m3onSurfaceVariant
                                font: pwd.font
                                visible: pwd.text.length === 0 && !pwd.activeFocus && auth.promptText.length === 0
                            }

                            Row {
                                id: dots

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                visible: auth.masked

                                // Pinned rather than derived from children:
                                // the caret is taller than a dot, so a
                                // self-sizing row grows when the field takes
                                // focus and shifts every dot upwards.
                                height: 18

                                Repeater {
                                    model: pwd.text.length

                                    delegate: Rectangle {
                                        id: dot

                                        anchors.verticalCenter: parent.verticalCenter

                                        width: 9
                                        height: 9
                                        radius: width / 2
                                        color: Colours.m3primary

                                        scale: 0
                                        opacity: 0

                                        Component.onCompleted: pop.start()

                                        // Targets are named: `parent` does not
                                        // resolve inside an animation, which
                                        // is not a visual item.
                                        ParallelAnimation {
                                            id: pop

                                            NumberAnimation {
                                                target: dot
                                                property: "scale"
                                                from: 0
                                                to: 1
                                                duration: 220
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

                                Rectangle {
                                    id: caret

                                    width: 2
                                    height: 17
                                    radius: 1
                                    color: Colours.m3primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pwd.activeFocus && !greetd.busy

                                    SequentialAnimation on opacity {
                                        running: caret.visible
                                        loops: Animation.Infinite

                                        NumberAnimation {
                                            to: 0
                                            duration: 480
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            to: 1
                                            duration: 480
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }

                        // Caps Lock warning, shown where typing happens.
                        // Hidden entirely when the state is unknown rather
                        // than showing a permanently negative indicator.
                        Text {
                            text: "keyboard_capslock_badge"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 20
                            color: Colours.m3error
                            visible: kb.capsLockKnown && kb.capsLock
                        }

                        Text {
                            text: auth.reveal ? "visibility_off" : "visibility"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 19
                            color: revealArea.containsMouse ? Colours.m3onSurface : Colours.m3outline
                            visible: pwd.text.length > 0 && auth.promptSecret

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            MouseArea {
                                id: revealArea

                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    auth.reveal = !auth.reveal;
                                    pwd.forceActiveFocus();
                                }
                            }
                        }

                        Item {
                            implicitWidth: 28
                            implicitHeight: 28

                            Text {
                                anchors.centerIn: parent
                                text: "arrow_forward"
                                font.family: Config.iconFontFamily
                                font.pixelSize: 22
                                color: pwd.text.length > 0 ? Colours.m3primary : Colours.m3outline
                                visible: !greetd.busy
                                // Clipped so a missing icon font cannot
                                // spill the ligature name across the field.
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: auth.submit(pwd.text)
                                }
                            }

                            Text {
                                id: spinner

                                anchors.centerIn: parent
                                text: "progress_activity"
                                font.family: Config.iconFontFamily
                                font.pixelSize: 22
                                color: Colours.m3primary
                                visible: greetd.busy
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight

                                RotationAnimation on rotation {
                                    running: spinner.visible
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }
                        }
                    }
                }

                // ─────────── status line ───────────

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family: Config.fontFamily
                    font.pixelSize: 13

                    text: {
                        if (auth.message.length > 0)
                            return auth.message;
                        if (kb.capsLockKnown && kb.capsLock)
                            return Strings.tr("capsLockOn");
                        if (!fonts.iconsPresent)
                            return Strings.tr("iconFontMissing");
                        return "";
                    }
                    color: auth.messageIsError || (kb.capsLockKnown && kb.capsLock) || !fonts.iconsPresent ? Colours.m3error : Colours.m3onSurfaceVariant
                    opacity: text.length > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        // ────────────────────── bottom bar ──────────────────────

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            implicitHeight: 40
            z: 2

            SessionPicker {
                id: sessionPicker

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                sessions: auth.sessions
                currentIndex: auth.sessionIndex
                onSelected: index => auth.sessionIndex = index

                // QUICKGREET_OPEN=1 starts with the list expanded, which is
                // how its layout gets captured during development.
                Component.onCompleted: if (Quickshell.env("QUICKGREET_OPEN") === "1")
                    expanded = true
            }

            RowLayout {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    implicitWidth: capsRow.implicitWidth + 20
                    implicitHeight: 34
                    radius: height / 2
                    color: Qt.alpha(Colours.m3error, 0.18)
                    visible: kb.capsLockKnown && kb.capsLock

                    RowLayout {
                        id: capsRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "keyboard_capslock"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 17
                            color: Colours.m3error
                        }

                        Text {
                            text: "CAPS"
                            color: Colours.m3error
                            font.family: Config.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                // Active layout; click or Space to switch. Shown dimmed and
                // inert when the compositor does not report the layout — a
                // guessed indicator on a login screen is worse than none.
                Rectangle {
                    id: layoutBadge

                    implicitWidth: layoutRow.implicitWidth + 20
                    implicitHeight: 34
                    radius: height / 2
                    opacity: kb.layoutKnown ? 0.92 : 0.45

                    color: (layoutArea.containsMouse || layoutBadge.activeFocus) && kb.canSwitch ? Colours.m3surfaceContainerHigh : Colours.m3surfaceContainer

                    activeFocusOnTab: kb.canSwitch

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            kb.cycleLayout();
                            event.accepted = true;
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    RowLayout {
                        id: layoutRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "keyboard"
                            font.family: Config.iconFontFamily
                            font.pixelSize: 17
                            color: Colours.m3onSurfaceVariant
                        }

                        Text {
                            text: kb.layoutShort
                            color: Colours.m3onSurface
                            font.family: Config.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: layoutArea

                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: kb.canSwitch
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            kb.cycleLayout();
                            // Focus goes back to the field, otherwise there
                            // is nowhere to type after a mouse click.
                            pwd.forceActiveFocus();
                        }
                    }
                }

                Rectangle {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    implicitWidth: 1
                    implicitHeight: 22
                    color: Qt.alpha(Colours.m3outline, 0.4)
                    visible: Config.showPowerButtons
                }

                PowerButtons {
                    visible: Config.showPowerButtons
                }
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            z: 3
            visible: shell.mockMode
            text: Strings.tr("mockNotice", Quickshell.env("MOCK_PASSWORD") || "test")
            color: Colours.m3outline
            font.family: Config.fontFamily
            font.pixelSize: 11
        }
    }

    // ─────────────────────────── state ───────────────────────────

    KeyboardState {
        id: kb
    }

    // Detects the icon font once. A missing one renders every icon as its
    // ligature name — "arrow_forward", "power_settings_new" — which gives
    // the user nothing to search for unless it is named explicitly.
    QtObject {
        id: fonts

        readonly property bool iconsPresent: Qt.fontFamilies().includes(Config.iconFontFamily)

        Component.onCompleted: if (!iconsPresent)
            console.warn("quickgreet: icon font", Config.iconFontFamily, "is not installed; icons will render as text")
    }

    QtObject {
        id: auth

        property var users: []
        property int userIndex: 0
        property var sessions: []
        property int sessionIndex: 0
        property string message: ""
        property bool messageIsError: false
        property bool reveal: false

        // Set while PAM is asking for something beyond the first password.
        property string promptText: ""
        property bool promptSecret: true

        readonly property bool masked: promptSecret && !reveal

        readonly property var currentUser: users.length > 0 ? users[userIndex] : null
        readonly property var currentSession: sessions.length > 0 ? sessions[sessionIndex] : null

        readonly property string username: currentUser ? currentUser.name : ""
        readonly property string displayName: currentUser ? currentUser.realname : "?"
        readonly property string avatar: currentUser && currentUser.avatar ? "file://" + currentUser.avatar : ""

        function chooseUser(index: int): void {
            userIndex = index;
            userList.open = false;
            clearField();
            pwd.forceActiveFocus();
        }

        function clearField(): void {
            pwd.text = "";
            reveal = false;
        }

        function note(text: string, isError: bool): void {
            message = text;
            messageIsError = isError;
        }

        // Enter either starts a login or answers whatever PAM last asked.
        function submit(text: string): void {
            if (greetd.busy)
                return;

            if (greetd.awaitingInput) {
                clearField();
                greetd.respond(text);
                return;
            }

            if (!currentSession) {
                note(Strings.tr("noSessions"), true);
                return;
            }
            if (!username) {
                note(Strings.tr("noUsers"), true);
                return;
            }

            note("", false);
            greetd.login(username, text, currentSession.exec);
            clearField();
        }

        // Escape backs out of an in-progress conversation.
        function abort(): void {
            if (userList.open || sessionPicker.expanded) {
                userList.open = false;
                sessionPicker.expanded = false;
                return;
            }
            if (greetd.awaitingInput || greetd.busy) {
                greetd.cancel();
                promptText = "";
                promptSecret = true;
                note("", false);
            }
            clearField();
        }
    }

    Timer {
        id: clock

        property date now: new Date()

        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: now = new Date()
    }

    Greetd {
        id: greetd

        mock: shell.mockMode
        timeoutSeconds: Config.timeoutSeconds

        // PAM wants something more: a second factor, a new password, an
        // answer to a question. Its own wording is shown as the label.
        onPrompt: (message, secret) => {
            auth.promptText = message;
            auth.promptSecret = secret;
            auth.reveal = false;
            pwd.text = "";
            pwd.forceActiveFocus();
        }

        // PAM said something. Shown verbatim: these messages are written
        // for people and are translated, so matching their text would
        // break on the first non-English system.
        onNotice: (message, isError) => auth.note(message, isError)

        onFailed: description => {
            auth.note(description, true);
            auth.promptText = "";
            auth.promptSecret = true;
            auth.clearField();
            pwd.forceActiveFocus();
            shake.restart();
        }

        onSucceeded: {
            auth.note(Strings.tr("signedIn"), false);
            auth.promptText = "";
            auth.clearField();
            // greetd starts the session only once the greeter exits, and
            // kills it five seconds later if it has not. Leaving on our own
            // lets the compositor shut down cleanly instead.
            quitDelay.start();
        }
    }

    Timer {
        id: quitDelay

        interval: 150
        repeat: false
        onTriggered: Qt.quit()
    }

    // Both enumerators wait for the configuration: they are launched from
    // a configured path, and starting early runs them from the default one.
    JsonSource {
        id: sessionSource

        script: "list-sessions.py"
        // Session names carry Name[xx] variants; hand the script the
        // language the greeter is actually displaying.
        args: ["--locale", Strings.qtLocale]
        onLoaded: data => {
            auth.sessions = data;
            const want = Quickshell.env("QUICKGREET_SESSION") || Config.defaultSession;
            if (want) {
                const idx = data.findIndex(s => s.id === want);
                if (idx >= 0)
                    auth.sessionIndex = idx;
            }
            if (data.length === 0)
                auth.note(Strings.tr("noSessions"), true);
        }
        onFailed: auth.note(Strings.tr("noSessions"), true)
    }

    JsonSource {
        id: userSource

        script: "list-users.py"
        onLoaded: data => {
            auth.users = data;
            const want = Quickshell.env("QUICKGREET_USER") || Config.defaultUser;
            if (want) {
                const idx = data.findIndex(u => u.name === want);
                if (idx >= 0)
                    auth.userIndex = idx;
            }
            if (data.length === 0)
                auth.note(Strings.tr("noUsers"), true);
        }
        onFailed: auth.note(Strings.tr("noUsers"), true)
    }
}
