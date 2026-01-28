#!/bin/bash
# Run YOLO detection manually with same config as systemd service

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from systemd config if it exists
if [ -f /etc/default/awsggpi4 ]; then
    set -a
    source /etc/default/awsggpi4
    set +a
    echo "Loaded environment from /etc/default/awsggpi4"
fi

# Use the virtual environment Python (same as systemd)
if [ -f "$SCRIPT_DIR/bin/python" ]; then
    exec "$SCRIPT_DIR/bin/python" "$SCRIPT_DIR/objectdetection.py"
elif [ -f "$SCRIPT_DIR/.venv/bin/python" ]; then
    exec "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/objectdetection.py"
else
    echo "ERROR: Virtual environment not found. Please run ./install.sh first."
    exit 1
fi
