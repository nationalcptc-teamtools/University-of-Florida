#!/bin/bash

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
   echo "Please run this script as root (e.g., sudo ./setup_sshfs_server.sh)"
   exit 1
fi

# Prompt for the new username
read -p "Enter the username to create for SSH access: " ssh_username

# Create the user and set the password
adduser --gecos "" "$ssh_username"

# Create the directory to share
read -p "Enter the full path for the shared directory (e.g., /srv/shared): " shared_dir
mkdir -p "$shared_dir"

# Set ownership and permissions
chown "$ssh_username":"$ssh_username" "$shared_dir"
chmod 755 "$shared_dir"

# Install SSH server if not already installed
if ! command -v sshd >/dev/null 2>&1; then
    echo "Installing OpenSSH server..."
    apt update
    apt install -y openssh-server
fi

# Start and enable SSH service
systemctl enable ssh
systemctl restart ssh

echo "SSHFS server setup is complete."
echo "User '$ssh_username' can connect to this server and access '$shared_dir'."