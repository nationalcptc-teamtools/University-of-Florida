#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo bash "$DIR/install_dependencies.sh"

# Wait for server setup to finish and press Enter
echo "Wait here for server setup to finish... hit enter to continue"
read -r  # Wait for user input

sudo bash "$DIR/connect_sshfs_client.sh"

bash "$DIR/start_recorded_tmux.sh"