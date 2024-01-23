#!/bin/bash

pip3 install pipx
apt install xclip golang bat -y
pipx install git+https://github.com/Pennyw0rth/NetExec
pipx install git+https://github.com/Adamkadaban/NTLMCrack
pipx ensurepath

# cloudfox
# go install github.com/BishopFox/cloudfox@latest
cloudfox_latest=$(curl -s -I https://github.com/bishopfox/cloudfox/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}')
wget "https://github.com/BishopFox/cloudfox/releases/download/$cloudfox_latest/cloudfox-linux-amd64.zip"
unzip cloudfox-linux-amd64.zip
sudo mv cloudfox/cloudfox /usr/bin
rm -r cloudfox cloudfox-linux-amd64.zip

echo bashrc_addons >> ~/.bashrc
echo tmux_dot >> ~/.tmux.conf
