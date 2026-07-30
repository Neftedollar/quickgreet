import QtQuick
import Quickshell
import Quickshell.Io

// greetd protocol state machine.
//
// Login sequence:
//   create_session -> auth_message(secret) -> post_auth_message_response
//                  -> success              -> start_session -> session starts
//
// Any failure sends cancel_session. Without it greetd is left holding a
// half-created session and every later attempt is rejected.
Item {
    id: root

    enum Phase {
        Idle,
        Authenticating,
        Starting
    }

    property bool mock: false
    property int phase: Greetd.Idle
    property bool busy: phase !== Greetd.Idle

    // Holds the password between create_session and the auth_message
    // that actually asks for it.
    property string _password: ""
    property var _sessionCmd: []

    signal succeeded
    signal failed(string description)
    signal info(string message)

    function login(username: string, password: string, sessionCmd: var): void {
        if (busy)
            return;

        _password = password;
        _sessionCmd = sessionCmd;
        phase = Greetd.Authenticating;

        send({
            type: "create_session",
            username: username
        });
    }

    function cancel(): void {
        if (phase === Greetd.Idle)
            return;
        send({
            type: "cancel_session"
        });
        reset();
    }

    function reset(): void {
        phase = Greetd.Idle;
        _password = "";
    }

    function send(obj: var): void {
        if (!proc.running) {
            root.failed(Strings.tr("bridgeMissing"));
            return;
        }
        proc.write(JSON.stringify(obj) + "\n");
    }

    function handle(raw: string): void {
        let msg;
        try {
            msg = JSON.parse(raw);
        } catch (e) {
            console.warn("quickgreet: unparseable line from bridge:", raw);
            return;
        }

        switch (msg.type) {
        case "auth_message":
            onAuthMessage(msg);
            break;
        case "success":
            onSuccess();
            break;
        case "error":
            onError(msg);
            break;
        }
    }

    function onAuthMessage(msg: var): void {
        const kind = msg.auth_message_type;

        if (kind === "secret") {
            send({
                type: "post_auth_message_response",
                response: _password
            });
            _password = "";
        } else if (kind === "visible") {
            // A prompt expecting a visible answer, e.g. a second factor.
            // Unsupported for now; cancel rather than hang forever.
            root.failed(msg.auth_message || Strings.tr("extraInput"));
            cancel();
        } else if (kind === "error") {
            root.failed(msg.auth_message || Strings.tr("wrongPassword"));
        } else {
            root.info(msg.auth_message || "");
            // greetd still expects a reply to informational messages.
            send({
                type: "post_auth_message_response",
                response: null
            });
        }
    }

    function onSuccess(): void {
        if (phase === Greetd.Authenticating) {
            phase = Greetd.Starting;
            send({
                type: "start_session",
                cmd: _sessionCmd,
                env: []
            });
        } else if (phase === Greetd.Starting) {
            // greetd accepted the session and will terminate the greeter.
            root.succeeded();
            reset();
        }
    }

    function onError(msg: var): void {
        const desc = msg.description || "unknown error";
        root.failed(msg.error_type === "auth_error" ? Strings.tr("wrongPassword") : desc);
        cancel();
    }

    Process {
        id: proc

        command: {
            const script = Config.script("greetd-bridge.py");
            return root.mock ? ["python3", script, "--mock"] : ["python3", script];
        }
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => root.handle(data)
        }

        stderr: SplitParser {
            onRead: data => console.log("quickgreet/bridge:", data)
        }

        onExited: code => {
            console.warn("quickgreet: bridge exited with code", code);
            root.reset();
        }
    }
}
