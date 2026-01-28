import csv
from datetime import datetime, timedelta, timezone
from pathlib import Path


class HourlyCounter:
    def __init__(self, interval_minutes: int, tz_offset_minutes: int) -> None:
        self.roi1_persons = 0
        self.roi1_two_wheelers = 0
        self.roi2_persons = 0
        self.roi2_two_wheelers = 0
        self._interval = max(1, interval_minutes)
        self._tz = timezone(timedelta(minutes=tz_offset_minutes))
        self.current_bucket = self._bucket_label(self._now())

    def _now(self):
        return datetime.now(self._tz)

    def _bucket_label(self, dt: datetime) -> str:
        minute = (dt.minute // self._interval) * self._interval
        start = dt.replace(minute=0, second=0, microsecond=0) + timedelta(minutes=minute)
        end = start + timedelta(minutes=self._interval)
        return f"{start.strftime('%Y-%m-%d %H:%M:%S')} - {end.strftime('%H:%M:%S')} IST"

    def rollover_if_needed(self, csv_path: str):
        bucket_now = self._bucket_label(self._now())
        if bucket_now == self.current_bucket:
            return
        write_hourly_counts(
            csv_path,
            self.current_bucket,
            self.roi1_persons,
            self.roi1_two_wheelers,
            self.roi2_persons,
            self.roi2_two_wheelers,
        )
        self.current_bucket = bucket_now
        self.roi1_persons = 0
        self.roi1_two_wheelers = 0
        self.roi2_persons = 0
        self.roi2_two_wheelers = 0


def write_hourly_counts(
    csv_path: str,
    bucket_label: str,
    roi1_persons: int,
    roi1_two_wheelers: int,
    roi2_persons: int,
    roi2_two_wheelers: int,
):
    path = Path(csv_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.exists()
    with path.open("a", newline="") as csvfile:
        writer = csv.writer(csvfile)
        if write_header:
            writer.writerow(
                [
                    "time_bucket",
                    "roi1_persons",
                    "roi1_two_wheelers",
                    "roi2_persons",
                    "roi2_two_wheelers",
                ]
            )
        writer.writerow(
            [
                bucket_label,
                roi1_persons,
                roi1_two_wheelers,
                roi2_persons,
                roi2_two_wheelers,
            ]
        )

