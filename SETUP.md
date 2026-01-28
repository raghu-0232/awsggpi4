# Automated Setup Guide

This project includes fully automated setup scripts that require **no manual steps**.

## Quick Start (One Command)

For a completely automated setup:

```bash
git clone https://github.com/raghu-0232/awsggpi4.git
cd awsggpi4
./setup-auto.sh --install-service --start-service
```

That's it! The script will:
1. ✅ Install all system dependencies
2. ✅ Create Python virtual environment
3. ✅ Install Python packages (including opencv-python)
4. ✅ Download YOLO model automatically
5. ✅ Create and configure environment file
6. ✅ Set up systemd service
7. ✅ Start the service automatically

## Available Scripts

### `setup-auto.sh` - Fully Automated Setup
**Non-interactive, perfect for fresh installations**

```bash
# Basic setup (no service)
./setup-auto.sh

# Setup with systemd service (enabled but not started)
./setup-auto.sh --install-service

# Setup with systemd service and start it
./setup-auto.sh --install-service --start-service
```

### `install.sh` - Installation Only
Installs dependencies and creates virtual environment.

```bash
./install.sh
```

### `run.sh` - Run Manually
Runs the application manually (loads config, activates venv automatically).

```bash
./run.sh
```

**Features:**
- Automatically loads environment from `/etc/default/awsggpi4`
- Handles permission issues automatically
- Verifies and installs missing Python packages if needed
- Uses correct virtual environment Python

### `verify_setup.sh` - Verify Installation
Checks if everything is set up correctly.

```bash
./verify_setup.sh
```

## What Gets Configured Automatically

1. **System Dependencies**: All required apt packages
2. **Python Environment**: Virtual environment with all packages
3. **Environment File**: `/etc/default/awsggpi4` created from template
4. **Model Download**: Automatically downloads `yolov8n.pt` if not present
5. **ROI Config**: Creates `roi_config.json` from example if missing
6. **Systemd Service**: Installs and enables service (if requested)

## Configuration

After automated setup, edit configuration:

```bash
sudo nano /etc/default/awsggpi4
```

Key settings:
- `USE_PICAMERA=1` - Use Pi Camera (or `0` for RTSP)
- `RTSP_URL=...` - RTSP stream URL (if not using Pi Camera)
- `YOLO_MODEL_PATH=...` - Path to YOLO model file
- `ROI1` and `ROI2` - Region coordinates
- `STREAM_PORT=9090` - HTTP stream port

## Troubleshooting

### cv2 module not found
The `run.sh` script automatically installs it if missing. Or run:
```bash
./install.sh  # Reinstall dependencies
```

### Permission denied on /etc/default/awsggpi4
The `run.sh` script handles this automatically using sudo.

### Service not starting
Check logs:
```bash
sudo systemctl status awsggpi4
./view-logs.sh follow
```

### Port already in use
Change `STREAM_PORT` in `/etc/default/awsggpi4` or stop the conflicting service.

## Manual Steps (If Needed)

If you prefer manual control:

1. **Install dependencies**: `./install.sh`
2. **Download model**: Place `yolov8n.pt` in `~/models/`
3. **Configure**: `sudo nano /etc/default/awsggpi4`
4. **Run**: `./run.sh`
5. **Service**: `sudo cp awsggpi4.service /etc/systemd/system/ && sudo systemctl enable awsggpi4`

## Files Created

- Virtual environment: `bin/`, `lib/`, `include/` (in project directory)
- Environment config: `/etc/default/awsggpi4`
- ROI config: `roi_config.json` (from example)
- Model file: `~/models/yolov8n.pt` (if downloaded)
- Logs: `awsggpi4.log`, `awsggpi4-error.log`
- CSV data: `detections_YYYY-MM-DD.csv` (daily files, updated every minute)
