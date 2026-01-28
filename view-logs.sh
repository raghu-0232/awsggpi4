#!/bin/bash
# View service logs with proper permissions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Service Logs Viewer"
echo "=========================================="
echo ""

if [ "$1" = "error" ] || [ "$1" = "err" ]; then
    echo "ERROR LOG (last 50 lines):"
    echo "----------------------------------------"
    sudo tail -50 "$SCRIPT_DIR/awsggpi4-error.log" 2>/dev/null || echo "No error log found or permission denied"
elif [ "$1" = "follow" ] || [ "$1" = "f" ]; then
    echo "Following error log (Ctrl+C to stop)..."
    echo "----------------------------------------"
    sudo tail -f "$SCRIPT_DIR/awsggpi4-error.log" 2>/dev/null || echo "Cannot follow log"
else
    echo "STANDARD LOG (last 50 lines):"
    echo "----------------------------------------"
    sudo tail -50 "$SCRIPT_DIR/awsggpi4.log" 2>/dev/null || echo "No log found or permission denied"
    echo ""
    echo "ERROR LOG (last 50 lines):"
    echo "----------------------------------------"
    sudo tail -50 "$SCRIPT_DIR/awsggpi4-error.log" 2>/dev/null || echo "No error log found or permission denied"
    echo ""
    echo "Usage:"
    echo "  ./view-logs.sh          - Show both logs"
    echo "  ./view-logs.sh error     - Show error log only"
    echo "  ./view-logs.sh follow    - Follow error log live"
fi
