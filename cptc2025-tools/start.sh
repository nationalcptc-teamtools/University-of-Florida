#!/usr/bin/env bash

cd "${BASH_SOURCE[0]}"

chmod +x install_dependencies.sh
sudo ./install_dependencies.sh

chmod +x connect_sshfs_client.sh
sudo ./connect_sshfs_client.sh

chmod +x start_recorded_tmux.sh
./start_recorded_tmux.sh