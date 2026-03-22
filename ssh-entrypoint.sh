#!/bin/bash

set -e

# Set password at runtime from environment variable
if [ -n "$SSH_PASSWORD" ]; then
    echo "root:${SSH_PASSWORD}" | chpasswd
fi

# Re-generate host keys if volume mounted (fresh container)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

echo "[SSH] Starting sshd..."
exec /usr/sbin/sshd -D