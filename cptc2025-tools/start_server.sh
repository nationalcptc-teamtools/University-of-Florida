#!/usr/bin/env bash

cd "${dirname BASH_SOURCE[0]}"

chmod +x install_dependencies.sh
sudo ./install_dependencies.sh

chmod +x setup_sshfs_server.sh
sudo ./setup_sshfs_server.sh

chmod +x start_recorded_tmux.sh
./start_recorded_tmux.sh