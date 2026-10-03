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

    rm -f "$PTY" /tmp/minitel-inputrc
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
    -cstopb \
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
    cols "$COLS" \
    -echoctl \
    -echoke \
    -imaxbel

# Minimal readline behavior: no bell, no bracketed-paste control sequences.
# 3 extra bytes per paste otherwise, plus garbage on Minitel.
printf '%s\n' 'set bell-style none' 'set enable-bracketed-paste off' > /tmp/minitel-inputrc
export INPUTRC=/tmp/minitel-inputrc

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
        PAGER="less -X -S" \
        MANPAGER="less -X -S" \
        LESS=R \
        PROMPT_COMMAND="" \
        PS1="$ " \
        PS2="> " \
        INPUTRC=/tmp/minitel-inputrc \
        bash --noprofile --norc -i'

# Keep tmux fixed at 80x24: no resize storms at 120c/s
tmux set-window-option -t "$SESSION" window-size manual
tmux resize-window -t "$SESSION" -x "$COLS" -y "$ROWS"
tmux set-window-option -t "$SESSION" aggressive-resize off

# Remove tmux status line: full 24 lines belong to the Minitel
tmux set-option -t "$SESSION" status off
tmux set-option -t "$SESSION" status-interval 0
tmux set-option -t "$SESSION" display-time 0
tmux set-option -t "$SESSION" message-limit 0

# Slow-link tuning: kill every byte that is not pane content.
# alternate-screen off = vim/less do not do smcup/rmcup full repaints.
tmux set-window-option -t "$SESSION" alternate-screen off
tmux set-window-option -t "$SESSION" allow-rename off
tmux set-window-option -t "$SESSION" automatic-rename off
tmux set-window-option -t "$SESSION" monitor-activity off
tmux set-window-option -t "$SESSION" monitor-bell off
tmux set-option -t "$SESSION" visual-activity off
tmux set-option -t "$SESSION" visual-bell off
tmux set-option -t "$SESSION" visual-silence off
tmux set-option -t "$SESSION" bell-action none
tmux set-option -t "$SESSION" set-titles off
tmux set-option -t "$SESSION" history-limit 50
tmux set-option -s escape-time 0
tmux set-option -s focus-events off
tmux set-option -s set-clipboard off
tmux set-option -s default-terminal vt100

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
echo "Second client attach = one full repaint (~16s at 120c/s). Detach PC when idle."
echo "Connecting PC to tmux session '${SESSION}'..."

# PC is the second tmux client (size is pinned, so no resize storms)
exec tmux attach-session -t "$SESSION"
