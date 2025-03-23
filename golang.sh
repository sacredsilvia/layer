#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash install_golang.sh"
    exit 1
fi

set -e  # Exit on any error

echo "Removing old Go version..."
sudo apt remove -y golang-go || echo "No existing Go installation found, continuing..."

cd ~
echo "Downloading Go..."
curl -OL https://go.dev/dl/go1.23.1.linux-amd64.tar.gz || { echo "Failed to download Go"; exit 1; }

echo "Extracting Go..."
sudo tar -C /usr/local -xvf go1.23.1.linux-amd64.tar.gz || { echo "Failed to extract Go"; exit 1; }

rm go1.23.1.linux-amd64.tar.gz

echo "Updating PATH..."
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
source ~/.profile

echo "Verifying Go installation..."
go version || { echo "Go installation verification failed"; exit 1; }

echo "Go installation completed successfully!"
