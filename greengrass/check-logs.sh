#!/usr/bin/env bash
# Script to check AWS IoT Greengrass component logs and deployment status

set -e

COMPONENT_NAME="com.example.awsggpi4"
GREENGRASS_ROOT="/greengrass/v2"

echo "=========================================="
echo "Checking Greengrass Component Status"
echo "=========================================="
echo ""

# 1. Check component status using Greengrass CLI
echo "1. Component Status:"
sudo /greengrass/v2/bin/greengrass-cli component list | grep -A 5 "$COMPONENT_NAME" || echo "Component not found in list"
echo ""

# 2. Check component logs (most recent)
echo "2. Recent Component Logs (last 50 lines):"
sudo /greengrass/v2/bin/greengrass-cli logs get --component-name "$COMPONENT_NAME" --lines 50 || echo "No logs available"
echo ""

# 3. Check Greengrass system logs
echo "3. Greengrass System Logs (last 30 lines):"
sudo journalctl -u greengrass -n 30 --no-pager || echo "Systemd service not found, checking log files..."
echo ""

# 4. Check component-specific log files
echo "4. Component Log Files:"
if [ -d "$GREENGRASS_ROOT/logs" ]; then
    echo "Checking $GREENGRASS_ROOT/logs:"
    find "$GREENGRASS_ROOT/logs" -name "*${COMPONENT_NAME}*" -type f -exec ls -lh {} \; 2>/dev/null | head -10
    echo ""
    echo "Recent errors from component logs:"
    find "$GREENGRASS_ROOT/logs" -name "*${COMPONENT_NAME}*" -type f -exec grep -i "error\|fail\|exception" {} \; 2>/dev/null | tail -20
else
    echo "Logs directory not found at $GREENGRASS_ROOT/logs"
fi
echo ""

# 5. Check component work directory and artifacts
echo "5. Component Work Directory:"
COMPONENT_WORK="$GREENGRASS_ROOT/work/$COMPONENT_NAME"
if [ -d "$COMPONENT_WORK" ]; then
    echo "Work directory exists: $COMPONENT_WORK"
    ls -la "$COMPONENT_WORK" 2>/dev/null || echo "Cannot list work directory"
    echo ""
    echo "Checking for requirements.txt in artifacts:"
    find "$GREENGRASS_ROOT/packages/artifacts-unarchived" -name "requirements.txt" -type f 2>/dev/null | head -5
    echo ""
    echo "Artifact structure:"
    find "$GREENGRASS_ROOT/packages/artifacts-unarchived/$COMPONENT_NAME" -type f 2>/dev/null | head -20 || echo "Artifacts directory not found"
else
    echo "Work directory not found: $COMPONENT_WORK"
fi
echo ""

# 6. Check for installation errors specifically
echo "6. Installation Errors (from Greengrass logs):"
sudo journalctl -u greengrass --no-pager | grep -i "error\|fail\|exception" | grep -i "$COMPONENT_NAME\|install\|requirements" | tail -30 || echo "No installation errors found in system logs"
echo ""

# 7. Check deployment status from AWS (if AWS CLI is configured)
echo "7. Deployment Status (from AWS):"
if command -v aws &> /dev/null; then
    REGION="${AWS_REGION:-ap-south-1}"
    THING_NAME="${THING_NAME:-pi4}"
    echo "Checking deployments for thing: $THING_NAME"
    aws greengrassv2 list-deployments --target-arn "arn:aws:iot:${REGION}:*:thing/${THING_NAME}" --region "$REGION" 2>/dev/null | head -20 || echo "Could not fetch deployment status (check AWS credentials)"
else
    echo "AWS CLI not available"
fi
echo ""

# 8. Real-time log monitoring (optional - commented out)
echo "=========================================="
echo "To monitor logs in real-time, run:"
echo "  sudo journalctl -u greengrass -f"
echo ""
echo "Or for component-specific logs:"
echo "  sudo /greengrass/v2/bin/greengrass-cli logs get --component-name $COMPONENT_NAME --follow"
echo "=========================================="
