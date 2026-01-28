#!/usr/bin/env bash
# Simple installer for Raspberry Pi 4 (Debian / Raspberry Pi OS)
# Usage:
#   chmod +x install.sh
#   ./install.sh
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON_BIN=python3

echo "=========================================="
echo "YOLO Object Detection - Installation"
echo "=========================================="
echo ""

echo "Step 1: Updating apt and installing system dependencies..."
sudo apt update

# Install core dependencies (required)
echo "Installing core dependencies..."
sudo apt install -y python3-pip python3-venv build-essential \
    libglib2.0-0 libsm6 libxrender1 libxext6 \
    libjpeg-dev libpng-dev git python3-picamera2 python3-libcamera libcap-dev

# Install OpenGL libraries (optional, for OpenCV GUI features)
# On newer Debian/Raspberry Pi OS, libgl1-mesa-glx is replaced with libgl1
echo "Installing OpenGL libraries (optional)..."
if apt-cache show libgl1 >/dev/null 2>&1; then
    sudo apt install -y libgl1 || echo "Note: libgl1 installation skipped (not critical for headless operation)"
elif apt-cache show libgl1-mesa-glx >/dev/null 2>&1; then
    sudo apt install -y libgl1-mesa-glx || echo "Note: libgl1-mesa-glx installation skipped"
else
    echo "Note: OpenGL packages not available (not critical for headless operation)"
fi

# Create virtualenv in project directory (like YOLO setup)
# Use --system-site-packages to allow access to system packages like libcamera
echo ""
echo "Step 2: Creating virtualenv in project directory..."
if [ -d "bin" ] || [ -d "lib" ]; then
    echo "Virtual environment already exists. Skipping creation."
    echo "Note: If libcamera issues occur, recreate venv with: rm -rf bin lib include pyvenv.cfg && python3 -m venv --system-site-packages ."
else
    $PYTHON_BIN -m venv --system-site-packages .
    echo "Virtual environment created successfully (with system site packages access)."
fi

echo ""
echo "Step 3: Upgrading pip..."
PYTHON_BIN="$SCRIPT_DIR/bin/python"
PIP_BIN="$SCRIPT_DIR/bin/pip"
if [ ! -f "$PYTHON_BIN" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
    PIP_BIN="$SCRIPT_DIR/.venv/bin/pip"
fi
if [ ! -f "$PYTHON_BIN" ]; then
    echo "ERROR: Virtual environment Python not found (bin/python or .venv/bin/python)."
    exit 1
fi
"$PYTHON_BIN" -m pip install --upgrade pip setuptools wheel

# Install python requirements
echo ""
echo "Step 4: Installing Python requirements from requirements.txt..."
if [ -f requirements.txt ]; then
  "$PIP_BIN" install -r requirements.txt
else
  echo "ERROR: requirements.txt not found. Please ensure it exists."
  exit 1
fi

# Create default environment file if it doesn't exist
echo ""
echo "Step 5: Setting up environment configuration..."
if [ ! -f /etc/default/awsggpi4 ]; then
    echo "Creating /etc/default/awsggpi4 from template..."
    sudo cp "$SCRIPT_DIR/awsggpi4.env.example" /etc/default/awsggpi4
    sudo chmod 644 /etc/default/awsggpi4
    # Expand ~ to actual home directory in the config file
    USER_HOME=$(eval echo ~$(whoami))
    sudo sed -i "s|~/|$USER_HOME/|g" /etc/default/awsggpi4
    echo "Environment file created with paths for user: $(whoami)"
    echo "Edit it with: sudo nano /etc/default/awsggpi4"
else
    echo "Environment file already exists at /etc/default/awsggpi4"
fi

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  Single-shot setup: ./setup-auto.sh --install-service --start-service"
echo "  Or run manually: ./run.sh"
echo "  Or install service: ./install-service.sh && sudo systemctl enable --now awsggpi4"
echo "  Edit config: sudo nano /etc/default/awsggpi4"
echo ""
