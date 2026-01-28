import cv2


def draw_detections(frame, detections, names, color=(0, 255, 0)):
    for det in detections:
        x1, y1, x2, y2 = [int(v) for v in det["bbox"]]
        cls_id = det["cls"]
        label = names.get(cls_id, str(cls_id)) if isinstance(names, dict) else str(cls_id)
        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        cv2.putText(
            frame,
            label,
            (x1, max(15, y1 - 5)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            color,
            2,
        )


def draw_hud(frame, fps, event_count, hourly_persons, hourly_two_wheelers, height):
    cv2.putText(
        frame,
        "FPS: " + str(round(fps, 1)),
        (int(height * 0.01), int(height * 0.075)),
        cv2.FONT_HERSHEY_SIMPLEX,
        height * 0.002,
        (0, 0, 255),
        2,
    )
    cv2.putText(
        frame,
        f"Events: {event_count}",
        (int(height * 0.01), int(height * 0.14)),
        cv2.FONT_HERSHEY_SIMPLEX,
        height * 0.002,
        (0, 255, 0),
        2,
    )
    cv2.putText(
        frame,
        f"P:{hourly_persons} 2W:{hourly_two_wheelers}",
        (int(height * 0.01), int(height * 0.205)),
        cv2.FONT_HERSHEY_SIMPLEX,
        height * 0.002,
        (255, 255, 0),
        2,
    )


def draw_rois(frame, roi1, roi2):
    x1, y1, x2, y2 = roi1
    cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 0, 0), 2)
    cv2.putText(
        frame,
        "ROI1",
        (x1 + 5, y1 + 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (255, 0, 0),
        2,
    )
    x1, y1, x2, y2 = roi2
    cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 255), 2)
    cv2.putText(
        frame,
        "ROI2",
        (x1 + 5, y1 + 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (0, 255, 255),
        2,
    )

