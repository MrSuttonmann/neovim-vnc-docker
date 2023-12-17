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
    useradd --home-dir /data --shell /bin/bash --uid 1000 --gid 1000 app && \
    mkdir -p /data

RUN apt-get update && apt-get -y install wget curl fzf ripgrep tree git xclip python3 python3-pip nodejs npm tzdata ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config zip unzip subversion libgtk-4-dev

RUN apt-get install -y python3-pynvim

RUN npm i -g neovim

RUN mkdir -p /root/TMP
RUN cd /root/TMP && git clone https://github.com/neovim/neovim
RUN cd /root/TMP/neovim && git checkout stable && make -j4 && make install
RUN rm -rf /root/TMP

RUN mkdir -p /home/app/.local/share/nvim/site
RUN cd /home/app/.local/share/nvim/site && svn export https://github.com/MashMB/nvim-ide.git/trunk/nvim/spell


RUN curl -fLo /home/app/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

RUN mkdir -p /home/app/.config/nvim
RUN cd /home/app/.config/nvim && svn export https://github.com/MashMB/nvim-ide.git/trunk/nvim/config

RUN nvim --headless +PlugInstall +qall

RUN mkdir -p /home/app/.config/coc/extensions

RUN cd /home/app/.config/coc/extensions && npm install $COC --global --omit=dev

RUN apt-get update && apt-get install -y golang

RUN git clone https://github.com/jesseduffield/lazygit.git
RUN cd lazygit && go install

RUN mkdir -p /root/TMP
RUN cd /root/TMP && git clone $GIT_FLOW_GITHUB
RUN cd /root/TMP/$GIT_FLOW_DIR && git checkout master && make install

RUN rm -rf /root/TMP

COPY ./home/ /home/app/

RUN mkdir -p /home/app/workspace

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends dbus-x11 openbox tigervnc-standalone-server supervisor gosu && \
    rm -rf /var/lib/apt/lists && \
    mkdir -p /usr/share/desktop-directories
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends lxterminal nano wget openssh-client rsync ca-certificates xdg-utils htop tar xzip gzip bzip2 zip make && \
    rm -rf /var/lib/apt/lists

COPY --from=easy-novnc-build /bin/easy-novnc /usr/local/bin
COPY --from=gnvim /gnvim/ /gnvim/
COPY menu.xml /etc/xdg/openbox/

WORKDIR /gnvim
RUN make install

COPY supervisord.conf /etc/

VOLUME /data

ENV GTK_A11Y=none

WORKDIR /home/app/workspace
CMD ["sh", "-c", "chown app:app /data /dev/stdout && exec gosu app supervisord"]
