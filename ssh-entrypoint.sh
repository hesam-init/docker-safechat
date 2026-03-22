#!/bin/bash

set -e

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

if [ -z "$SSH_PASSWORD" ]; then
    echo "ERROR: SSH_PASSWORD not set"
    exit 1
fi

echo "forwarder:${SSH_PASSWORD}" | chpasswd

echo "[SSH] Starting sshd..."
exec /usr/sbin/sshd -D