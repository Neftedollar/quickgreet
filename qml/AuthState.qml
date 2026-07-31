import QtQuick
import Quickshell

// Who is logging in, into what, and what the screen currently says.
//
// Holds no reference to any view. The password is never one of its fields:
// it arrives as an argument to submit() and is handed straight to the
// protocol layer. That is what makes this object testable on its own, and
// it is why the answer field emits its text rather than exposing it.
QtObject {
    id: root

    property var users: []
    property int userIndex: 0
    property var sessions: []
    property int sessionIndex: 0

    property string message: ""
    property bool messageIsError: false

    // What PAM last asked for; empty for the ordinary password round.
    property string promptText: ""
    property bool promptSecret: true

    readonly property var currentUser: users.length > 0 ? users[userIndex] : null
    readonly property var currentSession: sessions.length > 0 ? sessions[sessionIndex] : null

    readonly property string username: currentUser ? currentUser.name : ""

    signal loginRequested(string username, string password, var sessionCmd)
    signal responseRequested(string answer)

    function note(text: string, isError: bool): void {
        message = text;
        messageIsError = isError;
    }

    function beginPrompt(text: string, secret: bool): void {
        promptText = text;
        promptSecret = secret;
    }

    function endPrompt(): void {
        promptText = "";
        promptSecret = true;
    }

    // Enter either starts a login or answers whatever PAM last asked.
    function submit(answer: string, awaitingInput: bool): void {
        if (awaitingInput) {
            root.responseRequested(answer);
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
        root.loginRequested(username, answer, currentSession.exec);
    }

    function selectSessionById(id: string): void {
        if (!id)
            return;
        const idx = sessions.findIndex(s => s.id === id);
        if (idx >= 0)
            sessionIndex = idx;
    }

    function selectUserByName(name: string): void {
        if (!name)
            return;
        const idx = users.findIndex(u => u.name === name);
        if (idx >= 0)
            userIndex = idx;
    }
}
