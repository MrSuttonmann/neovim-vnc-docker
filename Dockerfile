FROM golang:1.14-buster AS go-builder
WORKDIR /src/novnc
RUN go mod init build && \
    go get github.com/geek1011/easy-novnc@v1.1.0 && \
    go build -o /bin/easy-novnc github.com/geek1011/easy-novnc
WORKDIR /src/lazygit
RUN go mod init build && \
    go get github.com/jesseduffield/lazygit@latest && \
    go build -o /bin/lazygit github.com/jesseduffield/lazygit

FROM rust:1.74-bookworm AS gnvim
RUN apt-get update -y && \
    apt-get install libgtk-4-dev -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists && \
    git clone https://github.com/vhakulinen/gnvim.git && cd gnvim && make build

FROM debian:bookworm
WORKDIR /src

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV TZ=Europe/London

EXPOSE 8080

ARG COC='coc-css coc-eslint coc-html coc-json coc-sh coc-sql coc-tsserver coc-yaml'
ARG GIT_FLOW_GITHUB='https://github.com/petervanderdoes/gitflow-avh.git'
ARG GIT_FLOW_DIR='gitflow-avh'

RUN groupadd --gid 1000 app && \
    useradd --create-home --shell /bin/bash --uid 1000 --gid 1000 app && \
    mkdir -p /data && \
    apt-get update && apt-get -y install wget curl fzf ripgrep tree git xclip python3 python3-pip nodejs npm \
        tzdata ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config zip unzip subversion libgtk-4-dev python3-pynvim && \
    npm i -g neovim

RUN mkdir -p /root/TMP && \
 cd /root/TMP && git clone https://github.com/neovim/neovim && \
 cd /root/TMP/neovim && git checkout stable && make -j4 && make install && \
 rm -rf /root/TMP


USER app
RUN curl -fLo /home/app/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim && \
 mkdir -p /home/app/.config/nvim && \
 cd /home/app/.config/nvim && svn export https://github.com/MashMB/nvim-ide.git/trunk/nvim/config && \
 mkdir -p /home/app/.local/share/nvim/site && \
 cd /home/app/.local/share/nvim/site && svn export https://github.com/MashMB/nvim-ide.git/trunk/nvim/spell && \
 nvim --headless +PlugInstall +qall && \
 mkdir -p /home/app/.config/coc/extensions

USER root
RUN cd /home/app/.config/coc/extensions && npm install $COC --global --omit=dev && \
    mkdir -p /root/TMP && \
    cd /root/TMP && git clone $GIT_FLOW_GITHUB && \
    cd /root/TMP/$GIT_FLOW_DIR && git checkout master && make install && \
    rm -rf /root/TMP

COPY ./home/ /home/app/

RUN mkdir -p /home/app/workspace && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends dbus-x11 openbox tigervnc-standalone-server supervisor gosu && \
    rm -rf /var/lib/apt/lists && \
    mkdir -p /usr/share/desktop-directories && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends lxterminal nano wget openssh-client rsync ca-certificates xdg-utils htop tar xzip gzip bzip2 zip make && \
    rm -rf /var/lib/apt/lists

COPY --from=go-builder /bin/easy-novnc /usr/local/bin
COPY --from=go-builder /bin/lazygit /usr/local/bin
COPY --from=gnvim /gnvim/ /gnvim/
COPY menu.xml /etc/xdg/openbox/

WORKDIR /gnvim
RUN make install

COPY supervisord.conf /etc/

VOLUME /data

ENV GTK_A11Y=none

WORKDIR /home/app/workspace
CMD ["sh", "-c", "chown app:app /data /dev/stdout && exec gosu app supervisord"]
