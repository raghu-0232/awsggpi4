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
sudo apt install -y python3-pip python3-venv build-essential \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 \
    libjpeg-dev libpng-dev git

# Create virtualenv in project directory (like YOLO setup)
echo ""
echo "Step 2: Creating virtualenv in project directory..."
if [ -d "bin" ] || [ -d "lib" ]; then
    echo "Virtual environment already exists. Skipping creation."
else
    $PYTHON_BIN -m venv .
    echo "Virtual environment created successfully."
fi

echo ""
echo "Step 3: Upgrading pip..."
# shellcheck disable=SC1091
source bin/activate || source .venv/bin/activate 2>/dev/null || true
python -m pip install --upgrade pip setuptools wheel

# Install python requirements
echo ""
echo "Step 4: Installing Python requirements from requirements.txt..."
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
else
  echo "ERROR: requirements.txt not found. Please ensure it exists."
  exit 1
fi

echo ""
echo "=========================================="
echo "Installation completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Download YOLO model weights (e.g., yolov8n.pt) and place it in a known location"
echo "2. Configure environment variables (see README.md or create /etc/default/awsggpi4)"
echo "3. Run manually: ./run.sh"
echo "4. Or set up systemd service: sudo cp awsggpi4.service /etc/systemd/system/"
echo "   Then: sudo systemctl enable awsggpi4 && sudo systemctl start awsggpi4"
echo ""