#!/bin/bash
# Install systemd service with dynamic paths based on current user

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo ~$CURRENT_USER)
PROJECT_DIR="$SCRIPT_DIR"

echo "Installing systemd service for user: $CURRENT_USER"
echo "Project directory: $PROJECT_DIR"
echo ""

# Create service file with actual paths
SERVICE_FILE="/tmp/awsggpi4.service.$$"
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=YOLO Object Detection Stream (awsggpi4)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
EnvironmentFile=-/etc/default/awsggpi4
ExecStart=$PROJECT_DIR/bin/python $PROJECT_DIR/objectdetection.py
Restart=on-failure
RestartSec=3
StandardOutput=append:$PROJECT_DIR/awsggpi4.log
StandardError=append:$PROJECT_DIR/awsggpi4-error.log

[Install]
WantedBy=multi-user.target
EOF

# Copy to systemd
sudo cp "$SERVICE_FILE" /etc/systemd/system/awsggpi4.service
rm "$SERVICE_FILE"

sudo systemctl daemon-reload
echo "Service installed successfully!"
echo ""
echo "To enable: sudo systemctl enable awsggpi4"
echo "To start: sudo systemctl start awsggpi4"
