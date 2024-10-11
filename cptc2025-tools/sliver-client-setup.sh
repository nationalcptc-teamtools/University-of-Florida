#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Path to the config.yaml file
CONFIG_FILE="$DIR/config.yaml"
# Extract variables from the YAML file
shared_dir=$(yq -r '.local_mount_dir' "$CONFIG_FILE")
username=$(yq -r '.username' "$CONFIG_FILE")

sudo sliver-client import $shared_dir/$username.cfg
sudo sliver-client