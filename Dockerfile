FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        tmux \
        socat \
        ncurses-term \
        util-linux \
        procps \
        neofetch \
        build-essential \
        gdb \
        nano \
        vim \
	curl \
	links \
    && rm -rf /var/lib/apt/lists/*

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
