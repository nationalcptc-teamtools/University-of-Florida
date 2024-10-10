#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo bash "$DIR/install_dependencies.sh"

sudo bash "$DIR/connect_sshfs_client.sh"

bash "$DIR/start_recorded_tmux.sh"