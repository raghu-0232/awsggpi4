#!/bin/bash
# Fix libcamera access issue by recreating venv with system-site-packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Fixing libcamera Access Issue"
echo "=========================================="
echo ""

# Check if python3-libcamera is installed
if ! python3 -c "import libcamera" 2>/dev/null; then
    echo "Installing python3-libcamera..."
    sudo apt install -y python3-libcamera
fi

# Stop service if running
if systemctl is-active --quiet awsggpi4 2>/dev/null; then
    echo "Stopping awsggpi4 service..."
    sudo systemctl stop awsggpi4
fi

# Backup current venv if it exists
if [ -d "bin" ] || [ -d "lib" ]; then
    echo "Backing up current virtual environment..."
    mv bin bin.backup 2>/dev/null || true
    mv lib lib.backup 2>/dev/null || true
    mv include include.backup 2>/dev/null || true
    mv pyvenv.cfg pyvenv.cfg.backup 2>/dev/null || true
fi

# Create new venv with system-site-packages
echo "Creating new virtual environment with system site packages access..."
python3 -m venv --system-site-packages .

# Upgrade pip and reinstall requirements using venv Python directly
echo "Upgrading pip..."
"$SCRIPT_DIR/bin/python" -m pip install --upgrade pip setuptools wheel

echo "Reinstalling Python packages..."
"$SCRIPT_DIR/bin/pip" install -r requirements.txt

# Verify libcamera is accessible
echo ""
echo "Verifying libcamera access..."
if "$SCRIPT_DIR/bin/python" -c "import libcamera" 2>/dev/null; then
    echo "✓ libcamera is now accessible!"
else
    echo "✗ libcamera still not accessible. Trying alternative fix..."
    # Try symlinking system libcamera (detect Python version dynamically)
    SYSTEM_LIBCAMERA=$(python3 -c "import libcamera, os; print(os.path.dirname(libcamera.__file__))" 2>/dev/null)
    PYVER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    if [ -n "$SYSTEM_LIBCAMERA" ] && [ -n "$PYVER" ]; then
        echo "Creating symlink to system libcamera..."
        SITEPKG="$SCRIPT_DIR/lib/python${PYVER}/site-packages"
        mkdir -p "$SITEPKG"
        ln -sf "$SYSTEM_LIBCAMERA" "$SITEPKG/libcamera"
        if "$SCRIPT_DIR/bin/python" -c "import libcamera" 2>/dev/null; then
            echo "✓ libcamera accessible via symlink!"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Fix Complete!"
echo "=========================================="
echo ""
echo "To test: ./run.sh"
echo "To start service: sudo systemctl start awsggpi4"
echo ""
