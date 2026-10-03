#!/usr/bin/env bash
set -euo pipefail

SERIAL="/dev/ttyUSB0"
PTY="/tmp/minitel-pty"
SESSION="minitel"

COLS=80
ROWS=24

export TERM=vt100
export LANG=C
export LC_ALL=C
export LC_CTYPE=C

export NO_COLOR=1
export CLICOLOR=0
export CLICOLOR_FORCE=0
export FORCE_COLOR=0
export COLORTERM=""

cleanup() {
    set +e

    if [[ -n "${MINITEL_PID:-}" ]]; then
        kill "$MINITEL_PID" 2>/dev/null || true
    fi

    if [[ -n "${SOCAT_PID:-}" ]]; then
        kill "$SOCAT_PID" 2>/dev/null || true
    fi

    tmux kill-session -t "$SESSION" 2>/dev/null || true

    rm -f "$PTY"
}

trap cleanup EXIT INT TERM

if [[ ! -e "$SERIAL" ]]; then
    echo "ERROR: serial device not found: $SERIAL" >&2
    exit 1
fi

# Clean previous instance
tmux kill-session -t "$SESSION" 2>/dev/null || true
rm -f "$PTY"

# Configure serial: 1200 baud, 7 data bits, even parity, 1 stop bit
stty -F "$SERIAL" \
    1200 \
    cs7 \
    parenb \
    -parodd \
    cstopb \
    -ixon \
    -ixoff \
    raw \
    -echo

# Create a PTY and bridge:
#
#     /dev/ttyUSB0 <-> socat <-> /tmp/minitel-pty
#
socat \
    "$SERIAL,raw,b1200,cs7,parenb=1,parodd=0,cstopb=0,ixon=0,ixoff=0,echo=0" \
    "PTY,link=$PTY,rawer,echo=0,perm=0666,wait-slave" &
SOCAT_PID=$!

# Wait for PTY
for _ in {1..100}; do
    if [[ -e "$PTY" ]]; then
        break
    fi
    sleep 0.1
done

if [[ ! -e "$PTY" ]]; then
    echo "ERROR: failed to create PTY" >&2
    exit 1
fi

# Tell the PTY that the Minitel is 80x24
stty -F "$PTY" \
    rows "$ROWS" \
    cols "$COLS"

# Create tmux session
tmux new-session \
    -d \
    -s "$SESSION" \
    -x "$COLS" \
    -y "$ROWS" \
    'exec env \
        TERM=vt100 \
        LANG=C \
        LC_ALL=C \
        LC_CTYPE=C \
        NO_COLOR=1 \
        CLICOLOR=0 \
        CLICOLOR_FORCE=0 \
        FORCE_COLOR=0 \
        COLORTERM="" \
        bash -l'

# Keep tmux fixed at 80x24
tmux set-window-option -t "$SESSION" window-size manual
tmux resize-window -t "$SESSION" -x "$COLS" -y "$ROWS"

# Remove tmux status line: full 24 lines belong to the Minitel
tmux set-option -t "$SESSION" status off

# Attach Minitel as one tmux client.
#
# The PTY is opened read/write, so keyboard input from
# the Minitel goes back into tmux.
(
    exec setsid bash -c '
        exec 3<> "$1"

        exec env \
            TERM=vt100 \
            LANG=C \
            LC_ALL=C \
            LC_CTYPE=C \
            NO_COLOR=1 \
            CLICOLOR=0 \
            CLICOLOR_FORCE=0 \
            FORCE_COLOR=0 \
            COLORTERM="" \
            tmux attach-session -t "$2" <&3 >&3 2>&3
    ' _ "$PTY" "$SESSION"
) &

MINITEL_PID=$!

sleep 0.5

echo "Minitel terminal: ${COLS}x${ROWS}, 1200 7E1"
echo "Connecting PC to tmux session '${SESSION}'..."

# PC is the second tmux client
exec tmux attach-session -t "$SESSION"
