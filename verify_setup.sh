#!/bin/bash
# Verification script to check if awsggpi4 is set up correctly

echo "=========================================="
echo "awsggpi4 Setup Verification"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Virtual environment
echo "[1/8] Checking virtual environment..."
if [ -d "bin" ] && [ -f "bin/python" ]; then
    echo "  ✓ Virtual environment found"
elif [ -d ".venv" ] && [ -f ".venv/bin/python" ]; then
    echo "  ✓ Virtual environment found (.venv)"
else
    echo "  ✗ Virtual environment not found. Run ./install.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: Python packages
echo ""
echo "[2/8] Checking Python packages..."
if [ -f "bin/python" ]; then
    PYTHON_BIN="bin/python"
elif [ -f ".venv/bin/python" ]; then
    PYTHON_BIN=".venv/bin/python"
else
    PYTHON_BIN="python3"
fi

if $PYTHON_BIN -c "import ultralytics, cv2, flask" 2>/dev/null; then
    echo "  ✓ Required Python packages installed"
else
    echo "  ✗ Missing Python packages. Run ./install.sh"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Environment config
echo ""
echo "[3/8] Checking environment configuration..."
if [ -f "/etc/default/awsggpi4" ]; then
    echo "  ✓ Environment config found at /etc/default/awsggpi4"
    source /etc/default/awsggpi4 2>/dev/null
else
    echo "  ⚠ Environment config not found. Copy awsggpi4.env.example to /etc/default/awsggpi4"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 4: Model file
echo ""
echo "[4/8] Checking YOLO model file..."
MODEL_PATH="${YOLO_MODEL_PATH:-/home/pi4/screenshots/yolov8n.pt}"
if [ -f "$MODEL_PATH" ]; then
    echo "  ✓ Model file found: $MODEL_PATH"
else
    echo "  ⚠ Model file not found: $MODEL_PATH"
    echo "     Set YOLO_MODEL_PATH in /etc/default/awsggpi4"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 5: ROI config
echo ""
echo "[5/8] Checking ROI configuration..."
ROI_CONFIG="${ROI_CONFIG_PATH:-roi_config.json}"
if [ -f "$ROI_CONFIG" ]; then
    echo "  ✓ ROI config found: $ROI_CONFIG"
elif [ -f "roi_config.json.example" ]; then
    echo "  ⚠ ROI config not found. Copy roi_config.json.example to roi_config.json"
    WARNINGS=$((WARNINGS + 1))
else
    echo "  ⚠ ROI config not found. Using environment variables ROI1/ROI2"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 6: Systemd service
echo ""
echo "[6/8] Checking systemd service..."
if systemctl list-unit-files | grep -q awsggpi4.service; then
    echo "  ✓ Systemd service installed"
    if systemctl is-active --quiet awsggpi4; then
        echo "  ✓ Service is running"
    else
        echo "  ⚠ Service is installed but not running"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ⚠ Systemd service not installed (optional)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check 7: Port availability
echo ""
echo "[7/8] Checking port availability..."
PORT="${STREAM_PORT:-9090}"
if netstat -tln 2>/dev/null | grep -q ":$PORT "; then
    echo "  ⚠ Port $PORT is already in use"
    WARNINGS=$((WARNINGS + 1))
else
    echo "  ✓ Port $PORT is available"
fi

# Check 8: Camera/RTSP
echo ""
echo "[8/8] Checking camera configuration..."
if [ "${USE_PICAMERA:-0}" = "1" ]; then
    echo "  ✓ Configured to use Pi Camera"
    if command -v libcamera-hello >/dev/null 2>&1; then
        echo "  ✓ libcamera tools available"
    else
        echo "  ⚠ libcamera tools not found (may need: sudo apt install libcamera-apps)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ✓ Configured to use RTSP stream"
    if [ -n "${RTSP_URL:-}" ]; then
        echo "  ✓ RTSP_URL is set"
    else
        echo "  ⚠ RTSP_URL not set in environment"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Setup looks good."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "✓ No critical errors found"
    echo "⚠ $WARNINGS warning(s) - review above"
    exit 0
else
    echo "✗ $ERRORS error(s) found - please fix before running"
    echo "⚠ $WARNINGS warning(s) - review above"
    exit 1
fi
