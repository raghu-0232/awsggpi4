#!/bin/bash
# Run YOLO detection manually with same config as systemd service

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from systemd config if it exists
if [ -f /etc/default/awsggpi4 ]; then
    # Use sudo to read the file if we don't have permission
    if [ -r /etc/default/awsggpi4 ]; then
        set -a
        # shellcheck disable=SC1091
        source /etc/default/awsggpi4
        set +a
        echo "Loaded environment from /etc/default/awsggpi4"
    else
        # Read with sudo and export variables (safer method)
        set -a
        while IFS='=' read -r key value; do
            # Skip comments, empty lines, and export lines
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ "$key" =~ ^export[[:space:]] ]] && continue
            [[ -z "$key" ]] && continue
            # Remove quotes if present
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            export "$key=$value"
        done < <(sudo cat /etc/default/awsggpi4)
        set +a
        echo "Loaded environment from /etc/default/awsggpi4 (via sudo)"
    fi
fi

# Determine Python executable
if [ -f "$SCRIPT_DIR/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/bin/python"
elif [ -f "$SCRIPT_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
else
    echo "ERROR: Virtual environment not found. Please run ./install.sh first."
    exit 1
fi

# Verify required packages are available
MISSING_PACKAGES=()
if ! "$PYTHON_BIN" -c "import cv2" 2>/dev/null; then MISSING_PACKAGES+=("cv2"); fi
if ! "$PYTHON_BIN" -c "import ultralytics" 2>/dev/null; then MISSING_PACKAGES+=("ultralytics"); fi
if ! "$PYTHON_BIN" -c "import flask" 2>/dev/null; then MISSING_PACKAGES+=("flask"); fi

# Check for libcamera (system package, needed for picamera2)
# Try venv Python first, then system Python
if ! "$PYTHON_BIN" -c "import libcamera" 2>/dev/null && ! python3 -c "import libcamera" 2>/dev/null; then
    echo "ERROR: libcamera module not found. This is a system package."
    echo "Please install it with: sudo apt install python3-libcamera"
    echo "If already installed, recreate venv with system packages:"
    echo "  rm -rf bin lib include pyvenv.cfg"
    echo "  python3 -m venv --system-site-packages ."
    echo "  ./install.sh"
    exit 1
fi

# Check picamera2 (can be installed via pip, but needs libcamera from system)
if ! "$PYTHON_BIN" -c "import picamera2" 2>/dev/null; then MISSING_PACKAGES+=("picamera2"); fi

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "Missing Python packages: ${MISSING_PACKAGES[*]}. Installing from requirements.txt..."
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        "$PYTHON_BIN" -m pip install -q -r "$SCRIPT_DIR/requirements.txt" || {
            echo "Failed to install packages. Please run ./install.sh"
            exit 1
        }
        echo "Packages installed successfully"
    else
        echo "ERROR: requirements.txt not found. Please run ./install.sh"
        exit 1
    fi
fi

# Run the application
exec "$PYTHON_BIN" "$SCRIPT_DIR/objectdetection.py"
