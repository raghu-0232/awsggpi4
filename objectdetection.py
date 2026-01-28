import time
import os
import logging
import cv2
from ultralytics import YOLO

from yolo_app.capture import FrameBuffer, start_capture
from yolo_app.config import Config
from yolo_app.draw import draw_detections, draw_hud, draw_rois
from yolo_app.hourly import HourlyCounter, write_hourly_counts
from yolo_app.stream import create_app, start_server
from yolo_app.tracking import SimpleTracker


def main():
    logging.basicConfig(level=logging.INFO)
    log = logging.getLogger("objectdetection")

    config = Config.from_env()

    device = getattr(config, "device", None) or os.environ.get("YOLO_DEVICE", "cpu")
    log.info("Using device: %s", device)

    try:
        model = YOLO(config.model_path, task="detect", device=device)
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
    start_server(app, config.stream_port)

    capture_thread = start_capture(config, capture_buffer, running_flag)

    fps = 0.0
    t_start = time.time()
    frame_index = 0
    event_count = 0
    tracker = SimpleTracker(config.track_iou_threshold, config.track_max_age_seconds)
    hourly = HourlyCounter(config.interval_minutes, config.tz_offset_minutes)

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
                fps = fps * config.fps_smooth + (1.0 - config.fps_smooth) * (1.0 / delta_t)
            t_start = time.time()

            frame = capture_buffer.get()
            if frame is None:
                time.sleep(0.01)
                continue

            frame_index += 1
            if config.infer_every_n > 1 and (frame_index % config.infer_every_n) != 0:
                annotated = cv2.resize(frame, (config.width, config.height))
                draw_hud(annotated, fps, event_count, hourly.persons, hourly.two_wheelers, config.height)
                annotated_buffer.set(annotated)
                continue

            # Preprocess: convert BGR->RGB (safer) and optionally resize to reduce CPU load
            try:
                rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            except Exception:
                rgb = frame  # fallback if conversion fails

            # Optionally downscale prior to inference to speed up on Pi
            try:
                if isinstance(config.infer_img_size, int):
                    infer_img = cv2.resize(rgb, (config.infer_img_size, config.infer_img_size))
                else:
                    infer_img = rgb
            except Exception:
                infer_img = rgb

            try:
                results = model(infer_img, conf=getattr(config, "confidence", 0.25), imgsz=config.infer_img_size, verbose=False)[0]
            except Exception as e:
                log.exception("Model inference failed: %s", e)
                annotated = cv2.resize(frame, (config.width, config.height))
                draw_hud(annotated, fps, event_count, hourly.persons, hourly.two_wheelers, config.height)
                annotated_buffer.set(annotated)
                continue

            hourly.rollover_if_needed(config.hourly_csv_path)

            detections = []
            if hasattr(results, "boxes") and results.boxes is not None:
                for box in results.boxes:
                    try:
                        cls_id = int(box.cls[0])
                    except Exception:
                        cls_id = int(box.cls)
                    if getattr(config, "count_class_ids", None) and cls_id not in config.count_class_ids:
                        continue
                    try:
                        xyxy = box.xyxy[0].tolist()
                    except Exception:
                        xyxy = list(map(float, box.xyxy))
                    detections.append({"bbox": xyxy, "cls": cls_id})

            new_detections = tracker.update(detections, time.time())
            for det in new_detections:
                roi = roi_for_detection(det["bbox"])
                if roi == 0:
                    continue
                event_count += 1
                if det["cls"] == 0:
                    if roi == 1:
                        hourly.roi1_persons += 1
                    else:
                        hourly.roi2_persons += 1
                elif det["cls"] in (1, 3):
                    if roi == 1:
                        hourly.roi1_two_wheelers += 1
                    else:
                        hourly.roi2_two_wheelers += 1

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

            if getattr(config, "enable_imshow", False):
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
            write_hourly_counts(
                config.hourly_csv_path,
                hourly.current_hour,
                hourly.roi1_persons,
                hourly.roi1_two_wheelers,
                hourly.roi2_persons,
                hourly.roi2_two_wheelers,
            )
        except Exception as e:
            log.exception("Failed to write hourly counts: %s", e)
        if getattr(config, "enable_imshow", False):
            cv2.destroyAllWindows()


if __name__ == "__main__":
    main()