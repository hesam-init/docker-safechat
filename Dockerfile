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

RUN ssh-keygen -A && \
    sed -i \
        -e 's/.*PermitRootLogin.*/PermitRootLogin yes/' \
        -e 's/.*Port 22.*/Port 22/' \
        -e 's/.*AllowTcpForwarding.*/AllowTcpForwarding yes/' \
        -e 's/.*GatewayPorts.*/GatewayPorts yes/' \
        /etc/ssh/sshd_config

# Set root password
RUN echo "root:${PASSWORD}" | chpasswd && \
    echo "export VISIBLE=now" >> /etc/profile

COPY ssh-entrypoint.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

EXPOSE 22

CMD ["/usr/local/bin/startup.sh"]