#!/bin/bash


if [ "$(id -u)" != "0" ]; then
    echo "You must be root to run this script."
    exit 1
fi


# set default shell to bash
chsh --shell /bin/bash $(whoami)

echo "Installing dependencies"
# install things
apt install xclip golang bat wget curl unzip python3 python3-pip python3.11-venv docker.io docker-compose -y
pip3 install pipx

# Installing tools
pipx install git+https://github.com/Pennyw0rth/NetExec
pipx install git+https://github.com/Adamkadaban/NTLMCrack
pipx install git+https://github.com/ThePorgs/impacket # I don't like the kali impacket 
pipx ensurepath

# cloudfox
# go install github.com/BishopFox/cloudfox@latest
cloudfox_latest=$(curl -s -I https://github.com/bishopfox/cloudfox/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}')
wget -q "https://github.com/BishopFox/cloudfox/releases/download/$cloudfox_latest/cloudfox-linux-amd64.zip"
unzip cloudfox-linux-amd64.zip
mv cloudfox/cloudfox /usr/bin
rm -r cloudfox cloudfox-linux-amd64.zip

# Adding dotfiles
cat bashrc_addons >> ~/.bashrc
cat tmux_dot >> ~/.tmux.conf
