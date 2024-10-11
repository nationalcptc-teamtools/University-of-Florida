#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $DIR

sudo bash "./install_dependencies.sh"

sudo bash "./setup_sshfs_server.sh"
sudo bash "./connect_sshfs_client.sh"

bash "./start_recorded_tmux.sh" server