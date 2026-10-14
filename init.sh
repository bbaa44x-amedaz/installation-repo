#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure script is run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo."
  exit 1
fi

echo "Updating package lists..."
apt-get update && apt-get upgrade -y

echo "Installing prerequisites..."
apt-get install -y curl wget apt-transport-https software-properties-common lsb-release gnupg

# 1. Git
echo "Installing latest Git..."
apt-get install -y git

# 2. Firefox
if ! command -v firefox &> /dev/null; then
    echo "Installing Firefox..."
    add-apt-repository -y ppa:mozillateam/ppa
    apt-get update
    apt-get install -y firefox
else
    echo "Firefox is already installed. Skipping..."
fi

# 3. DBeaver Community (Always downloads the latest release binary)
echo "Installing latest DBeaver Community..."
wget -O /tmp/dbeaver-ce_amd64.deb https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
apt-get install -y /tmp/dbeaver-ce_amd64.deb
rm /tmp/dbeaver-ce_amd64.deb

# 4. Go (Dynamically fetches the latest stable version)
echo "Fetching the latest Go version..."
LATEST_GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
if [ -z "$LATEST_GO_VERSION" ]; then
    echo "Failed to fetch latest Go version. Falling back to go1.23.4"
    LATEST_GO_VERSION="go1.23.4"
fi
echo "Installing Go version: $LATEST_GO_VERSION"

wget -O /tmp/go.tar.gz "https://golang.org/dl/${LATEST_GO_VERSION}.linux-amd64.tar.gz"
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

if ! grep -q "/usr/local/go/bin" /etc/profile; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
fi

# 5. VS Code (Always downloads the latest stable build)
echo "Installing latest Visual Studio Code..."
wget -qO /tmp/vscode.deb https://update.code.visualstudio.com/latest/linux-deb-x64/stable
apt-get install -y /tmp/vscode.deb
rm /tmp/vscode.deb

# 6. pnpm (Installs Node.js LTS and the absolute latest pnpm via corepack)
echo "Installing Node.js and the latest pnpm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
corepack enable
corepack prepare pnpm@latest --activate

# 7. Docker & Docker Compose (Installs from Docker's official latest repository)
echo "Installing latest Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "Added $SUDO_USER to the docker group."
fi

# 8. PostgreSQL (Installs from the official PostgreSQL Global Development Group repo)
echo "Installing latest PostgreSQL..."
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

apt-get update
apt-get install -y postgresql postgresql-contrib

echo "All latest tools installed successfully!"
echo "Please restart your terminal or run 'source /etc/profile' to load Go into your PATH."
