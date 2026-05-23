#!/usr/bin/env bash
set -e

# =============================================================================
# install.sh  —  CfxLua CLI Installer (Linux)
# =============================================================================

INSTALL_DIR="/usr/local/lib/cfxlua"
BIN_LINK="/usr/local/bin/cfxlua"

# Determine if we are in a release package or the source repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing CfxLua CLI..."

# 1. Create installation directory
sudo mkdir -p "$INSTALL_DIR/bin"
sudo mkdir -p "$INSTALL_DIR/runtime"
sudo mkdir -p "$INSTALL_DIR/vm/build"

# 2. Copy files
echo "Copying files to $INSTALL_DIR..."
sudo cp "$SCRIPT_DIR/bin/cfxlua" "$INSTALL_DIR/bin/"
sudo cp -r "$SCRIPT_DIR/runtime/"* "$INSTALL_DIR/runtime/"

# Find the VM binary
if [ -f "$SCRIPT_DIR/cfxlua-vm" ]; then
    # Release package mode
    sudo cp "$SCRIPT_DIR/cfxlua-vm" "$INSTALL_DIR/vm/build/"
elif [ -f "$SCRIPT_DIR/core/lua" ]; then
    # Source repo mode (after make)
    sudo cp "$SCRIPT_DIR/core/lua" "$INSTALL_DIR/vm/build/cfxlua-vm"
elif [ -f "$SCRIPT_DIR/build/lua" ]; then
    # Source repo mode (after make)
    sudo cp "$SCRIPT_DIR/build/lua" "$INSTALL_DIR/vm/build/cfxlua-vm"
fi

# 3. Create symlink
echo "Creating symlink in $BIN_LINK..."
sudo ln -sf "$INSTALL_DIR/bin/cfxlua" "$BIN_LINK"
sudo chmod +x "$BIN_LINK"

echo "-----------------------------------------------------------------------"
echo "Success! CfxLua CLI v1.1.0 installed."
echo "Usage: cfxlua <script.lua>"
echo "-----------------------------------------------------------------------"
