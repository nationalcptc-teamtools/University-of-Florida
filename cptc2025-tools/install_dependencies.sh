#!/usr/bin/env bash

echo "Installing dependencies..."

# List of dependencies to install
dependencies=("sshfs" "asciinema" "tmux" "sliver" "yq" "openssh-server" "sshpass")

# Check if the script is being run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update package list and install dependencies
echo "Updating package list..."
apt-get update -y

echo "Installing dependencies..."
for package in "${dependencies[@]}"; do
  if ! dpkg -l | grep -qw "$package"; then
    echo "Installing $package..."
    apt-get install -y "$package"
  else
    echo "$package is already installed"
  fi
done

echo "All dependencies are installed."