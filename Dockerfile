FROM archlinux:latest

RUN pacman -Sy tmux socat ncurses fastfetch nano vim links --noconfirm

ENV TERM=vt100 \
    LANG=C \
    LC_ALL=C \
    LC_CTYPE=C \
    NO_COLOR=1 \
    CLICOLOR=0 \
    CLICOLOR_FORCE=0 \
    FORCE_COLOR=0 \
    COLORTERM=""

COPY minitel.sh /usr/local/bin/minitel.sh
RUN chmod +x /usr/local/bin/minitel.sh

ENTRYPOINT ["/usr/local/bin/minitel.sh"]
