# YOLO Object Detection on Raspberry Pi 4

This project runs YOLO-based object detection on a Raspberry Pi 4, reads frames from a camera source (Pi Camera or RTSP stream), performs detection and tracking, draws overlays, and serves an MJPEG stream via HTTP.

## Features

- Real-time object detection using Ultralytics YOLO models
- Multi-ROI (Region of Interest) tracking and counting
- Hourly statistics logging to CSV
- MJPEG stream served over HTTP
- Systemd service support for automatic startup
- Configurable via environment variables

## Quick Start (Fresh Pi Installation)

### Prerequisites

- Raspberry Pi 4 with Raspberry Pi OS (64-bit recommended)
- Python 3.9+ (usually pre-installed)
- Internet connection for package installation

### Step 1: Clone the Repository

```bash
cd /home/pi4
git clone https://github.com/raghu-0232/awsggpi4.git
cd awsggpi4
```

### Step 2: Run the Installer

The installer script will:
- Install system dependencies
- Create a Python virtual environment
- Install Python packages

```bash
chmod +x install.sh
./install.sh
```

This will create a virtual environment in the project directory (same structure as `/home/pi4/YOLO`).

### Step 3: Download YOLO Model

Download a YOLO model file (e.g., `yolov8n.pt` for nano, or `yolov8s.pt` for small):

```bash
# Create a directory for models (optional)
mkdir -p ~/models

# Download using wget or curl (example URL - adjust as needed)
# wget https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.pt -O ~/models/yolov8n.pt
```

Or place your model file in a known location.

### Step 4: Configure Environment

Copy the example environment file and customize it:

```bash
sudo cp awsggpi4.env.example /etc/default/awsggpi4
sudo nano /etc/default/awsggpi4
```

**Important settings to configure:**

- `USE_PICAMERA=1` - Set to `1` for Pi Camera, `0` for RTSP stream
- `RTSP_URL` - Your RTSP stream URL (if not using Pi Camera)
- `YOLO_MODEL_PATH` - Path to your `.pt` model file
- `ROI1` and `ROI2` - Region of Interest coordinates (x1,y1,x2,y2)
- `STREAM_PORT` - Port for the MJPEG stream (default: 9090)

### Step 5: Configure ROI (Optional)

If you want to use a JSON file for ROI configuration:

```bash
cp roi_config.json.example roi_config.json
nano roi_config.json
```

Adjust the coordinates as needed. The JSON file will override `ROI1` and `ROI2` environment variables if it exists.

### Step 6: Test Run

Test the application manually:

```bash
./run.sh
```

The stream should be available at:
- `http://localhost:9090/` (or your configured port)
- `http://<pi-ip-address>:9090/` (from other devices on the network)

Press `Ctrl+C` to stop.

### Step 7: Set Up Systemd Service (Optional)

To run automatically on boot:

```bash
# Copy the service file
sudo cp awsggpi4.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable the service (starts on boot)
sudo systemctl enable awsggpi4

# Start the service
sudo systemctl start awsggpi4

# Check status
sudo systemctl status awsggpi4

# View logs
tail -f /home/pi4/awsggpi4/awsggpi4.log
tail -f /home/pi4/awsggpi4/awsggpi4-error.log
```

**Service management commands:**
```bash
sudo systemctl stop awsggpi4      # Stop the service
sudo systemctl start awsggpi4     # Start the service
sudo systemctl restart awsggpi4   # Restart the service
sudo systemctl disable awsggpi4   # Disable auto-start on boot
```

## Configuration Reference

### Environment Variables

All configuration is done via environment variables loaded from `/etc/default/awsggpi4`:

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_PICAMERA` | `0` | Set to `1` to use Raspberry Pi Camera |
| `RTSP_URL` | (see example) | RTSP stream URL (if not using Pi Camera) |
| `FRAME_WIDTH` | `1280` | Frame width |
| `FRAME_HEIGHT` | `720` | Frame height |
| `ROI1` | `0,0,640,720` | ROI1 coordinates (x1,y1,x2,y2) |
| `ROI2` | `640,0,1280,720` | ROI2 coordinates (x1,y1,x2,y2) |
| `YOLO_MODEL_PATH` | `/home/pi4/screenshots/yolov8n.pt` | Path to YOLO model file |
| `STREAM_PORT` | `9090` | HTTP port for MJPEG stream |
| `INFER_IMG_SIZE` | `640` | Inference image size (smaller = faster) |
| `INFER_EVERY_N` | `1` | Process every Nth frame (1 = all frames) |
| `COUNT_CLASS_IDS` | `0,1,3` | Class IDs to count (comma-separated) |
| `DRAW_DETECTIONS` | `1` | Draw bounding boxes (1 = yes, 0 = no) |
| `TRACK_IOU_THRESHOLD` | `0.3` | Tracking IoU threshold |
| `TRACK_MAX_AGE_SECONDS` | `5` | Max age for tracking (seconds) |
| `COUNT_INTERVAL_MINUTES` | `30` | Time interval for hourly counts |
| `TZ_OFFSET_MINUTES` | `330` | Timezone offset (330 = IST) |
| `HOURLY_CSV_PATH` | `/home/pi4/awsggpi4/hourly_counts.csv` | Path for CSV output |
| `ROI_CONFIG_PATH` | `/home/pi4/awsggpi4/roi_config.json` | Path to ROI JSON config |
| `ENABLE_IMSHOW` | `0` | Enable cv2.imshow (only if display connected) |

### YOLO Class IDs

Common class IDs (COCO dataset):
- `0` - person
- `1` - bicycle
- `2` - car
- `3` - motorcycle
- etc.

## Project Structure

```
awsggpi4/
├── objectdetection.py      # Main application entry point
├── install.sh              # Installation script
├── run.sh                  # Manual run script
├── requirements.txt        # Python dependencies
├── awsggpi4.service        # Systemd service file
├── awsggpi4.env.example    # Environment config template
├── roi_config.json.example # ROI config template
├── README.md               # This file
└── yolo_app/               # Application modules
    ├── __init__.py
    ├── capture.py          # Frame capture (Pi Camera/RTSP)
    ├── config.py           # Configuration management
    ├── draw.py             # Drawing functions (HUD, ROIs, detections)
    ├── hourly.py           # Hourly counting logic
    ├── stream.py           # Flask MJPEG stream server
    └── tracking.py         # Object tracking
```

## Troubleshooting

### Stream not accessible on port 9090

1. **Check if service is running:**
   ```bash
   sudo systemctl status awsggpi4
   ```

2. **Check if port is in use:**
   ```bash
   sudo netstat -tlnp | grep 9090
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status
   # If enabled, allow port 9090:
   sudo ufw allow 9090
   ```

4. **Run manually to see errors:**
   ```bash
   ./run.sh
   ```

### Camera not working

1. **For Pi Camera:**
   ```bash
   # Test camera
   libcamera-hello --list-cameras
   ```

2. **For RTSP stream:**
   - Verify the RTSP URL is correct
   - Test with VLC or ffplay:
     ```bash
     ffplay rtsp://your-stream-url
     ```

### Model loading fails

- Ensure the model file path is correct in `/etc/default/awsggpi4`
- Check file permissions: `ls -l /path/to/model.pt`
- Verify the model file is valid (try downloading again)

### Performance issues

- Reduce `INFER_IMG_SIZE` (e.g., 320 instead of 640)
- Increase `INFER_EVERY_N` (e.g., 2 or 3 to skip frames)
- Use a smaller model (`yolov8n.pt` instead of `yolov8s.pt`)

### Virtual environment issues

If you get "command not found" or import errors:

```bash
# Reinstall dependencies
source bin/activate  # or .venv/bin/activate
pip install -r requirements.txt
```

## Manual Installation (Alternative)

If you prefer manual setup:

```bash
# Install system dependencies
sudo apt update
sudo apt install -y python3-pip python3-venv build-essential \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 \
    libjpeg-dev libpng-dev git

# Create virtual environment
python3 -m venv .

# Activate virtual environment
source bin/activate

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install Python packages
pip install -r requirements.txt
```

## Logs

- Service logs: `/home/pi4/awsggpi4/awsggpi4.log`
- Error logs: `/home/pi4/awsggpi4/awsggpi4-error.log`
- Hourly counts: `/home/pi4/awsggpi4/hourly_counts.csv`

## Recommended Next Steps

- Set up automatic model updates
- Configure email/SMS alerts for events
- Add database logging instead of CSV
- Integrate with home automation systems
- Set up monitoring/alerting for the service

## License

[Add your license information here]

## Support

For issues and questions, please open an issue on GitHub or contact the maintainer.
