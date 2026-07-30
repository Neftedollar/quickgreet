import QtQuick
import Quickshell
import Quickshell.Io

// Runs one of the helper scripts and hands back its parsed JSON.
//
// Waits for the configuration before starting: the script path is built
// from a configured directory, and launching at component completion runs
// it from the default location instead.
//
// A non-zero exit is reported rather than swallowed. Both callers use this
// to enumerate things a login needs, so "the script failed" and "there is
// genuinely nothing" must not look the same on screen.
Item {
    id: root

    required property string script

    signal loaded(var data)
    signal failed(string reason)

    Process {
        id: proc

        running: Config.ready
        command: ["python3", Config.script(root.script)]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || !text.trim()) {
                    root.failed("empty output from " + root.script);
                    return;
                }
                try {
                    root.loaded(JSON.parse(text));
                } catch (e) {
                    console.warn("quickgreet:", root.script, "produced unparseable output:", e);
                    root.failed("bad output from " + root.script);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text && text.trim())
                console.warn("quickgreet:", root.script + ":", text.trim())
        }

        onExited: code => {
            if (code !== 0) {
                console.warn("quickgreet:", root.script, "exited with", code);
                root.failed(root.script + " exited with " + code);
            }
        }
    }
}
