#!/bin/bash
# XMRig installer for Aime mining
# Builds XMRig from source for current platform.
set -euo pipefail

XMRIG_VERSION="6.22.0"  # Update as needed
INSTALL_DIR="${XMRIG_DIR:-$HOME/xmrig-aime}"

echo "Installing XMRig for Aime mining..."
echo "Target directory: $INSTALL_DIR"

# Detect OS
if [ -f /etc/debian_version ]; then
    PKG="apt-get"
elif [ -f /etc/fedora-release ]; then
    PKG="dnf"
else
    echo "Unsupported OS. Manual install required."
    exit 1
fi

# Install build deps
case "$PKG" in
    apt-get)
        sudo apt-get update
        sudo apt-get install -y --no-install-recommends \
            git build-essential cmake automake libtool autoconf libhwloc-dev \
            libssl-dev libuv1-dev
        ;;
    dnf)
        sudo dnf install -y \
            git gcc-c++ make cmake automake libtool autoconf hwloc-devel \
            openssl-devel libuv-devel
        ;;
esac

# Clone & build XMRig
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -d xmrig ]; then
    git clone --depth=1 --branch=v$XMRIG_VERSION https://github.com/xmrig/xmrig.git
fi

cd xmrig
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# Verify
if [ ! -x ./xmrig ]; then
    echo "Build failed."
    exit 1
fi

# Install to ~/.local/bin
mkdir -p "$HOME/.local/bin"
cp ./xmrig "$HOME/.local/bin/aime-xmrig"
chmod +x "$HOME/.local/bin/aime-xmrig"

echo ""
echo "✓ Installed: $HOME/.local/bin/aime-xmrig"
echo ""
echo "Add to PATH if not already:"
echo "  export PATH=\$HOME/.local/bin:\$PATH"
echo ""
echo "Test:"
echo "  aime-xmrig --version"
echo ""
echo "Use the aime-mine.sh wrapper to start mining."
