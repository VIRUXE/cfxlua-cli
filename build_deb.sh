#!/usr/bin/env bash
set -e

VERSION="1.1.1"
PKG_DIR="debian/cfxlua-cli"

echo "Building Debian package v$VERSION..."

# 1. Build the VM
make -C core clean
make -C core linux-noreadline -j$(nproc)

# 2. Setup directory structure
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/usr/local/lib/cfxlua/bin"
mkdir -p "$PKG_DIR/usr/local/lib/cfxlua/runtime"
mkdir -p "$PKG_DIR/usr/local/lib/cfxlua/vm/build"
mkdir -p "$PKG_DIR/usr/local/bin"
    mkdir -p "$PKG_DIR/DEBIAN"
    cp debian/source/control "$PKG_DIR/DEBIAN/"

# 3. Copy files to the staging directory
cp bin/cfxlua "$PKG_DIR/usr/local/lib/cfxlua/bin/"
cp -r runtime/* "$PKG_DIR/usr/local/lib/cfxlua/runtime/"
cp core/lua "$PKG_DIR/usr/local/lib/cfxlua/vm/build/cfxlua-vm"

# 4. Create the symlink inside the package
ln -sf /usr/local/lib/cfxlua/bin/cfxlua "$PKG_DIR/usr/local/bin/cfxlua"

# 5. Set permissions
chmod -R 755 "$PKG_DIR"
chmod 755 "$PKG_DIR/DEBIAN/control"

# 6. Build the package
dpkg-deb --build "$PKG_DIR" cfxlua-cli-linux-amd64.deb

echo "-----------------------------------------------------------------------"
echo "Debian package generated: cfxlua-cli-linux-amd64.deb"
echo "-----------------------------------------------------------------------"
