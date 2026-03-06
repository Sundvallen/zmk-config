#!/usr/bin/env bash
# One-time ZMK toolchain setup for WSL Ubuntu.
# Run from WSL: bash /mnt/c/Users/sande/Documents/Programming/keeb/keebart-config/scripts/wsl-setup.sh
set -e

ZEPHYR_SDK_VERSION="0.16.8"
ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz"
KEEBART_CONFIG="/mnt/c/Users/sande/Documents/Programming/keeb/keebart-config"
# Separate workspace keeps zmk/, zephyr/ etc. out of the repo
# (keebart-config/zephyr/module.yml would collide if workspace were inside the repo)
WORKSPACE="$HOME/zmk-workspace"

echo "==> Installing system packages..."
sudo apt-get update -q
sudo apt-get install -y \
  git cmake ninja-build gperf ccache dfu-util device-tree-compiler wget xz-utils file make \
  gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 \
  python3-dev python3-pip python3-setuptools python3-pkg-resources python3-tk python3-wheel python3-venv python3-full

# Create a persistent venv for west + zephyr tooling (avoids PEP 668 externally-managed error)
VENV="$HOME/.zmk-venv"
if [ ! -d "$VENV" ]; then
  echo "==> Creating Python venv at $VENV..."
  python3 -m venv "$VENV"
fi
# Activate for the rest of this script
# shellcheck disable=SC1091
source "$VENV/bin/activate"

# Keep venv active in future shells
if ! grep -q '.zmk-venv' ~/.bashrc; then
  echo 'source "$HOME/.zmk-venv/bin/activate"' >> ~/.bashrc
fi

echo "==> Installing west into venv..."
pip install west setuptools

echo "==> Initialising ZMK west workspace at $WORKSPACE..."
# west init -l resolves symlinks and would anchor .west/ on the Windows path.
# Instead, manually write .west/config so the workspace root stays at $WORKSPACE,
# then symlink config -> keebart-config/config so west update can read west.yml.
mkdir -p "$WORKSPACE"
if [ ! -L "$WORKSPACE/config" ]; then
    ln -sf "$KEEBART_CONFIG/config" "$WORKSPACE/config"
fi
if [ ! -f "$WORKSPACE/.west/config" ]; then
    mkdir -p "$WORKSPACE/.west"
    cat > "$WORKSPACE/.west/config" << 'EOF'
[manifest]
path = config
file = west.yml
EOF
    echo "   (west workspace bootstrapped)"
else
    echo "   (west already initialised, skipping)"
fi
cd "$WORKSPACE"
west update
west zephyr-export

# nanopb's protoc script uses '#!/usr/bin/env python3' (system python) which on
# Ubuntu 24.04 lacks pkg_resources.  Repoint it at the venv python that has
# setuptools so it finds pkg_resources without touching system packages.
echo "==> Patching nanopb protoc shebang to use venv python..."
NANOPB_PROTOC="$WORKSPACE/modules/lib/nanopb/generator/protoc"
if [ -f "$NANOPB_PROTOC" ]; then
    sed -i "1s|.*|#!${VENV}/bin/python3|" "$NANOPB_PROTOC"
    echo "   patched $NANOPB_PROTOC"
fi

echo "==> Installing Python requirements..."
pip install -r "$WORKSPACE/zephyr/scripts/requirements.txt"

echo "==> Downloading Zephyr SDK ${ZEPHYR_SDK_VERSION}..."
SDK_ARCHIVE="$HOME/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz"
if [ ! -f "$SDK_ARCHIVE" ]; then
  wget -O "$SDK_ARCHIVE" "$ZEPHYR_SDK_URL"
fi

echo "==> Extracting & registering SDK..."
cd "$HOME"
tar xf "$SDK_ARCHIVE"
cd "zephyr-sdk-${ZEPHYR_SDK_VERSION}"
./setup.sh -t arm-zephyr-eabi -h -c

echo ""
echo "==> Setup complete!"
echo "   Workspace: $WORKSPACE"
echo "   Run: bash /mnt/c/Users/sande/Documents/Programming/keeb/keebart-config/scripts/wsl-build.sh"
