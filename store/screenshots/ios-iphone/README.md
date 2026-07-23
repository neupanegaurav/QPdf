iPhone 6.9" screenshots — 1290 × 2796 or 1320 × 2868, portrait.

`01-home.png` is real: 1320 × 2868, captured 2026-07-23 from the iOS simulator
build on an iPhone 17 Pro Max, status bar overridden to Apple's 9:41. It meets
Apple's one-screenshot minimum for this display size, and
`tool/publish_asc.py screenshots` uploads it as APP_IPHONE_67.

Only the Home screen. `simctl` has no tap command, so `xcrun simctl launch`
cannot reach the document view or the Fill & Sign sheet — that needs an Xcode UI
test, `idb`, or Accessibility permission for AppleScript. See ../ios-ipad/.
