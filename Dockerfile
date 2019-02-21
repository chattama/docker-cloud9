FROM centos:7

ARG LOCALE=ja_JP.UTF-8
ARG TZ=Asia/Tokyo
ARG UID=1000
ARG GID=1000
ARG USER=c9user
ARG GROUP=c9user
ARG HOME=/home/$USER
ARG INST_FIXUID=https://github.com/boxboat/fixuid/releases/download/v0.4/fixuid-0.4-linux-amd64.tar.gz
ARG INST_NODE=https://rpm.nodesource.com/setup_8.x
ARG INST_NVM=https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh

ENV C9_AUTH_USER=c9user \
    C9_AUTH_PASS=c9user \
    C9ROOT=/cloud9 \
    WORKSPACE=$HOME/workspace

# ------------------------------------------------------------------------------
# environment
# ------------------------------------------------------------------------------
RUN groupadd -g $GID $GROUP && \
    useradd -d $HOME --shell /bin/bash -g $GROUP -u $UID $USER

RUN ln -f -s /usr/share/zoneinfo/$TZ  /etc/localtime && \
    echo "ZONE=\"$TZ\"\nUTC=true"   > /etc/sysconfig/clock && \
    echo "LOCALE=\"$LOCALE"         > /etc/locale.conf

# ------------------------------------------------------------------------------
# basic install
# ------------------------------------------------------------------------------
RUN yum update -y && \
    yum install -y \
            epel-release && \
    yum groupinstall -y \
            "Development Tools" && \
    yum install -y \
            g++ glibc-static openssl-devel httpd-tools git libxml2-dev nfs-utils curl vim nano \
            bash-completion bash-completion-extras \
            wget

RUN cp -f /usr/share/git-core/contrib/completion/git-prompt.sh /etc/bash_completion.d/

# ------------------------------------------------------------------------------
# fixuid
# ------------------------------------------------------------------------------
RUN USER=$USER && \
    GROUP=$GROUP && \
    curl -SsL $INST_FIXUID | tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml

# ------------------------------------------------------------------------------
# nodejs
# ------------------------------------------------------------------------------
RUN curl -sL $INST_NODE | bash -
RUN yum install -y nodejs

# ------------------------------------------------------------------------------
# Install Cloud9 SDK
# ------------------------------------------------------------------------------
RUN mkdir -p $C9ROOT && \
    git clone https://github.com/c9/core.git $C9ROOT

WORKDIR $C9ROOT

RUN scripts/install-sdk.sh
RUN npm install -g \
        pug-cli \
        forever

RUN sed -i -e 's_127.0.0.1_0.0.0.0_g' $C9ROOT/configs/standalone.js
RUN sed -i -e 's_127.0.0.1_0.0.0.0_g' $C9ROOT/configs/standalone.js

RUN yum clean all && rm -rf /tmp/* /var/tmp/*

# ------------------------------------------------------------------------------
# allow binding for and application running for non-root
# ------------------------------------------------------------------------------
RUN mkdir -p $HOME/.c9
RUN mkdir -p $WORKSPACE
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/node
RUN chown -R $USER:$GROUP $HOME
RUN chown -R $USER:$GROUP $WORKSPACE

# ------------------------------------------------------------------------------
# Expose ports.
# ------------------------------------------------------------------------------
EXPOSE 80
EXPOSE 3000

# ------------------------------------------------------------------------------
# Startup commands and entrypoint
# ------------------------------------------------------------------------------
ENTRYPOINT ["fixuid"]
CMD ["/bin/sh", "-c", "/usr/bin/node $C9ROOT/server.js --listen 0.0.0.0 --port 80 --auth $C9_AUTH_USER:$C9_AUTH_PASS -w $WORKSPACE"]

# ------------------------------------------------------------------------------
# change user
# ------------------------------------------------------------------------------
USER $USER:$GROUP

WORKDIR $HOME

RUN curl -o- $INST_NVM | bash
RUN echo 'PS1='\''\[\033[01;32m\]$(echo $USER)\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " (%s)" 2>/dev/null) $ '\' \
        >> $HOME/.bashrc
