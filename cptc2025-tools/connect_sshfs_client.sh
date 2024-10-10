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
server_ip=$(yq -r '.server_ip' "$CONFIG_FILE")
ssh_username=$(yq -r '.ssh_username' "$CONFIG_FILE")
ssh_password=$(yq -r '.ssh_password' "$CONFIG_FILE")
remote_dir=$(yq -r '.remote_mount_dir' "$CONFIG_FILE")
local_mount=$(yq -r '.local_mount_dir' "$CONFIG_FILE")
username=$(yq -r '.username' "$CONFIG_FILE")

# Create local mount point if it doesn't exist
mkdir -p "$local_mount"

# Mount the remote directory using sshfs with password authentication
echo "Mounting remote directory..."
echo "$ssh_password" | sshfs "$ssh_username@$server_ip:$remote_dir" "$local_mount" -o password_stdin

if [[ $? -eq 0 ]]; then
    echo "Successfully mounted $remote_dir to $local_mount"
else
    echo "Failed to mount the remote directory."
    exit 1
fi

# Create directory with username
user_shared_dir="$shared_dir/$username"
mkdir -p "$user_shared_dir"