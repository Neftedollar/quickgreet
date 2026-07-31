import QtQuick
import Quickshell

// quickgreet — a greetd greeter built on Quickshell.
//
// This file is the composition root and nothing else: it wires the view to
// the state and the state to the protocol. Every piece of the interface
// lives in its own component beside it.
//
// Run against real greetd by launching this config from a greetd session;
// run ./test.sh for a mock mode that exercises the UI without logging in.
ShellRoot {
    id: shell

    readonly property bool mockMode: Quickshell.env("QUICKGREET_MOCK") === "1"

    // Backing out has to work while greetd is busy, which is exactly when
    // it is most needed: a PAM stack can hold the conversation for a long
    // time — a fingerprint read, a faillock delay — and the field is
    // disabled throughout. Handling this only inside the field meant the
    // key never arrived, leaving the watchdog as the only way out.
    //
    // Not called escape(): that is a legacy JavaScript global, and QML
    // rejects it as a method name.
    function dismiss(): void {
        if (bottom.sessionsExpanded || card.userListOpen) {
            bottom.sessionsExpanded = false;
            card.closeLists();
            return;
        }
        if (greetd.awaitingInput || greetd.busy) {
            greetd.cancel();
            auth.endPrompt();
            auth.note("", false);
        }
        card.clearField();
        card.grabFocus();
    }

    FloatingWindow {
        id: win

        title: "quickgreet"
        color: Colours.m3background
        visible: true

        implicitWidth: shell.mockMode ? 1280 : 1920
        implicitHeight: shell.mockMode ? 800 : 1080

        Wallpaper {
            anchors.fill: parent
        }

        // Dismisses open dropdowns on a click anywhere else.
        //
        // The z values matter. Declared later in the file, this would sit
        // above the card and swallow every click meant for the user list,
        // which then looked alive but could never be used.
        MouseArea {
            anchors.fill: parent
            z: 1
            visible: bottom.sessionsExpanded || card.userListOpen
            onClicked: {
                bottom.sessionsExpanded = false;
                card.closeLists();
            }
        }

        ClockBlock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.11
        }

        LoginCard {
            id: card

            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.height * 0.06
            z: 2

            users: auth.users
            userIndex: auth.userIndex
            promptText: auth.promptText
            promptSecret: auth.promptSecret
            busy: greetd.busy
            capsLock: kb.capsLockKnown && kb.capsLock

            message: {
                if (auth.message.length > 0)
                    return auth.message;
                if (kb.capsLockKnown && kb.capsLock)
                    return Strings.tr("capsLockOn");
                if (!fonts.iconsPresent)
                    return Strings.tr("iconFontMissing");
                return "";
            }
            messageIsError: auth.messageIsError || (kb.capsLockKnown && kb.capsLock) || !fonts.iconsPresent

            onSubmitted: answer => {
                if (greetd.busy)
                    return;
                auth.submit(answer, greetd.awaitingInput);
                clearField();
            }

            onUserSelected: index => {
                auth.userIndex = index;
                closeLists();
                clearField();
                grabFocus();
            }

            onEscaped: shell.dismiss()
        }

        BottomBar {
            id: bottom

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Style.pad.screen
            z: 2

            sessions: auth.sessions
            sessionIndex: auth.sessionIndex
            capsLock: kb.capsLockKnown && kb.capsLock
            layout: kb.layoutShort
            layoutKnown: kb.layoutKnown
            layoutSwitchable: kb.canSwitch

            onSessionSelected: index => auth.sessionIndex = index
            onCycleLayout: {
                kb.cycleLayout();
                // Focus returns to the field, otherwise there is nowhere
                // to type after a mouse click.
                card.grabFocus();
            }

            // QUICKGREET_OPEN=1 starts with the list expanded, which is how
            // its layout gets captured during development.
            Component.onCompleted: if (Quickshell.env("QUICKGREET_OPEN") === "1")
                sessionsExpanded = true
        }

        // Works whatever the field's state, unlike a handler inside it.
        Shortcut {
            sequences: ["Escape"]
            context: Qt.WindowShortcut
            onActivated: shell.dismiss()
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            z: 3
            visible: shell.mockMode
            text: Strings.tr("mockNotice", Quickshell.env("MOCK_PASSWORD") || "test")
            color: Colours.m3outline
            font.family: Style.font.sans
            font.pixelSize: Style.size.caption
        }
    }

    // ─────────────────────────── state ───────────────────────────

    KeyboardState {
        id: kb
    }

    // A missing icon font renders every icon as its ligature name, which
    // gives the user nothing to search for unless it is named explicitly.
    QtObject {
        id: fonts

        readonly property bool iconsPresent: Qt.fontFamilies().includes(Config.iconFontFamily)

        Component.onCompleted: if (!iconsPresent)
            console.warn("quickgreet: icon font", Config.iconFontFamily, "is not installed; icons will render as text")
    }

    AuthState {
        id: auth

        onLoginRequested: (username, password, sessionCmd) => greetd.login(username, password, sessionCmd)
        onResponseRequested: answer => greetd.respond(answer)
    }

    Greetd {
        id: greetd

        mock: shell.mockMode
        timeoutSeconds: Config.timeoutSeconds

        // PAM wants something more: a second factor, a new password, an
        // answer to a question. Its own wording becomes the label.
        onPrompt: (message, secret) => {
            auth.beginPrompt(message, secret);
            card.clearField();
            card.grabFocus();
        }

        // Shown verbatim: these messages are written for people and are
        // translated, so matching their text breaks on the first
        // non-English system.
        onNotice: (message, isError) => auth.note(message, isError)

        onFailed: description => {
            auth.note(description, true);
            auth.endPrompt();
            card.reject();
        }

        onSucceeded: {
            auth.note(Strings.tr("signedIn"), false);
            auth.endPrompt();
            card.clearField();
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

    JsonSource {
        script: "list-sessions.py"
        // Session names carry Name[xx] variants; hand the script the
        // language the greeter is actually displaying.
        args: ["--locale", Strings.qtLocale]

        onLoaded: data => {
            auth.sessions = data;
            auth.selectSessionById(Quickshell.env("QUICKGREET_SESSION") || Config.defaultSession);
            if (data.length === 0)
                auth.note(Strings.tr("noSessions"), true);
        }
        onFailed: auth.note(Strings.tr("noSessions"), true)
    }

    JsonSource {
        script: "list-users.py"

        onLoaded: data => {
            auth.users = data;
            auth.selectUserByName(Quickshell.env("QUICKGREET_USER") || Config.defaultUser);
            if (data.length === 0)
                auth.note(Strings.tr("noUsers"), true);
        }
        onFailed: auth.note(Strings.tr("noUsers"), true)
    }
}
