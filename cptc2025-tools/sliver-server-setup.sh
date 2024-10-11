#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Path to the config.yaml file
CONFIG_FILE="$DIR/config.yaml"
# Extract variables from the YAML file
shared_dir=$(yq -r '.local_mount_dir' "$CONFIG_FILE")
server_ip=$(yq -r '.server_ip' "$CONFIG_FILE")

mkdir -p $shared_dir/sliver/profile
mkdir -p $shared_dir/sliver/payloads

chmod +x $DIR/sliver-server-setup.exp
$DIR/sliver-server-setup.exp $server_ip $shared_dir