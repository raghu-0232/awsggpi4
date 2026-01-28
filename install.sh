#!/usr/bin/env bash
# Simple installer for Raspberry Pi 4 (Debian / Raspberry Pi OS)
# Usage:
#   chmod +x install.sh
#   ./install.sh
set -e

PYTHON_BIN=python3

echo "Updating apt and installing system dependencies..."
sudo apt update
sudo apt install -y python3-pip python3-venv build-essential \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 \
    libjpeg-dev libpng-dev

# Create virtualenv
echo "Creating virtualenv in .venv ..."
$PYTHON_BIN -m venv .venv
echo "Activating virtualenv and upgrading pip..."
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip setuptools wheel

# Install python requirements
if [ -f requirements.txt ]; then
  echo "Installing Python requirements from requirements.txt..."
  pip install -r requirements.txt
else
  echo "requirements.txt not found. Please ensure it exists."
  exit 1
fi

echo "Installation finished."
echo "To activate the environment: source .venv/bin/activate"
echo "Then run the app: python objectdetection.py"