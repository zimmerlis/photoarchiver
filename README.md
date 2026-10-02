# photoarchiver

Archive backed-up Synology Moments media into dated photo and video folders.

## Script

`archive_moments.sh` recursively scans the directory containing the script, including device folders such as `iPhone` and `SM-S908B`. Use `-folder NAME` to scan only one direct subfolder, for example `-folder SM-S908B`. Supported photos are moved to `/volume2/photo/YYYY/YYYY-MM-DD` and videos to `/volume2/video/YYYY/YYYY-MM-DD`, using embedded capture dates when available and the file modification date otherwise.

After each successful move, the original folder gets or updates a `photo_archive_readme.txt` or `video_archive_readme.txt`, so the markers remain where the media used to be. Each line lists the destination path without the volume prefix and the size in bytes, for example `/photo/2026/2026-10-02/image.jpg (123456 bytes)`. Identical files already in the destination are removed from the source and listed in the manifest; files with a conflicting name are moved with a numbered suffix. Bash is required. ExifTool is optional: when available, the script uses embedded capture dates; otherwise, it warns and uses file modification dates.

Run it manually on the NAS first:

```sh
/bin/bash /volume1/homes/gigi/Drive/Moments/Mobile/archive_moments.sh
```

To test only one device folder:

```sh
/bin/bash /volume1/homes/gigi/Drive/Moments/Mobile/archive_moments.sh -folder SM-S908B
```

For a nightly run at 02:15, add this cron entry for a user that can read the source and write to both destinations:

```cron
15 2 * * * /bin/bash /volume1/homes/gigi/Drive/Moments/Mobile/archive_moments.sh -folder SM-S908B >> /volume1/homes/gigi/Drive/Moments/Mobile/archive_moments.log 2>&1
```

On Synology, the Task Scheduler in DSM is an alternative to editing the system crontab directly. Verify that the task's environment includes the directory containing `exiftool` in `PATH`.
