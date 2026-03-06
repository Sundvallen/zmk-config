#!/usr/bin/env bash
# Build corne_choc_pro firmware from WSL.
# Run from WSL: bash /mnt/c/Users/sande/Documents/Programming/keeb/keebart-config/scripts/wsl-build.sh [left|right|both]
set -e

KEEBART="/mnt/c/Users/sande/Documents/Programming/keeb/keebart-config"
CONFIG="$KEEBART/config"
# Separate workspace created by wsl-setup.sh
WORKSPACE="$HOME/zmk-workspace"
OUTPUT="$KEEBART/firmware"

# Activate the zmk venv (contains west)
# shellcheck disable=SC1091
source "$HOME/.zmk-venv/bin/activate"

# nanopb's protoc script uses #!/usr/bin/env python3 (system python) which on
# Ubuntu 24.04 lacks pkg_resources/setuptools.  Inject the venv's site-packages
# into PYTHONPATH so any subprocess can import them regardless of shebang.
VENV_SITE="$(python3 -c 'import site; print(site.getsitepackages()[0])')"
export PYTHONPATH="${VENV_SITE}${PYTHONPATH:+:$PYTHONPATH}"

TARGET="${1:-both}"

build_side() {
    local SIDE="$1"     # left or right
    local BOARD="corne_choc_pro_${SIDE}"
    local BUILD_DIR="$WORKSPACE/build/corne_${SIDE}"

    echo ""
    echo "==> Building $BOARD..."
    cd "$WORKSPACE"

    west build \
        -s zmk/app \
        -b "$BOARD" \
        -d "$BUILD_DIR" \
        --pristine \
        -S studio-rpc-usb-uart \
        -- \
        -DBOARD_ROOT="$KEEBART" \
        -DSHIELD=nice_view \
        -DZMK_CONFIG="$CONFIG" \
        ${SIDE:+$( [ "$SIDE" = "left" ] && echo "-DCONFIG_ZMK_STUDIO=y" )}

    mkdir -p "$OUTPUT"
    cp "$BUILD_DIR/zephyr/zmk.uf2" "$OUTPUT/corne_${SIDE}.uf2"
    echo "==> Firmware: $OUTPUT/corne_${SIDE}.uf2"
}

build_reset() {
    local SIDE="$1"
    local BOARD="corne_choc_pro_${SIDE}"
    local BUILD_DIR="$WORKSPACE/build/corne_${SIDE}_reset"

    echo ""
    echo "==> Building settings_reset for $BOARD..."
    cd "$WORKSPACE"

    west build \
        -s zmk/app \
        -b "$BOARD" \
        -d "$BUILD_DIR" \
        --pristine \
        -S studio-rpc-usb-uart \
        -- \
        -DBOARD_ROOT="$KEEBART" \
        -DSHIELD=settings_reset \
        -DZMK_CONFIG="$CONFIG"

    mkdir -p "$OUTPUT"
    cp "$BUILD_DIR/zephyr/zmk.uf2" "$OUTPUT/corne_${SIDE}_reset.uf2"
    echo "==> Reset firmware: $OUTPUT/corne_${SIDE}_reset.uf2"
}

case "$TARGET" in
    left)   build_side left ;;
    right)  build_side right ;;
    reset)  build_reset left; build_reset right ;;
    both)   build_side left; build_side right ;;
    *)
        echo "Usage: $0 [left|right|both|reset]"
        exit 1
        ;;
esac

echo ""
echo "==> Done. Firmware files in $OUTPUT/"
