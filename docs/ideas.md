# Ideas

Possible features, looked into but not planned yet. Findings checked on
2026-09-29.

## The route network in one file, or bundled

The planner reads 91 route files, 555 KB as the service sends them (it
does not compress). Compacted into one file the whole network takes
145 KB, 39 KB gzipped: faster to load, and small enough to ship with the
APK, so the planner works on first use without its 92 requests. A
bundled copy ages between releases, so the background refresh stays.
