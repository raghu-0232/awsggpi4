#!/bin/bash
# Quick diagnostic script to check service status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Service Diagnostic Check"
echo "=========================================="
echo ""

echo "1. Service Status:"
sudo systemctl status awsggpi4 --no-pager -l | head -15
echo ""

echo "2. Recent Logs (last 20 lines):"
if [ -f "$SCRIPT_DIR/awsggpi4.log" ]; then
    sudo tail -20 "$SCRIPT_DIR/awsggpi4.log" 2>/dev/null || echo "Cannot read log file (permission issue)"
else
    echo "No log file found"
fi
echo ""

echo "3. Recent Errors (last 20 lines):"
if [ -f "$SCRIPT_DIR/awsggpi4-error.log" ]; then
    sudo tail -20 "$SCRIPT_DIR/awsggpi4-error.log" 2>/dev/null || echo "Cannot read error log file (permission issue)"
else
    echo "No error log file found"
fi
echo ""

echo "4. Port 9090 Status:"
if command -v netstat >/dev/null 2>&1; then
    sudo netstat -tlnp | grep 9090 || echo "Port 9090 not listening"
elif command -v ss >/dev/null 2>&1; then
    sudo ss -tlnp | grep 9090 || echo "Port 9090 not listening"
else
    echo "Cannot check port (netstat/ss not available)"
fi
echo ""

echo "5. Process Check:"
ps aux | grep "[p]ython.*objectdetection.py" || echo "No objectdetection.py process found"
echo ""

echo "6. Configuration Check:"
if [ -f /etc/default/awsggpi4 ]; then
    echo "STREAM_PORT setting:"
    sudo grep "^STREAM_PORT" /etc/default/awsggpi4 2>/dev/null || echo "STREAM_PORT not set (using default 9090)"
    echo "USE_PICAMERA setting:"
    sudo grep "^USE_PICAMERA" /etc/default/awsggpi4 2>/dev/null || echo "USE_PICAMERA not set"
    echo "YOLO_MODEL_PATH setting:"
    sudo grep "^YOLO_MODEL_PATH" /etc/default/awsggpi4 2>/dev/null || echo "YOLO_MODEL_PATH not set"
else
    echo "Configuration file not found at /etc/default/awsggpi4"
fi
echo ""

echo "=========================================="
echo "To view live logs: tail -f $SCRIPT_DIR/awsggpi4-error.log"
echo "=========================================="
