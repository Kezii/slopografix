FROM archlinux:latest

RUN pacman -Sy tmux socat ncurses fastfetch nano vim links git base-devel --noconfirm

RUN useradd -m slop 
USER slop
RUN cd $HOME && git clone https://aur.archlinux.org/claude-code.git && cd claude-code && makepkg -s --noconfirm
USER root
RUN cd /home/slop/claude-code && pacman -U *.pkg.tar.* --noconfirm


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
