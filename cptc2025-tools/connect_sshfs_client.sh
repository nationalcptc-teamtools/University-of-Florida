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

# Path to the config.yaml file
CONFIG_FILE="config.yaml"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $CONFIG_FILE not found!"
  exit 1
fi

# Extract variables from the YAML file
server_ip=$(yq '.server_ip' "$CONFIG_FILE")
ssh_username=$(yq '.ssh_username' "$CONFIG_FILE")
ssh_password=$(yq '.ssh_password' "$CONFIG_FILE")
remote_dir=$(yq '.remote_mount_dir' "$CONFIG_FILE")
local_mount=$(yq '.local_mount_dir' "$CONFIG_FILE")

# Ensure all values are present
if [ -z "$server_ip" ] || [ -z "$ssh_username" ] || [ -z "$ssh_password" ] || [ -z "$remote_dir" ] || [ -z "$local_mount" ]; then
  echo "Missing values in configuration file. Please ensure all fields are properly set."
  exit 1
fi

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