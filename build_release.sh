#!/usr/bin/env bash
set -e

VERSION="1.1.1"
DIST_DIR="dist"
LINUX_PKG="cfxlua-cli-linux.tar.gz"
WIN_PKG="cfxlua-cli-windows.zip"

echo "Building CfxLua CLI v$VERSION Release..."

# 1. Clean and Prepare
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/linux" "$DIST_DIR/windows/bin" "$DIST_DIR/windows/runtime" "$DIST_DIR/windows"

# 2. Build Linux VM
echo "Building Linux VM..."
make -C core clean
make -C core linux-noreadline -j$(nproc)
cp core/lua "$DIST_DIR/linux/cfxlua-vm"

# 3. Build Windows VM (Cross-compile)
if command -v x86_64-w64-mingw32-g++ &> /dev/null; then
    echo "Building Windows VM (Cross-compiling)..."
    make -C core clean
    make -C core CC="x86_64-w64-mingw32-g++ -std=c++11" CPP="x86_64-w64-mingw32-g++ -std=c++11" PLAT=mingw -j$(nproc)
    cp core/lua.exe "$DIST_DIR/windows/cfxlua-vm.exe"
    cp core/lua54.dll "$DIST_DIR/windows/"
else
    echo "WARNING: x86_64-w64-mingw32-g++ not found. Skipping Windows build."
fi

# 4. Package Linux
echo "Packaging Linux..."
cp -r bin runtime install.sh "$DIST_DIR/linux/"
tar -czvf "$LINUX_PKG" -C "$DIST_DIR/linux" .

# 5. Package Windows
if [ -f "$DIST_DIR/windows/cfxlua-vm.exe" ]; then
    echo "Packaging Windows..."
    cp -r bin/cfxlua.bat "$DIST_DIR/windows/bin/"
    cp -r runtime/* "$DIST_DIR/windows/runtime/"
    cp install.bat "$DIST_DIR/windows/"
    
    cd "$DIST_DIR/windows"
    zip -r "../../$WIN_PKG" .
    cd ../..
fi

echo "-----------------------------------------------------------------------"
echo "Release build complete!"
echo "Assets generated:"
[ -f "$LINUX_PKG" ] && echo "  - $LINUX_PKG"
[ -f "$WIN_PKG" ] && echo "  - $WIN_PKG"
echo "-----------------------------------------------------------------------"
