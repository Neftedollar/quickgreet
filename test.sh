#!/usr/bin/env bash
# Runs quickgreet from a source checkout as an ordinary window, against a
# mock greetd. No real authentication takes place; the whole UI and the
# full protocol flow are exercised, but nobody is logged in.
#
#   ./test.sh              accepts the password "test"
#   ./test.sh -k           stop a running instance
#   MOCK_PASSWORD=x ./test.sh
#
# MOCK_SCENARIO picks the conversation the mock plays back. The default
# is a single password prompt; the others exercise paths the UI used to
# handle wrongly and that a plain success can never reach:
#
#   normal   password, then success
#   2fa      password, then a visible code prompt (any 6 digits)
#   expired  password, then two prompts for a new one
#   info     an informational message before the password
#   lockout  an error message, the kind that used to wedge the greeter
#   hang     no reply at all, to exercise the timeout
#
# Shutdown goes through a PID file rather than a command-line pattern on
# purpose. Any pattern broad enough to match the greeter ("qs -c ...",
# "quickshell.*greet") also matches this script's own path and the
# command that launches it, so pkill would kill the calling shell.

set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PIDFILE=/tmp/quickgreet-test.pid
LOG="${QUICKGREET_LOG:-/tmp/quickgreet-test.log}"

stop() {
    [ -f "$PIDFILE" ] || return 0

    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null)
    rm -f "$PIDFILE"

    case "$pid" in
        ''|*[!0-9]*) return 0 ;;
    esac

    kill -0 "$pid" 2>/dev/null || return 0

    kill "$pid" 2>/dev/null
    for _ in $(seq 10); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    kill -9 "$pid" 2>/dev/null

    echo "stopped PID $pid"
}

stop
[ "${1:-}" = "-k" ] && exit 0

export QUICKGREET_MOCK=1
export MOCK_PASSWORD="${MOCK_PASSWORD:-test}"
export MOCK_SCENARIO="${MOCK_SCENARIO:-normal}"
export QUICKGREET_SCRIPTS="$here/scripts"

# Prefer an untracked local config if one exists, so a developer can
# point at their own wallpaper and colour scheme without touching the
# example that ships with the project.
if [ -z "${QUICKGREET_CONFIG:-}" ]; then
    if [ -f "$here/config/config.dev.json" ]; then
        export QUICKGREET_CONFIG="$here/config/config.dev.json"
    else
        export QUICKGREET_CONFIG="$here/config/config.example.json"
    fi
fi

echo "mock mode · scenario ${MOCK_SCENARIO} · password '${MOCK_PASSWORD}'"

: > "$LOG"
setsid qs -p "$here/qml/shell.qml" </dev/null >"$LOG" 2>&1 &
pid=$!
echo "$pid" > "$PIDFILE"

sleep 4

if kill -0 "$pid" 2>/dev/null; then
    echo "running, PID $pid, log: $LOG"
else
    echo "failed to start:"
    sed 's/^/    /' "$LOG"
    rm -f "$PIDFILE"
    exit 1
fi
