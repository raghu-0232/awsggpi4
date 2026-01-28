#!/bin/bash
# View detection logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTION_LOG="$SCRIPT_DIR/detections.log"

if [ "$1" = "follow" ] || [ "$1" = "f" ]; then
    echo "Following detection log (Ctrl+C to stop)..."
    echo "=========================================="
    if [ -f "$DETECTION_LOG" ]; then
        tail -f "$DETECTION_LOG"
    else
        echo "Detection log not found. Waiting for first detection..."
        while [ ! -f "$DETECTION_LOG" ]; do
            sleep 1
        done
        tail -f "$DETECTION_LOG"
    fi
elif [ "$1" = "today" ]; then
    echo "Today's detections:"
    echo "=========================================="
    if [ -f "$DETECTION_LOG" ]; then
        grep "$(date +%Y-%m-%d)" "$DETECTION_LOG" || echo "No detections today"
    else
        echo "Detection log not found"
    fi
else
    echo "Recent detections (last 50 lines):"
    echo "=========================================="
    if [ -f "$DETECTION_LOG" ]; then
        tail -50 "$DETECTION_LOG"
    else
        echo "Detection log not found. It will be created when first detection occurs."
    fi
    echo ""
    echo "Usage:"
    echo "  ./view-detections.sh          - Show recent detections"
    echo "  ./view-detections.sh follow   - Follow detections live"
    echo "  ./view-detections.sh today    - Show today's detections"
fi
