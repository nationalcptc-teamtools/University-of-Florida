#!/bin/bash

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

# Extract variables from the YAML file
ssh_username=$(yq '.ssh_username' "$CONFIG_FILE")
ssh_password=$(yq '.ssh_password' "$CONFIG_FILE")
shared_dir=$(yq '.remote_mount_dir' "$CONFIG_FILE")

# Ensure all values are present
if [ -z "$ssh_username" ] || [ -z "$ssh_password" ] || [ -z "$remote_dir" ]; then
  echo "Missing values in configuration file. Please ensure all fields are properly set."
  exit 1
fi

# Create the user and set the password
adduser --gecos "" --disabled-password "$ssh_username"
echo "$ssh_username:$ssh_password" | chpasswd

# Create the directory to share
mkdir -p "$shared_dir"

# Set ownership and permissions
chown "$ssh_username":"$ssh_username" "$shared_dir"
chmod 755 "$shared_dir"

# Start and enable SSH service
systemctl enable ssh
systemctl restart ssh

echo "SSHFS server setup is complete."
echo "User '$ssh_username' can connect to this server and access '$shared_dir'."