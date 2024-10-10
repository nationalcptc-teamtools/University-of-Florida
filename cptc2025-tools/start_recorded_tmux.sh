#!/usr/bin/env bash

# Check if yq is installed (a command-line YAML processor)
if ! command -v yq &> /dev/null
then
    echo "yq could not be found. Please install yq to proceed."
    exit 1
fi

# Path to the config.yaml file
CONFIG_FILE="config.yaml"
# Extract variables from the YAML file
local_mount=$(yq '.local_mount_dir' "$CONFIG_FILE")
username=$(yq '.username' "$CONFIG_FILE")

recording_dir="$shared_dir/$username/terminal.cast"

echo "Starting recording..."
asciinema rec $recording_dir

# Start tmux in home dir
cd ~
tmux