def iou(a, b) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    inter_x1 = max(ax1, bx1)
    inter_y1 = max(ay1, by1)
    inter_x2 = min(ax2, bx2)
    inter_y2 = min(ay2, by2)
    inter_w = max(0.0, inter_x2 - inter_x1)
    inter_h = max(0.0, inter_y2 - inter_y1)
    inter = inter_w * inter_h
    area_a = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    area_b = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0.0


class SimpleTracker:
    def __init__(self, iou_threshold: float, max_age_seconds: float) -> None:
        self._iou_threshold = iou_threshold
        self._max_age_seconds = max_age_seconds
        self._next_id = 1
        self._tracks = []

    def update(self, detections, now):
        used_tracks = set()
        new_detections = []
        for det in detections:
            best_iou = 0.0
            best_idx = -1
            for idx, tr in enumerate(self._tracks):
                if idx in used_tracks:
                    continue
                if tr["cls"] != det["cls"]:
                    continue
                score = iou(det["bbox"], tr["bbox"])
                if score > best_iou:
                    best_iou = score
                    best_idx = idx
            if best_iou >= self._iou_threshold and best_idx >= 0:
                self._tracks[best_idx]["bbox"] = det["bbox"]
                self._tracks[best_idx]["last_seen"] = now
                used_tracks.add(best_idx)
            else:
                self._tracks.append(
                    {"id": self._next_id, "bbox": det["bbox"], "last_seen": now, "cls": det["cls"]}
                )
                new_detections.append(det)
                self._next_id += 1

        self._tracks = [
            t for t in self._tracks if (now - t["last_seen"]) <= self._max_age_seconds
        ]
        return new_detections

