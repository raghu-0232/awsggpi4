# YOLO on Raspberry Pi 4 - awsggpi4

This project runs YOLO-based object detection on a Raspberry Pi 4, reads frames from a camera source, performs detection, tracking, draws overlays, and serves a MJPEG stream.

## Quick notes about Raspberry Pi 4
- Raspbian / Raspberry Pi OS (64-bit is recommended) with Python 3.9+.
- Pi4 can run smaller YOLO models (yolov8n / yolov8s) reasonably, but large models will be very slow on CPU.
- Consider using accelerators (Coral USB TPU, Intel NCS, or Jetson/TensorRT) if you need higher FPS.

## Installation (recommended)
1. Clone repo:
   ```
   git clone https://github.com/raghu-0232/awsggpi4.git
   cd awsggpi4
   ```

2. On Raspberry Pi 4 run the installer script (this will create a virtualenv and install Python deps):
   ```
   chmod +x install.sh
   ./install.sh
   ```

   - Activating the environment:
     ```
     source .venv/bin/activate
     ```

   - If you prefer manual steps:
     - Install system libs:
       ```
       sudo apt update
       sudo apt install -y python3-pip python3-venv build-essential libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 libjpeg-dev libpng-dev
       ```
     - Create venv:
       ```
       python3 -m venv .venv
       source .venv/bin/activate
       pip install --upgrade pip
       pip install -r requirements.txt
       ```

3. Model weights
   - Place your Ultralytics YOLO `.pt` model (e.g., `yolov8n.pt`) somewhere accessible and set its path in the configuration (see below).

## Configuration
- This repository uses `yolo_app.config.Config.from_env()` to load configuration from environment variables.
- Example environment variables (set in your shell or systemd service file):
  - MODEL_PATH - path to your .pt model (e.g., `/home/pi/models/yolov8n.pt`)
  - STREAM_PORT - port for MJPEG stream (default: 5000)
  - INFER_IMG_SIZE - target size for inference (e.g., 320)
  - INFER_EVERY_N - integer: infer every N frames (useful for performance)
  - ENABLE_IMSHOW - set to `1` to enable cv2.imshow (DON'T enable on headless Pi)
  - DEVICE - set to `cpu` (default) or specify device if you have accelerator support
- Example:
  ```
  export MODEL_PATH=/home/pi/models/yolov8n.pt
  export DEVICE=cpu
  export STREAM_PORT=5000
  export INFER_IMG_SIZE=320
  ```

## Running
With the virtualenv activated:
```
python objectdetection.py
```

If you enabled streaming (default), open:
- http://<pi-ip>:<STREAM_PORT>/ (or as configured) to view the MJPEG stream

## Troubleshooting & tips
- If the app crashes at model load or inference:
  - Ensure the `ultralytics` package installed is compatible with the model file.
  - Try using a smaller model (yolov8n).
- If cv2.imshow fails or you have no display:
  - Make sure `ENABLE_IMSHOW` is disabled (default should be disabled for headless).
- To improve performance:
  - Reduce inference image size (INFER_IMG_SIZE).
  - Increase `INFER_EVERY_N` to skip frames between inferences.
  - Use a specialized runtime (OpenVINO, TensorRT, Coral) if available.
- Use logging output to understand failures. Consider increasing log level in objectdetection.py.

## Recommended next steps
- Add a systemd service that activates the venv and runs the script at boot.
- Add a simple sample config file or example env file `.env.example` with common variables.
- Consider lightweight model (yolov8n) by default in documentation.