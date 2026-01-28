import threading
import time
from flask import Flask, Response
import cv2


def create_app(get_frame, running_flag, jpeg_quality: int):
    app = Flask(__name__)

    @app.route("/")
    def index():
        return "<html><body><h2>YOLO Stream</h2><img src='/video'></body></html>"

    def generate_stream():
        while running_flag():
            frame = get_frame()
            if frame is None:
                time.sleep(0.05)
                continue
            ret, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, jpeg_quality])
            if not ret:
                continue
            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n" + buffer.tobytes() + b"\r\n"
            )

    @app.route("/video")
    def video():
        return Response(generate_stream(), mimetype="multipart/x-mixed-replace; boundary=frame")

    return app


def start_server(app, port: int) -> threading.Thread:
    def run():
        app.run(host="0.0.0.0", port=port, threaded=True)

    thread = threading.Thread(target=run, daemon=True)
    thread.start()
    return thread

