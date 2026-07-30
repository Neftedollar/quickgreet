import QtQuick
import Quickshell
import Quickshell.Io

// greetd protocol state machine.
//
// A login is a conversation, not a single exchange. greetd relays PAM's
// prompts one at a time and blocks until each one is answered, so this
// drives an arbitrary sequence rather than assuming "one password, one
// answer". That is what makes two-factor stacks, expired-password changes
// and informational messages work.
//
// Every auth_message MUST be answered, including the informational and
// error kinds. greetd's PAM conversation is synchronous: an unanswered
// message wedges the session worker permanently, and no timeout on their
// side ever releases it.
//
// Any failure sends cancel_session. Without it greetd keeps the
// half-configured session and rejects every later create_session with
// "a session is already being configured".
Item {
    id: root

    enum Phase {
        Idle,          // nothing in flight
        Authenticating,// waiting for greetd
        AwaitingInput, // waiting for the user to answer a prompt
        Starting,      // session requested, greeter about to be replaced
        Done           // session accepted; stay busy until we are torn down
    }

    property bool mock: false
    property int phase: Greetd.Idle

    // The form stays disabled while greetd is working and while the
    // session is starting, but not while we are waiting for the user.
    readonly property bool busy: phase === Greetd.Authenticating || phase === Greetd.Starting || phase === Greetd.Done

    readonly property bool awaitingInput: phase === Greetd.AwaitingInput

    // Seconds to wait for greetd before giving up. PAM modules can be slow
    // on purpose — pam_faillock delays are measured in seconds — so this is
    // generous. Without it any unanswered request leaves the greeter with a
    // dead form and a spinning indicator forever.
    property int timeoutSeconds: 60

    // Answer held for the first secret prompt, so the common case still
    // works as "type password, press enter". Later prompts are asked for.
    property string _pending: ""
    property bool _hasPending: false
    property var _sessionCmd: []

    signal succeeded
    signal failed(string description)

    // PAM wants something. `secret` decides whether the field masks input.
    signal prompt(string message, bool secret)

    // PAM said something. Not a question; no answer is expected from the user.
    signal notice(string message, bool isError)

    function login(username: string, password: string, sessionCmd: var): void {
        if (phase !== Greetd.Idle)
            return;

        // The bridge is checked before any state changes: assigning the
        // phase first and failing afterwards is how the form used to end
        // up permanently disabled.
        if (!proc.running) {
            root.failed(Strings.tr("bridgeMissing"));
            return;
        }

        _pending = password;
        _hasPending = true;
        _sessionCmd = sessionCmd;
        phase = Greetd.Authenticating;
        watchdog.restart();

        send({
            type: "create_session",
            username: username
        });
    }

    // Answers whatever prompt() last asked for.
    function respond(answer: string): void {
        if (phase !== Greetd.AwaitingInput)
            return;

        phase = Greetd.Authenticating;
        watchdog.restart();

        send({
            type: "post_auth_message_response",
            response: answer
        });
    }

    function cancel(): void {
        if (phase === Greetd.Idle || phase === Greetd.Done)
            return;

        watchdog.stop();
        send({
            type: "cancel_session"
        });

        // greetd answers cancel_session with its own success. Mark it so
        // that reply is consumed here instead of being mistaken for the
        // result of a later create_session.
        _cancelsInFlight++;
        reset();
    }

    function reset(): void {
        watchdog.stop();
        phase = Greetd.Idle;
        _pending = "";
        _hasPending = false;
    }

    property int _cancelsInFlight: 0

    function send(obj: var): void {
        if (!proc.running) {
            root.failed(Strings.tr("bridgeMissing"));
            reset();
            return;
        }
        proc.write(JSON.stringify(obj) + "\n");
    }

    function handle(raw: string): void {
        let msg;
        try {
            msg = JSON.parse(raw);
        } catch (e) {
            console.warn("quickgreet: unparseable line from bridge");
            return;
        }

        watchdog.stop();

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
        default:
            console.warn("quickgreet: unknown message type from greetd");
            break;
        }
    }

    function onAuthMessage(msg: var): void {
        const kind = msg.auth_message_type;
        const text = msg.auth_message || "";

        if (kind === "secret" || kind === "visible") {
            // The very first secret prompt is answered with what the user
            // already typed. Everything after it — a second factor, a
            // "New password" round, a security question — has to be asked.
            if (kind === "secret" && _hasPending) {
                const answer = _pending;
                _pending = "";
                _hasPending = false;
                phase = Greetd.Authenticating;
                watchdog.restart();
                send({
                    type: "post_auth_message_response",
                    response: answer
                });
                return;
            }

            phase = Greetd.AwaitingInput;
            root.prompt(text, kind === "secret");
            return;
        }

        // info and error are statements, not questions, but greetd still
        // blocks until each one is answered. `null` is required here:
        // greetd's conversation rejects anything else with PAM_CONV_ERR.
        root.notice(text, kind === "error");

        phase = Greetd.Authenticating;
        watchdog.restart();
        send({
            type: "post_auth_message_response",
            response: null
        });
    }

    function onSuccess(): void {
        // Swallow the acknowledgement of a cancel we sent ourselves,
        // otherwise it reads as the result of whatever came next.
        if (_cancelsInFlight > 0) {
            _cancelsInFlight--;
            return;
        }

        if (phase === Greetd.Authenticating) {
            phase = Greetd.Starting;
            watchdog.restart();
            send({
                type: "start_session",
                cmd: _sessionCmd,
                env: []
            });
            return;
        }

        if (phase === Greetd.Starting) {
            // greetd starts the session only once the greeter has exited,
            // and SIGTERMs us five seconds later if we have not. Staying in
            // Done keeps the form disabled for the moment before we quit.
            phase = Greetd.Done;
            _pending = "";
            _hasPending = false;
            root.succeeded();
        }
    }

    function onError(msg: var): void {
        const auth = msg.error_type === "auth_error";
        // Only the generic error carries text worth showing; auth failures
        // describe themselves and greetd's wording leaks socket and path
        // detail onto a screen anyone can read.
        root.failed(auth ? Strings.tr("wrongPassword") : Strings.tr("loginFailed"));
        if (!auth)
            console.warn("quickgreet: greetd error:", msg.description);
        cancel();
    }

    Timer {
        id: watchdog

        interval: root.timeoutSeconds * 1000
        repeat: false
        onTriggered: {
            console.warn("quickgreet: greetd did not respond within", root.timeoutSeconds, "s");
            root.failed(Strings.tr("timedOut"));
            root.cancel();
        }
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

        // The bridge's stderr is deliberately not forwarded to the log: it
        // is the one stream that has carried secret-adjacent detail, and
        // the greeter's output is persisted to a file others can read.
        stderr: SplitParser {
            onRead: data => {}
        }

        onExited: code => {
            console.warn("quickgreet: bridge exited with code", code);
            if (root.phase !== Greetd.Idle && root.phase !== Greetd.Done) {
                root.failed(Strings.tr("bridgeMissing"));
                root.reset();
            }
        }
    }
}
