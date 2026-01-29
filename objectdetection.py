import time
import os
import logging
from pathlib import Path
import cv2
from ultralytics import YOLO

from yolo_app.capture import FrameBuffer, start_capture
from yolo_app.config import Config
from yolo_app.draw import draw_detections, draw_hud, draw_rois
from yolo_app.hourly import HourlyCounter, write_hourly_counts
from yolo_app.stream import create_app, start_server
from yolo_app.tracking import SimpleTracker
from yolo_app.s3_uploader import S3Uploader


def main():
    # Configure logging with both console and file handlers
    log_dir = Path(os.environ.get("LOG_DIR", Path(__file__).parent))
    log_dir.mkdir(parents=True, exist_ok=True)
    detection_log_file = log_dir / "detections.log"
    
    # Create formatters
    detailed_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    simple_formatter = logging.Formatter(
        '%(asctime)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    
    # Console handler (all logs)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(detailed_formatter)
    root_logger.addHandler(console_handler)
    
    # Detection log file handler (detection-specific logs)
    detection_handler = logging.FileHandler(detection_log_file)
    detection_handler.setLevel(logging.INFO)
    detection_handler.setFormatter(simple_formatter)
    # Only log detection-related messages to this file
    detection_handler.addFilter(lambda record: 'DETECTION' in record.getMessage() or 'MINUTE_SUMMARY' in record.getMessage())
    root_logger.addHandler(detection_handler)
    
    log = logging.getLogger("objectdetection")

    config = None
    capture_thread = None
    hourly = None
    config = Config.from_env()

    try:
        model = YOLO(config.model_path, task="detect")
    except Exception as e:
        log.exception("Failed to load model %s: %s", config.model_path, e)
        return

    names = getattr(model, "names", {})

    running = True

    def running_flag():
        return running

    capture_buffer = FrameBuffer()
    annotated_buffer = FrameBuffer()

    app = create_app(annotated_buffer.get, running_flag, config.jpeg_quality)
    log.info("Starting stream server on port %d", config.stream_port)
    server_thread = start_server(app, config.stream_port)
    log.info("Stream server started")

    log.info("Starting capture...")
    try:
        capture_thread = start_capture(config, capture_buffer, running_flag)
        log.info("Capture thread started, entering main loop...")
    except Exception as e:
        log.exception("Failed to start capture thread: %s", e)
        log.error("Application will continue but no video feed will be available")
        capture_thread = None

    fps = 0.0
    t_start = time.time()
    frame_index = 0
    event_count = 0
    tracker = SimpleTracker(config.track_iou_threshold, config.track_max_age_seconds)
    hourly = HourlyCounter(config.interval_minutes, config.tz_offset_minutes, config.hourly_csv_path)
    s3_uploader = S3Uploader(config.hourly_csv_path, config.s3_bucket, config.s3_prefix, 
                             config.aws_region, config.tz_offset_minutes) if config.s3_bucket else None

    def roi_for_detection(bbox):
        x1, y1, x2, y2 = bbox
        cx = (x1 + x2) / 2.0
        cy = (y1 + y2) / 2.0
        if config.roi1[0] <= cx <= config.roi1[2] and config.roi1[1] <= cy <= config.roi1[3]:
            return 1
        if config.roi2[0] <= cx <= config.roi2[2] and config.roi2[1] <= cy <= config.roi2[3]:
            return 2
        return 0

    try:
        while True:
            delta_t = time.time() - t_start
            if delta_t > 0:
                fps = fps * config.fps_smooth + (1.0 - config.fps_smooth) / delta_t
            t_start = time.time()

            frame = capture_buffer.get()
            if frame is None:
                time.sleep(0.01)
                continue

            frame_index += 1
            if config.infer_every_n > 1 and (frame_index % config.infer_every_n) != 0:
                annotated = cv2.resize(frame, (config.width, config.height))
                draw_rois(annotated, config.roi1, config.roi2)
                draw_hud(annotated, fps, event_count, hourly.roi1_persons + hourly.roi2_persons, hourly.roi1_two_wheelers + hourly.roi2_two_wheelers, config.height)
                annotated_buffer.set(annotated)
                continue

            results = model(frame, conf=0.25, imgsz=config.infer_img_size, verbose=False)[0]
            hourly.rollover_if_needed()
            
            # Check and upload previous day's CSV to S3 (runs once per day after midnight)
            if s3_uploader:
                s3_uploader.upload_previous_day_csv()

            detections = []
            if hasattr(results, "boxes") and results.boxes is not None:
                for box in results.boxes:
                    try:
                        cls_id = int(box.cls[0])
                    except Exception:
                        cls_id = int(box.cls)
                    if config.count_class_ids and cls_id not in config.count_class_ids:
                        continue
                    xyxy = box.xyxy[0].tolist()
                    detections.append({"bbox": xyxy, "cls": cls_id})

            new_detections = tracker.update(detections, time.time())
            for det in new_detections:
                roi = roi_for_detection(det["bbox"])
                if roi == 0:
                    continue
                event_count += 1
                
                # Log detection (only for persons and bikes, no garbage)
                if det["cls"] == 0:  # Person
                    if roi == 1:
                        hourly.roi1_persons += 1
                        log.info("DETECTION: Person in ROI1 - Total: %d", hourly.roi1_persons)
                    else:
                        hourly.roi2_persons += 1
                        log.info("DETECTION: Person in ROI2 - Total: %d", hourly.roi2_persons)
                elif det["cls"] in (1, 3):  # Bicycle (1) or Motorcycle (3)
                    vehicle_type = "Bike" if det["cls"] == 1 else "Motorcycle"
                    if roi == 1:
                        hourly.roi1_two_wheelers += 1
                        log.info("DETECTION: %s in ROI1 - Total: %d", vehicle_type, hourly.roi1_two_wheelers)
                    else:
                        hourly.roi2_two_wheelers += 1
                        log.info("DETECTION: %s in ROI2 - Total: %d", vehicle_type, hourly.roi2_two_wheelers)

            annotated = frame.copy()
            if config.draw_detections:
                draw_detections(annotated, detections, names)
            annotated = cv2.resize(annotated, (config.width, config.height))
            draw_rois(annotated, config.roi1, config.roi2)
            draw_hud(
                annotated,
                fps,
                event_count,
                hourly.roi1_persons + hourly.roi2_persons,
                hourly.roi1_two_wheelers + hourly.roi2_two_wheelers,
                config.height,
            )
            annotated_buffer.set(annotated)

            if config.enable_imshow:
                cv2.imshow("IP Camera", annotated)
                if cv2.waitKey(1) == ord("q"):
                    break
    except KeyboardInterrupt:
        log.info("Interrupted by user")
    finally:
        running = False
        try:
            if capture_thread is not None:
                capture_thread.join(timeout=2)
        except Exception:
            pass
        try:
            if hourly is not None:
                hourly._update_csv_path()
                write_hourly_counts(
                    str(hourly.current_csv_path),
                    hourly.current_bucket,
                    hourly.roi1_persons,
                    hourly.roi1_two_wheelers,
                    hourly.roi2_persons,
                    hourly.roi2_two_wheelers,
                )
        except Exception as e:
            log.exception("Failed to write hourly counts: %s", e)
        if config is not None and config.enable_imshow:
            cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
