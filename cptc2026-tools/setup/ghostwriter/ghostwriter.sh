#!/bin/bash

BACKUP_FILE="$(pwd)/start.sql.gz"

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exec sudo "$0" "$@"
fi

# rest of script here
echo "Running as root..."

apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker --now

cd ~
rm "v6.0.4.zip" # in case it exists
wget https://github.com/GhostManager/Ghostwriter/archive/refs/tags/v6.0.4.zip
unzip "v6.0.4.zip"
rm "v6.0.4.zip"
cd Ghostwriter-6.0.4

./ghostwriter-cli-linux install
docker cp $BACKUP_FILE ghostwriter-604-postgres-1:/backups
yes | ./ghostwriter-cli-linux restore start.sql.gz
./ghostwriter-cli-linux config allowhost "*"
./ghostwriter-cli-linux up
