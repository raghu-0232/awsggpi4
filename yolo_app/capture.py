import threading
import time
from picamera2 import Picamera2
import cv2


class FrameBuffer:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._frame = None

    def set(self, frame) -> None:
        with self._lock:
            self._frame = frame

    def get(self):
        with self._lock:
            if self._frame is None:
                return None
            return self._frame.copy()


def _frame_grabber_rtsp(url: str, buffer: FrameBuffer, running_flag):
    cap = cv2.VideoCapture(url, cv2.CAP_FFMPEG)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
    while running_flag():
        ret, frame = cap.read()
        if ret:
            buffer.set(frame)
    cap.release()


def _frame_grabber_picam(width: int, height: int, buffer: FrameBuffer, running_flag):
    picam = Picamera2()
    picam.preview_configuration.main.size = (width, height)
    picam.preview_configuration.main.format = "RGB888"
    picam.preview_configuration.controls.FrameRate = 60
    picam.preview_configuration.align()
    picam.configure("preview")
    picam.start()
    while running_flag():
        frame = picam.capture_array()
        buffer.set(frame)
    picam.stop()


def start_capture(config, buffer: FrameBuffer, running_flag) -> threading.Thread:
    if config.use_picamera:
        thread = threading.Thread(
            target=_frame_grabber_picam,
            args=(config.width, config.height, buffer, running_flag),
            daemon=True,
        )
    else:
        thread = threading.Thread(
            target=_frame_grabber_rtsp,
            args=(config.rtsp_url, buffer, running_flag),
            daemon=True,
        )
    thread.start()
    time.sleep(2)
    return thread

