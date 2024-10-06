#!/bin/bash

# Check if sshfs is installed
if ! command -v sshfs >/dev/null 2>&1; then
    echo "sshfs is not installed. Installing now..."
    sudo apt update
    sudo apt install -y sshfs
fi

# Prompt for server details and credentials
read -p "Enter the server IP address or hostname: " server_ip
read -p "Enter the SSH username: " ssh_username
read -p "Enter the remote directory to mount (e.g., /srv/shared): " remote_dir
read -p "Enter the local mount point (e.g., /mnt/shared): " local_mount

# Create local mount point if it doesn't exist
mkdir -p "$local_mount"

# Mount the remote directory using sshfs
echo "Mounting remote directory..."
sshfs "$ssh_username@$server_ip:$remote_dir" "$local_mount"

if [[ $? -eq 0 ]]; then
    echo "Successfully mounted $remote_dir to $local_mount"
else
    echo "Failed to mount the remote directory."
    exit 1
fi

# Option to unmount
read -p "Do you want to unmount the directory now? (y/n): " unmount_choice

if [[ "$unmount_choice" == "y" || "$unmount_choice" == "Y" ]]; then
    fusermount -u "$local_mount"
    echo "Unmounted $local_mount"
fi