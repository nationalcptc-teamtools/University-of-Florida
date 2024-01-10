#!/bin/bash

pip3 install pipx
apt install xclip golang -y
pipx install git+https://github.com/Pennyw0rth/NetExec
pipx install git+https://github.com/Adamkadaban/NTLMCrack
go install github.com/BishopFox/cloudfox@latest


echo bashrc_addons >> ~/.bashrc
