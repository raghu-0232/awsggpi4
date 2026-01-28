# YOLO Object Detection on Raspberry Pi 4

Real-time object detection using YOLO on Raspberry Pi 4 with automatic person and vehicle counting, MJPEG streaming, and daily CSV logging.

## Features

- Real-time object detection using Ultralytics YOLO models
- Multi-ROI (Region of Interest) tracking and counting
- Minute-by-minute statistics logging to daily CSV files
- MJPEG stream served over HTTP
- Automatic setup - no manual intervention required
- Systemd service support for automatic startup
- Uses network time (NTP) - no RTC required
- India timezone (IST) support

## Quick Start (Fully Automated)

**For fresh Raspberry Pi installation:**

```bash
git clone https://github.com/raghu-0232/awsggpi4.git
cd awsggpi4
./setup-auto.sh --install-service --start-service
```

That's it! The script will:
- ✅ Install all system dependencies
- ✅ Create Python virtual environment
- ✅ Install Python packages
- ✅ Download YOLO model automatically
- ✅ Configure environment
- ✅ Set up and start systemd service

**Outcomes:**
- **Live stream:** `http://<pi-ip-address>:9090` — web page with MJPEG video; `/video` is the raw stream
- **Daily CSV:** `detections_YYYY-MM-DD.csv` in project dir — minute-by-minute counts (see [Output files](#output-files))
- **Detection log:** `detections.log` — real-time Person/Bike/Motorcycle events per ROI
- **Service logs:** `awsggpi4.log`, `awsggpi4-error.log`

## Manual Setup (If Needed)

If you prefer step-by-step:

```bash
# 1. Clone repository
git clone https://github.com/raghu-0232/awsggpi4.git
cd awsggpi4

# 2. Run installer
./install.sh

# 3. Configure (optional - defaults work)
sudo nano /etc/default/awsggpi4

# 4. Run manually
./run.sh

# 5. Or install service
./install-service.sh
sudo systemctl enable awsggpi4
sudo systemctl start awsggpi4
```

## Configuration

Edit configuration file:
```bash
sudo nano /etc/default/awsggpi4
```

**Key settings:**
- `USE_PICAMERA=1` - Use Pi Camera (or `0` for RTSP)
- `RTSP_URL=...` - RTSP stream URL (if not using Pi Camera)
- `YOLO_MODEL_PATH=...` - Path to YOLO model (default: `~/models/yolov8n.pt`)
- `ROI1` and `ROI2` - Region coordinates (x1,y1,x2,y2)
- `STREAM_PORT=9090` - HTTP stream port
- `TZ_OFFSET_MINUTES=330` - India time (IST = UTC+5:30)

## Output Files

All output files are written in the project directory (or `HOURLY_CSV_PATH` parent for CSVs).

| Output | Description |
|--------|-------------|
| **Live stream** | `http://<pi-ip>:9090` — web page; `http://<pi-ip>:9090/video` — MJPEG stream |
| **Daily CSV** | `detections_YYYY-MM-DD.csv` (e.g. `detections_2026-01-28.csv`) |
| **Detection log** | `detections.log` — Person / Bike / Motorcycle events in ROI1 and ROI2 |
| **Service logs** | `awsggpi4.log`, `awsggpi4-error.log` |

**Daily CSV format** (updated every minute, IST from NTP):

| Column | Description |
|--------|-------------|
| `time_bucket` | 1‑minute window, e.g. `2026-01-28 14:30:00 - 14:31:00 IST` |
| `roi1_persons` | Person count in ROI1 |
| `roi1_two_wheelers` | Bicycle + motorcycle count in ROI1 |
| `roi2_persons` | Person count in ROI2 |
| `roi2_two_wheelers` | Bicycle + motorcycle count in ROI2 |

**What’s counted:** Persons (class 0), Bicycles (1), Motorcycles (3) whose center falls inside ROI1 or ROI2.

## Viewing Data

```bash
# View recent detections
./view-detections.sh

# Follow detections live
./view-detections.sh follow

# View today's detections
./view-detections.sh today

# Check service status
./check-service.sh

# View service logs
./view-logs.sh
```

## Project Structure

```
awsggpi4/
├── objectdetection.py      # Main application
├── install.sh              # Installation script
├── setup-auto.sh          # Fully automated setup
├── run.sh                  # Manual run script
├── install-service.sh      # Install systemd service
├── requirements.txt       # Python dependencies
├── awsggpi4.env.example   # Configuration template
├── roi_config.json.example # ROI config template
└── yolo_app/              # Application modules
    ├── capture.py         # Frame capture (Pi Camera/RTSP)
    ├── config.py          # Configuration management
    ├── draw.py            # Drawing functions
    ├── hourly.py          # Minute-by-minute counting
    ├── stream.py          # Flask MJPEG server
    └── tracking.py        # Object tracking
```

## Deploy as AWS IoT Greengrass v2 Component

To run awsggpi4 as a **Greengrass v2 component** on a Pi 4 (or Linux aarch64):

1. Build artifact: `./greengrass/build-artifact.sh`
2. Upload `greengrass/awsggpi4.zip` to S3, update the recipe `Uri`, then create and deploy the component.

See **[GREENGASS_DEPLOY.md](GREENGASS_DEPLOY.md)** for prerequisites, S3 setup, deployment commands, and config overrides.

## Requirements

- Raspberry Pi 4
- Raspberry Pi OS (64-bit recommended)
- Python 3.9+
- Internet connection (for NTP time sync and model download)

## Troubleshooting

**Service not starting:**
```bash
sudo systemctl status awsggpi4
./view-logs.sh error
```

**Port 9090 not accessible:**
```bash
./check-service.sh
# Check firewall: sudo ufw allow 9090
```

**Camera not working:**
- For Pi Camera: Ensure camera is enabled (`sudo raspi-config`)
- For RTSP: Verify RTSP_URL is correct

**Model not found:**
- Setup script downloads automatically to `~/models/yolov8n.pt`
- Or set `YOLO_MODEL_PATH` in `/etc/default/awsggpi4`

## License

[Add your license here]

## Support

For issues, please open an issue on GitHub.
