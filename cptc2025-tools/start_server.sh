#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo bash "$DIR/install_dependencies.sh"

sudo bash "$DIR/setup_sshfs_server.sh"

bash "$DIR/start_recorded_tmux.sh"