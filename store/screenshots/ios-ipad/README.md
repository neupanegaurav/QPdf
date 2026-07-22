iPad 13" screenshots — 2752 × 2064 landscape (or 2064 × 2752 portrait).

`01-home.png` is real: captured 2026-07-23 from the iOS simulator build running
on an iPad Pro 13-inch (M5), landscape, with the status bar overridden to
Apple's 9:41. It satisfies Apple's minimum of one screenshot for this display
size, and `tool/publish_asc.py screenshots` uploads it as
APP_IPAD_PRO_3GEN_129.

More would sell the app better — the document view and the Fill & Sign sheet, as
in the Android tablet set. Capturing those needs the simulator driven past the
Home screen, and `simctl` has no tap command: use Xcode's UI test runner, `idb`,
or grant Terminal Accessibility permission so AppleScript can click. A plain
`xcrun simctl launch` only ever lands on Home.

Note: the other booted iPad (A6D8CC94) shows a blocking "Apple Account
Verification" alert containing a real email address. Clear it with
`xcrun simctl spawn <udid> launchctl kickstart -k system/com.apple.SpringBoard`
before capturing, and never ship a frame containing it.
