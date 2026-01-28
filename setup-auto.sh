#!/bin/bash
# Fully automated non-interactive setup script for awsggpi4
# Usage: ./setup-auto.sh [--install-service] [--start-service]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INSTALL_SERVICE=false
START_SERVICE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --install-service)
            INSTALL_SERVICE=true
            shift
            ;;
        --start-service)
            INSTALL_SERVICE=true
            START_SERVICE=true
            shift
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--install-service] [--start-service]"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "awsggpi4 - Automated Setup (Non-Interactive)"
echo "=========================================="
echo ""

# Step 1: Run installer
echo "[1/6] Running installer..."
./install.sh

# Step 1.5: Fix libcamera access if needed
echo ""
echo "[2/6] Verifying libcamera access..."
PYTHON_BIN=""
if [ -f "$SCRIPT_DIR/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/bin/python"
elif [ -f "$SCRIPT_DIR/.venv/bin/python" ]; then
    PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python"
fi

if [ -n "$PYTHON_BIN" ]; then
    if ! "$PYTHON_BIN" -c "import libcamera" 2>/dev/null; then
        echo "libcamera not accessible in venv. Fixing..."
        
        # Ensure python3-libcamera is installed
        if ! python3 -c "import libcamera" 2>/dev/null; then
            echo "Installing python3-libcamera..."
            sudo apt install -y python3-libcamera
        fi
        
        # Check if venv was created with --system-site-packages
        if [ -f "$SCRIPT_DIR/pyvenv.cfg" ] && ! grep -q "include-system-site-packages = true" "$SCRIPT_DIR/pyvenv.cfg"; then
            echo "Recreating virtual environment with system-site-packages..."
            # Stop service if running
            if systemctl is-active --quiet awsggpi4 2>/dev/null; then
                sudo systemctl stop awsggpi4 2>/dev/null || true
            fi
            
            # Backup and recreate
            if [ -d "$SCRIPT_DIR/bin" ]; then
                mv "$SCRIPT_DIR/bin" "$SCRIPT_DIR/bin.backup" 2>/dev/null || true
                mv "$SCRIPT_DIR/lib" "$SCRIPT_DIR/lib.backup" 2>/dev/null || true
                mv "$SCRIPT_DIR/include" "$SCRIPT_DIR/include.backup" 2>/dev/null || true
                mv "$SCRIPT_DIR/pyvenv.cfg" "$SCRIPT_DIR/pyvenv.cfg.backup" 2>/dev/null || true
            fi
            
            python3 -m venv --system-site-packages "$SCRIPT_DIR"
            
            # Reinstall packages
            echo "Reinstalling Python packages..."
            "$SCRIPT_DIR/bin/python" -m pip install --upgrade pip setuptools wheel --quiet
            "$SCRIPT_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
            
            # Update PYTHON_BIN
            PYTHON_BIN="$SCRIPT_DIR/bin/python"
        fi
        
        # Verify fix worked
        if "$PYTHON_BIN" -c "import libcamera" 2>/dev/null; then
            echo "✓ libcamera is now accessible"
        else
            echo "Warning: libcamera still not accessible, but continuing..."
        fi
    else
        echo "✓ libcamera is accessible"
    fi
fi

# Step 2: Check/download model
echo ""
echo "[3/6] Checking for YOLO model..."
MODEL_DIR="${HOME}/models"
DEFAULT_MODEL="${MODEL_DIR}/yolov8n.pt"

if [ ! -f "$DEFAULT_MODEL" ]; then
    echo "Model not found. Attempting to download..."
    mkdir -p "$MODEL_DIR"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.pt" -O "$DEFAULT_MODEL" 2>&1 || {
            echo "Warning: Download failed. Please download manually to: $DEFAULT_MODEL"
            DEFAULT_MODEL=""
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -s "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.pt" -o "$DEFAULT_MODEL" 2>&1 || {
            echo "Warning: Download failed. Please download manually to: $DEFAULT_MODEL"
            DEFAULT_MODEL=""
        }
    else
        echo "Warning: wget/curl not found. Please download yolov8n.pt manually to: $DEFAULT_MODEL"
        DEFAULT_MODEL=""
    fi
fi

# Step 3: Update environment file
echo ""
echo "[4/6] Configuring environment..."
if [ -f "$DEFAULT_MODEL" ]; then
    if [ -f /etc/default/awsggpi4 ] && grep -q "YOLO_MODEL_PATH=" /etc/default/awsggpi4 2>/dev/null; then
        # Expand ~ to full path for sed
        DEFAULT_MODEL_EXPANDED=$(echo "$DEFAULT_MODEL" | sed "s|~|$HOME|g")
        sudo sed -i "s|^YOLO_MODEL_PATH=.*|YOLO_MODEL_PATH=$DEFAULT_MODEL_EXPANDED|" /etc/default/awsggpi4
        echo "Updated YOLO_MODEL_PATH to $DEFAULT_MODEL_EXPANDED"
    elif [ -f /etc/default/awsggpi4 ]; then
        # Add YOLO_MODEL_PATH if not present
        echo "YOLO_MODEL_PATH=$DEFAULT_MODEL" | sudo tee -a /etc/default/awsggpi4 > /dev/null
        echo "Added YOLO_MODEL_PATH to config"
    fi
fi

# Ensure ROI config exists
if [ ! -f "$SCRIPT_DIR/roi_config.json" ] && [ -f "$SCRIPT_DIR/roi_config.json.example" ]; then
    cp "$SCRIPT_DIR/roi_config.json.example" "$SCRIPT_DIR/roi_config.json"
    echo "Created roi_config.json from example"
fi

# Update ROI_CONFIG_PATH and HOURLY_CSV_PATH to project dir (works for any clone location)
if [ -f /etc/default/awsggpi4 ]; then
    for key in ROI_CONFIG_PATH HOURLY_CSV_PATH; do
        case "$key" in
            ROI_CONFIG_PATH) val="$SCRIPT_DIR/roi_config.json" ;;
            HOURLY_CSV_PATH) val="$SCRIPT_DIR/detections.csv" ;;
        esac
        if grep -q "^$key=" /etc/default/awsggpi4 2>/dev/null; then
            sudo sed -i "s|^$key=.*|$key=$val|" /etc/default/awsggpi4
        else
            echo "$key=$val" | sudo tee -a /etc/default/awsggpi4 > /dev/null
        fi
    done
fi

# Step 4: Verify setup
echo ""
echo "[5/6] Verifying setup..."
if [ -f "$SCRIPT_DIR/verify_setup.sh" ]; then
    if ./verify_setup.sh >/dev/null 2>&1; then
        echo "Setup verification passed"
    else
        echo "Warning: Some verification checks failed, but continuing..."
    fi
fi

# Step 5: Install/start service if requested
if [ "$INSTALL_SERVICE" = true ]; then
    echo ""
    echo "[6/6] Setting up systemd service..."
    if [ -f "$SCRIPT_DIR/install-service.sh" ]; then
        "$SCRIPT_DIR/install-service.sh"
    else
        # Fallback: create service file dynamically
        CURRENT_USER=$(whoami)
        SERVICE_FILE="/tmp/awsggpi4.service.$$"
        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=YOLO Object Detection Stream (awsggpi4)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$SCRIPT_DIR
EnvironmentFile=-/etc/default/awsggpi4
ExecStart=${PYTHON_BIN:-$SCRIPT_DIR/bin/python} $SCRIPT_DIR/objectdetection.py
Restart=on-failure
RestartSec=3
StandardOutput=append:$SCRIPT_DIR/awsggpi4.log
StandardError=append:$SCRIPT_DIR/awsggpi4-error.log

[Install]
WantedBy=multi-user.target
EOF
        sudo cp "$SERVICE_FILE" /etc/systemd/system/awsggpi4.service
        rm "$SERVICE_FILE"
        sudo systemctl daemon-reload
    fi
    sudo systemctl enable awsggpi4
    
    if [ "$START_SERVICE" = true ]; then
        echo "Starting service..."
        sudo systemctl start awsggpi4
        sleep 2
        if sudo systemctl is-active --quiet awsggpi4; then
            echo "Service started successfully"
        else
            echo "Warning: Service may have failed to start. Check: sudo systemctl status awsggpi4"
        fi
    else
        echo "Service installed and enabled. Start with: sudo systemctl start awsggpi4"
    fi
else
    echo ""
    echo "[6/6] Skipping systemd service setup"
    echo "To install service later: sudo cp awsggpi4.service /etc/systemd/system/ && sudo systemctl enable awsggpi4"
fi

# Step 6: Final verification
echo ""
echo "Final verification..."
if [ -n "$PYTHON_BIN" ] && "$PYTHON_BIN" -c "import cv2, ultralytics, flask, picamera2, libcamera" 2>/dev/null; then
    echo "✓ All required packages are accessible"
else
    echo "Warning: Some packages may not be accessible. Check manually with: ./run.sh"
fi

echo ""
echo "=========================================="
echo "Automated Setup Complete!"
echo "=========================================="
echo ""
echo "Configuration file: /etc/default/awsggpi4"
echo "Edit it with: sudo nano /etc/default/awsggpi4"
echo ""
echo "To run manually: ./run.sh"
echo "To check service status: sudo systemctl status awsggpi4"
echo ""
