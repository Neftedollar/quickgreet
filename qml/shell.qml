import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// quickgreet — a greetd greeter built on Quickshell.
//
// Run against the real greetd protocol by launching this config from a
// greetd session; run ./test.sh for a mock mode that exercises the whole
// UI and protocol flow without performing an actual login.
ShellRoot {
    id: shell

    readonly property bool mockMode: Quickshell.env("QUICKGREET_MOCK") === "1"

    FloatingWindow {
        id: win

        title: "quickgreet"
        color: Colours.m3background
        visible: true

        // Smaller in mock mode so it does not blanket the desktop.
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

        // Keeps text legible over arbitrary wallpapers.
        Rectangle {
            anchors.fill: parent
            color: Colours.m3background
            opacity: bg.status === Image.Ready ? Config.dim : 1
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
                font.family: "Rubik"
                font.pixelSize: 92
                font.weight: Font.Light
            }

            // The locale is set explicitly: the system locale need not
            // match the language the greeter is configured to display.
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const loc = Qt.locale(Config.effectiveLocale === "ru" ? "ru_RU" : "en_GB");
                    const d = clock.now.toLocaleDateString(loc, Config.dateFormat);
                    return d.charAt(0).toUpperCase() + d.slice(1);
                }
                color: Colours.m3onSurfaceVariant
                font.family: "Rubik"
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
            // property to animate: the card is positioned with anchors,
            // so animating x while centreIn is active does nothing.
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
                            font.family: "Rubik"
                            font.pixelSize: 34
                            font.weight: Font.Medium
                            visible: avatarImg.status !== Image.Ready
                        }
                    }

                    // Most accounts have no avatar file; the initial on a
                    // tinted circle is the fallback.
                    Image {
                        id: avatarImg

                        anchors.fill: parent
                        source: auth.avatar
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImg
                        maskEnabled: true
                        maskSource: avatarBg
                        visible: avatarImg.status === Image.Ready
                    }
                }

                // ─────────── user name ───────────

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: nameRow.implicitWidth
                    implicitHeight: 28

                    RowLayout {
                        id: nameRow

                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: auth.displayName
                            color: Colours.m3onSurface
                            font.family: "Rubik"
                            font.pixelSize: 19
                            font.weight: Font.Medium
                        }

                        // Only offer a chooser when there is a choice.
                        Text {
                            text: "expand_more"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
                            color: Colours.m3onSurfaceVariant
                            visible: auth.users.length > 1
                            rotation: userList.visible ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: auth.users.length > 1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: userList.visible = !userList.visible
                    }
                }

                // ─────────── user list ───────────

                Rectangle {
                    id: userList

                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? usersCol.implicitHeight + 12 : 0

                    visible: false
                    radius: 14
                    color: Colours.m3surfaceContainerHigh

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

                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 10
                                color: userArea.containsMouse ? Colours.m3surfaceContainerHighest : "transparent"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: userItem.modelData.realname
                                    color: userItem.index === auth.userIndex ? Colours.m3primary : Colours.m3onSurface
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: userArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        auth.userIndex = userItem.index;
                                        userList.visible = false;
                                        pwd.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────── password field ───────────

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 24
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

                        // The field keeps handling input, selection and
                        // IME; while the password is hidden its own text
                        // is drawn transparent and the dots below stand in
                        // for it, so each character can animate as it
                        // arrives. TextInput cannot animate its own
                        // password bullets.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 26

                            TextInput {
                                id: pwd

                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: auth.revealPassword ? TextInput.Normal : TextInput.Password
                                passwordCharacter: "•"
                                color: auth.revealPassword ? Colours.m3onSurface : "transparent"
                                font.family: "Rubik"
                                font.pixelSize: 16
                                focus: true
                                enabled: !greetd.busy
                                selectByMouse: auth.revealPassword
                                cursorVisible: auth.revealPassword && activeFocus
                                clip: true

                                onAccepted: auth.submit()

                                // Feeds the layout fallback used when the
                                // greeter is not running under Hyprland.
                                Keys.onPressed: event => kb.handleKey(event)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Strings.tr("password")
                                color: Colours.m3onSurfaceVariant
                                font: pwd.font
                                visible: pwd.text.length === 0 && !pwd.activeFocus
                            }

                            Row {
                                id: dots

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 7
                                visible: !auth.revealPassword

                                // Height is pinned rather than derived from
                                // the children: the caret is taller than a
                                // dot, so letting the row size itself makes
                                // it grow when the field takes focus, which
                                // shifts every dot upwards.
                                height: 18

                                Repeater {
                                    model: pwd.text.length

                                    delegate: Rectangle {
                                        id: dot

                                        anchors.verticalCenter: parent.verticalCenter

                                        width: 9
                                        height: 9
                                        radius: 4.5
                                        color: Colours.m3primary

                                        // Each dot is a freshly created
                                        // item, so animating on completion
                                        // fires exactly once per keystroke.
                                        scale: 0
                                        opacity: 0

                                        Component.onCompleted: pop.start()

                                        // Targets are named explicitly:
                                        // `parent` does not resolve inside
                                        // an animation, which is not a
                                        // visual item and has no parent.
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

                                // Caret trailing the dots: TextInput's own
                                // cursor is hidden along with its text.
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
                        Text {
                            text: "keyboard_capslock_badge"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: Colours.m3error
                            visible: kb.capsLock
                        }

                        Text {
                            text: auth.revealPassword ? "visibility_off" : "visibility"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 19
                            color: revealArea.containsMouse ? Colours.m3onSurface : Colours.m3outline
                            visible: pwd.text.length > 0

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
                                    auth.revealPassword = !auth.revealPassword;
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
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 22
                                color: pwd.text.length > 0 ? Colours.m3primary : Colours.m3outline
                                visible: !greetd.busy

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: auth.submit()
                                }
                            }

                            Text {
                                id: spinner

                                anchors.centerIn: parent
                                text: "progress_activity"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 22
                                color: Colours.m3primary
                                visible: greetd.busy

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
                    font.family: "Rubik"
                    font.pixelSize: 13

                    text: auth.message.length > 0 ? auth.message : kb.capsLock ? Strings.tr("capsLockOn") : ""
                    color: auth.messageIsError || kb.capsLock ? Colours.m3error : Colours.m3onSurfaceVariant
                    opacity: text.length > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        // Dismisses open dropdowns on a click anywhere else.
        MouseArea {
            anchors.fill: parent
            visible: sessionPicker.expanded || userList.visible
            onClicked: {
                sessionPicker.expanded = false;
                userList.visible = false;
            }
        }

        // ────────────────────── bottom bar ──────────────────────

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            implicitHeight: 40

            SessionPicker {
                id: sessionPicker

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                sessions: auth.sessions
                currentIndex: auth.sessionIndex
                onSelected: index => auth.sessionIndex = index

                // QUICKGREET_OPEN=1 starts with the list expanded, which
                // is how its layout gets captured during development.
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
                    radius: 17
                    color: Qt.alpha(Colours.m3error, 0.18)
                    visible: kb.capsLock

                    RowLayout {
                        id: capsRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "keyboard_capslock"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 17
                            color: Colours.m3error
                        }

                        Text {
                            text: "CAPS"
                            color: Colours.m3error
                            font.family: "Rubik"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                // Active layout; click to switch.
                Rectangle {
                    implicitWidth: layoutRow.implicitWidth + 20
                    implicitHeight: 34
                    radius: 17
                    opacity: 0.92

                    color: layoutArea.containsMouse && kb.canSwitch ? Colours.m3surfaceContainerHigh : Colours.m3surfaceContainer

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
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 17
                            color: Colours.m3onSurfaceVariant
                        }

                        Text {
                            text: kb.layoutShort
                            color: Colours.m3onSurface
                            font.family: "Rubik"
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
                            // Focus must go back to the field, otherwise
                            // there is nowhere to type after a mouse click.
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
            visible: shell.mockMode
            text: Strings.tr("mockNotice") + " " + (Quickshell.env("MOCK_PASSWORD") || "test")
            color: Colours.m3outline
            font.family: "Rubik"
            font.pixelSize: 11
        }
    }

    // ─────────────────────────── state ───────────────────────────

    KeyboardState {
        id: kb
    }

    QtObject {
        id: auth

        property var users: []
        property int userIndex: 0
        property var sessions: []
        property int sessionIndex: 0
        property string message: ""
        property bool messageIsError: false
        property bool revealPassword: false

        readonly property var currentUser: users.length > 0 ? users[userIndex] : null
        readonly property var currentSession: sessions.length > 0 ? sessions[sessionIndex] : null

        readonly property string username: currentUser ? currentUser.name : ""
        readonly property string displayName: currentUser ? currentUser.realname : "?"
        readonly property string avatar: currentUser && currentUser.avatar ? "file://" + currentUser.avatar : ""

        function submit(): void {
            if (greetd.busy)
                return;
            if (!currentSession) {
                message = Strings.tr("noSessions");
                messageIsError = true;
                return;
            }

            message = "";
            messageIsError = false;
            greetd.login(username, pwd.text, currentSession.exec);
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

        onFailed: description => {
            auth.message = description;
            auth.messageIsError = true;
            // Clear the reveal toggle so a failed password is never left
            // sitting on screen in plain text.
            auth.revealPassword = false;
            pwd.text = "";
            pwd.forceActiveFocus();
            shake.restart();
        }

        onInfo: msg => {
            auth.message = msg;
            auth.messageIsError = false;
        }

        onSucceeded: {
            auth.message = Strings.tr("signedIn");
            auth.messageIsError = false;
        }
    }

    Process {
        command: ["python3", Config.script("list-sessions.py")]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    auth.sessions = list;

                    const want = Quickshell.env("QUICKGREET_SESSION") || Config.defaultSession;
                    if (want) {
                        const idx = list.findIndex(s => s.id === want);
                        if (idx >= 0)
                            auth.sessionIndex = idx;
                    }
                } catch (e) {
                    console.warn("quickgreet: could not parse session list:", e);
                }
            }
        }
    }

    Process {
        command: ["python3", Config.script("list-users.py")]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    auth.users = list;

                    const want = Quickshell.env("QUICKGREET_USER") || Config.defaultUser;
                    if (want) {
                        const idx = list.findIndex(u => u.name === want);
                        if (idx >= 0)
                            auth.userIndex = idx;
                    }
                } catch (e) {
                    console.warn("quickgreet: could not parse user list:", e);
                }
            }
        }
    }
}
