FROM golang:1.14-buster AS easy-novnc-build
WORKDIR /src
RUN go mod init build && \
    go get github.com/geek1011/easy-novnc@v1.1.0 && \
    go build -o /bin/easy-novnc github.com/geek1011/easy-novnc

FROM rust:1.74-bookworm AS gnvim
RUN apt-get update -y && \
    apt-get install libgtk-4-dev -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists
RUN git clone https://github.com/vhakulinen/gnvim.git
WORKDIR gnvim
RUN make build
RUN make install

WORKDIR /src

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends dbus-x11 openbox tigervnc-standalone-server supervisor gosu && \
    rm -rf /var/lib/apt/lists && \
    mkdir -p /usr/share/desktop-directories
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends lxterminal nano wget openssh-client rsync ca-certificates xdg-utils htop tar xzip gzip bzip2 zip unzip && \
    rm -rf /var/lib/apt/lists
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends neovim && \
    rm -rf /var/lib/apt/lists

COPY --from=easy-novnc-build /bin/easy-novnc /usr/local/bin
FROM mashmb/nvim:1.0.0 AS neovim
COPY --from=gnvim /usr/local/bin/gnvim /usr/local/bin/
COPY menu.xml /etc/xdg/openbox/
COPY supervisord.conf /etc/
EXPOSE 8080

RUN groupadd --gid 1000 app && \
    useradd --home-dir /data --shell /bin/bash --uid 1000 --gid 1000 app && \
    mkdir -p /data
VOLUME /data

ENV GTK_A11Y=none

CMD ["sh", "-c", "chown app:app /data /dev/stdout && exec gosu app supervisord"]
