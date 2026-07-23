macOS screenshots — 1280 × 800 landscape.

Not part of the current submission: there is no Mac App Store record, and the
App Store Connect app record covers iOS only. These exist for the marketing page
and for whenever macOS is added as a platform.

`01-home.png` is the real QPdf window captured with `screencapture -l <windowid>`
— window only, never the full screen, which would carry whatever else is on the
desktop. The window is composited onto a 1280 × 800 brand canvas at native size
rather than upscaled: the app draws at 801 × 633 here, which is below the Mac App
Store's 1280 × 800 minimum, and scaling it up would only blur it.

For a larger asset (2880 × 1800), enlarge the window before capturing. Finding
the window id needs no special permission:

```python
import Quartz
opts = Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements
for w in Quartz.CGWindowListCopyWindowInfo(opts, Quartz.kCGNullWindowID):
    if "QPdf" in (w.get("kCGWindowOwnerName") or ""):
        print(w["kCGWindowNumber"], w["kCGWindowBounds"])
```

Note the macOS build has no Scan tile — there is no camera capture on desktop.
That is correct behaviour, not a broken capture.
