from dataclasses import dataclass
import json
import os
from pathlib import Path

# Get project root directory (parent of yolo_app)
_PROJECT_ROOT = Path(__file__).parent.parent


@dataclass(frozen=True)
class Config:
    width: int
    height: int
    use_picamera: bool
    rtsp_url: str
    model_path: str
    stream_port: int
    enable_imshow: bool
    count_class_ids: set[int]
    track_iou_threshold: float
    track_max_age_seconds: float
    infer_every_n: int
    infer_img_size: int
    hourly_csv_path: str
    draw_detections: bool
    roi1: tuple[int, int, int, int]
    roi2: tuple[int, int, int, int]
    roi_config_path: str
    interval_minutes: int
    tz_offset_minutes: int
    jpeg_quality: int = 85
    fps_smooth: float = 0.9
    s3_bucket: str = ""
    s3_prefix: str = "detections/"
    aws_region: str = "ap-south-1"

    @staticmethod
    def _parse_bool(value: str, default: bool = False) -> bool:
        if value is None:
            return default
        return value.strip() in ("1", "true", "True", "yes", "YES")

    @staticmethod
    def _parse_ids(value: str) -> set[int]:
        if not value:
            return set()
        return {int(x) for x in value.split(",") if x.strip().isdigit()}

    @staticmethod
    def _parse_roi(value: str, width: int, height: int) -> tuple[int, int, int, int]:
        if not value:
            return (0, 0, width, height)
        parts = [p.strip() for p in value.split(",")]
        if len(parts) != 4 or not all(p.lstrip("-").isdigit() for p in parts):
            return (0, 0, width, height)
        x1, y1, x2, y2 = [int(p) for p in parts]
        x1 = max(0, min(x1, width))
        x2 = max(0, min(x2, width))
        y1 = max(0, min(y1, height))
        y2 = max(0, min(y2, height))
        if x2 <= x1 or y2 <= y1:
            return (0, 0, width, height)
        return (x1, y1, x2, y2)

    @staticmethod
    def _load_roi_config(path: str, width: int, height: int):
        try:
            data = json.loads(Path(path).read_text())
            roi1 = data.get("roi1", [])
            roi2 = data.get("roi2", [])
            return (
                Config._parse_roi(",".join(str(x) for x in roi1), width, height),
                Config._parse_roi(",".join(str(x) for x in roi2), width, height),
            )
        except Exception:
            return (0, 0, width, height), (0, 0, width, height)

    @classmethod
    def from_env(cls) -> "Config":
        width = int(os.environ.get("FRAME_WIDTH", "1280"))
        height = int(os.environ.get("FRAME_HEIGHT", "720"))
        roi_config_path = os.environ.get("ROI_CONFIG_PATH", str(_PROJECT_ROOT / "roi_config.json"))
        roi1, roi2 = cls._load_roi_config(roi_config_path, width, height)
        env_roi1 = os.environ.get("ROI1", "")
        env_roi2 = os.environ.get("ROI2", "")
        if env_roi1:
            roi1 = cls._parse_roi(env_roi1, width, height)
        if env_roi2:
            roi2 = cls._parse_roi(env_roi2, width, height)
        return cls(
            width=width,
            height=height,
            use_picamera=cls._parse_bool(os.environ.get("USE_PICAMERA", "0")),
            rtsp_url=os.environ.get(
                "RTSP_URL",
                "rtsp://user:password@192.168.88.44:554/cam/realmonitor?channel=1&subtype=0",
            ),
            model_path=os.environ.get("YOLO_MODEL_PATH", str(Path.home() / "models" / "yolov8n.pt")),
            stream_port=int(os.environ.get("STREAM_PORT", "9090")),
            enable_imshow=cls._parse_bool(os.environ.get("ENABLE_IMSHOW", "0")),
            count_class_ids=cls._parse_ids(os.environ.get("COUNT_CLASS_IDS", "0,1,3")),
            track_iou_threshold=float(os.environ.get("TRACK_IOU_THRESHOLD", "0.3")),
            track_max_age_seconds=float(os.environ.get("TRACK_MAX_AGE_SECONDS", "5")),
            infer_every_n=int(os.environ.get("INFER_EVERY_N", "1")),
            infer_img_size=int(os.environ.get("INFER_IMG_SIZE", "640")),
            hourly_csv_path=os.environ.get("HOURLY_CSV_PATH", str(_PROJECT_ROOT / "detections.csv")),
            draw_detections=cls._parse_bool(os.environ.get("DRAW_DETECTIONS", "1")),
            roi1=roi1,
            roi2=roi2,
            roi_config_path=roi_config_path,
            interval_minutes=int(os.environ.get("COUNT_INTERVAL_MINUTES", "1")),
            tz_offset_minutes=int(os.environ.get("TZ_OFFSET_MINUTES", "330")),
            s3_bucket=os.environ.get("S3_BUCKET", ""),
            s3_prefix=os.environ.get("S3_PREFIX", "detections/"),
            aws_region=os.environ.get("AWS_REGION", "ap-south-1"),
        )

