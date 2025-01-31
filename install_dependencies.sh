#!/bin/bash

# Function to check if a command is installed
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package using apt (for Debian-based systems)
install_package() {
    if ! command_exists "$1"; then
        echo "Installing $1..."
        sudo apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Update package list
echo "Updating package list..."
sudo apt-get update

# Install required tools
install_package "bash"
install_package "nmap"
install_package "curl"
install_package "jq"
install_package "whois"
install_package "dnsutils"  # Provides 'dig'
install_package "parallel"

# Optional tools
if [[ "$1" == "--full" ]]; then
    echo "Installing optional tools..."
    install_package "openvas-cli"
    install_package "exploitdb"  # Provides 'searchsploit'
else
    echo "Skipping optional tools. Use '--full' to install them."
fi

# Verify installations
echo "Verifying installations..."
for tool in bash nmap curl jq whois dig parallel; do
    if command_exists "$tool"; then
        echo "$tool is installed and ready."
    else
        echo "Error: $tool could not be installed."
    fi
done

echo "All required tools have been installed successfully!"