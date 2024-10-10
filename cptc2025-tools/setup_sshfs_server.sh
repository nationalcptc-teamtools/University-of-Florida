#!/usr/bin/env bash

# Check if yq is installed (a command-line YAML processor)
if ! command -v yq &> /dev/null
then
    echo "yq could not be found. Please install yq to proceed."
    exit 1
fi

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
   echo "Please run this script as root (e.g., sudo ./setup_sshfs_server.sh)"
   exit 1
fi

# Path to the config.yaml file
CONFIG_FILE="config.yaml"
# Extract variables from the YAML file
ssh_username=$(yq -r '.ssh_username' "$CONFIG_FILE")
ssh_password=$(yq -r '.ssh_password' "$CONFIG_FILE")
shared_dir=$(yq -r '.remote_mount_dir' "$CONFIG_FILE")
username=$(yq -r '.username' "$CONFIG_FILE")

# Create the user and set the password
adduser --gecos "" --disabled-password "$ssh_username"
echo "$ssh_username:$ssh_password" | sudo chpasswd

# Create the directory to share
mkdir -p "$shared_dir"
# Create the directory to share with username
user_shared_dir="$shared_dir/$username"
mkdir -p "$user_shared_dir"

# Set ownership and permissions
chown "$ssh_username":"$ssh_username" "$shared_dir"
chmod 755 "$shared_dir"

# Start and enable SSH service
systemctl enable ssh
systemctl restart ssh

echo "SSHFS server setup is complete."
echo "User '$ssh_username' can connect to this server and access '$shared_dir'."