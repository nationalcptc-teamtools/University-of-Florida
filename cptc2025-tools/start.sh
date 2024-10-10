#!/usr/bin/env bash

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $DIR

sudo bash "./install_dependencies.sh"

# Wait for server setup to finish and press Enter
echo "Wait here for server setup to finish... hit enter to continue"
read -r  # Wait for user input

sudo bash "./connect_sshfs_client.sh"

bash "./start_recorded_tmux.sh"