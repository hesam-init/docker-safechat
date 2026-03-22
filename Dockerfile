# ═══════════════════════════════════════════════════════════════════════════════
# BASE STAGE - Common dependencies and configurations
# ═══════════════════════════════════════════════════════════════════════════════
FROM docker.iranserver.com/alpine:3.23 AS base

RUN echo "https://mirror.arvancloud.ir/alpine/v3.23/main" > /etc/apk/repositories && \
    echo "https://mirror.arvancloud.ir/alpine/v3.23/community" >> /etc/apk/repositories

RUN apk update
RUN apk add --no-cache openssh bash

RUN rm -rf /var/cache/apk/*

# ═══════════════════════════════════════════════════════════════════════════════
# SSH STAGE - SSH Server
# ═══════════════════════════════════════════════════════════════════════════════
FROM base AS ssh

ARG SSH_PASSWORD=root

RUN sed -i \
    -e 's/.*PermitRootLogin.*/PermitRootLogin no/' \
    -e 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' \
    -e 's/.*PubkeyAuthentication.*/PubkeyAuthentication no/' \
    -e 's/.*X11Forwarding.*/X11Forwarding no/' \
    -e 's/.*AllowAgentForwarding.*/AllowAgentForwarding no/' \
    -e 's/.*PermitTunnel.*/PermitTunnel no/' \
    -e 's/.*MaxAuthTries.*/MaxAuthTries 10/' \
    -e 's/.*LoginGraceTime.*/LoginGraceTime 20/' \
    -e 's/.*AllowTcpForwarding.*/AllowTcpForwarding yes/' \
    -e 's/.*GatewayPorts.*/GatewayPorts yes/' \
    /etc/ssh/sshd_config

# RUN adduser -D -s /bin/bash forwarder
RUN adduser -D -s /sbin/nologin forwarder

# Set users password
# RUN echo "root:${PASSWORD}" | chpasswd
RUN echo "forwarder:${SSH_PASSWORD}" | chpasswd

RUN echo "export VISIBLE=now" >> /etc/profile

COPY ssh-entrypoint.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

EXPOSE 22

CMD ["/usr/local/bin/startup.sh"]