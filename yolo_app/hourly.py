import csv
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
import ntplib
from time import ctime

log = logging.getLogger(__name__)


class HourlyCounter:
    def __init__(self, interval_minutes: int, tz_offset_minutes: int, csv_base_path: str) -> None:
        self.roi1_persons = 0
        self.roi1_two_wheelers = 0
        self.roi2_persons = 0
        self.roi2_two_wheelers = 0
        self._interval = 1  # Always 1 minute for CSV updates
        self._tz = timezone(timedelta(minutes=tz_offset_minutes))
        self.csv_base_path = csv_base_path
        self.current_date = None
        self.current_csv_path = None
        self.current_bucket = self._bucket_label(self._now())
        self._update_csv_path()

    def _get_network_time(self):
        """Get time from NTP server (India servers preferred), fallback to system time"""
        ntp_servers = ['in.pool.ntp.org', 'asia.pool.ntp.org', 'pool.ntp.org']
        for server in ntp_servers:
            try:
                client = ntplib.NTPClient()
                response = client.request(server, version=3, timeout=3)
                ntp_time = datetime.fromtimestamp(response.tx_time, tz=timezone.utc)
                # Convert to configured timezone (IST = UTC+5:30)
                return ntp_time.astimezone(self._tz)
            except Exception as e:
                log.debug("NTP server %s failed: %s", server, e)
                continue
        # Fallback to system time if all NTP servers fail
        log.warning("All NTP servers failed, using system time")
        return datetime.now(self._tz)
    
    def _now(self):
        return self._get_network_time()
    
    def _update_csv_path(self):
        """Update CSV path based on current date (India time)"""
        current_date_str = self._now().strftime('%Y-%m-%d')
        if self.current_date != current_date_str:
            self.current_date = current_date_str
            base_path = Path(self.csv_base_path)
            # Create daily CSV filename: detections_YYYY-MM-DD.csv (e.g., detections_2026-01-28.csv)
            daily_filename = f"detections_{current_date_str}.csv"
            self.current_csv_path = base_path.parent / daily_filename
            log.info("New daily CSV file created: %s", self.current_csv_path)

    def _bucket_label(self, dt: datetime) -> str:
        # For 1-minute intervals, use exact minute
        start = dt.replace(second=0, microsecond=0)
        end = start + timedelta(minutes=1)
        return f"{start.strftime('%Y-%m-%d %H:%M:%S')} - {end.strftime('%H:%M:%S')} IST"

    def rollover_if_needed(self):
        """Check if time bucket changed (every minute) and update CSV path if date changed"""
        # Update CSV path if date changed
        self._update_csv_path()
        
        bucket_now = self._bucket_label(self._now())
        if bucket_now == self.current_bucket:
            return
        
        # Write counts for the completed minute
        total_persons = self.roi1_persons + self.roi2_persons
        total_two_wheelers = self.roi1_two_wheelers + self.roi2_two_wheelers
        log.info("MINUTE_SUMMARY: %s | ROI1: %d persons, %d bikes | ROI2: %d persons, %d bikes | Total: %d persons, %d bikes",
                self.current_bucket, self.roi1_persons, self.roi1_two_wheelers, 
                self.roi2_persons, self.roi2_two_wheelers, total_persons, total_two_wheelers)
        
        write_hourly_counts(
            str(self.current_csv_path),
            self.current_bucket,
            self.roi1_persons,
            self.roi1_two_wheelers,
            self.roi2_persons,
            self.roi2_two_wheelers,
        )
        
        # Reset for next minute
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
    """Write detection counts to CSV file (called every minute, file changes daily)"""
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

