#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if yq is installed (a command-line YAML processor)
if ! command -v yq &> /dev/null
then
    echo "yq could not be found. Please install yq to proceed."
    exit 1
fi

# Path to the config.yaml file
CONFIG_FILE="config.yaml"
# Extract variables from the YAML file
shared_dir=$(yq -r '.local_mount_dir' "$CONFIG_FILE")
username=$(yq -r '.username' "$CONFIG_FILE")

echo "Starting recording..."
cd ~
asciinema rec terminal.cast --command=$DIR/"$1"_tmux_setup.ssh --append