# QPdf physical-device acceptance plan

Run every section with one simple form PDF, one password-protected PDF, one
20+ page office PDF, and one camera-scanned PDF. Do not use sensitive documents
during beta testing.

## Android phone and tablet

1. Install the signed debug APK with `adb install -r app-debug.apk`.
2. Launch QPdf and verify Home, Quick actions, and Recent documents.
3. Choose **Fill & Sign**, open the form, enter text, toggle a check box, add a
   handwritten signature, Save As, close, and reopen in another viewer.
4. Open `QPdf-Smart-Fill-Flat-Test.pdf`, choose **Smart Fill**, review the eight
   native flat-field detections, create them, populate values, and Save As.
5. Open `QPdf-Smart-Fill-Scanned-Test.pdf` and choose **Smart Fill**. Confirm
   QPdf offers **Run OCR**, complete the private OCR step, choose **Smart Fill**
   again, review the raster detections, populate them, and Save As.
6. Mark text and part of an image for redaction. Confirm Save is blocked until
   **Apply Securely**, review the image-only warning, apply, Save As, and verify
   the covered content is not searchable or selectable in another viewer.
7. Share a PDF into QPdf while it is closed, then repeat while it is running.
8. Scan two pages, reorder them, run OCR, search the recognized text, and save.
9. Rotate the tablet, use split-screen, print/share, force-stop during an edit,
   relaunch, and restore recovery data.

## iPhone and iPad

1. Install a Development/TestFlight build signed for the test device.
2. Repeat the Fill & Sign sequence using Files-provider open and Save As.
3. Repeat the secure-redaction sequence and independently inspect the saved
   image-only copy.
4. Open a PDF from Files while QPdf is closed and while it is already running.
5. Scan/OCR, AirPrint/share, portrait/landscape, iPad split view, Apple Pencil
   ink/signature, background/foreground, and recovery.

## Desktop and web

- Open a PDF from the OS, verify keyboard navigation, print, Save/Save As,
  recent files, dark mode, HiDPI, watermarks, Bates numbering, comparison, and
  large-document memory behavior.
- On web, verify open/edit/download and that native-only Scan/OCR actions are
  absent or clearly unavailable.

## Acceptance rule

Record device/OS, document fixture, steps, outcome, crash log, and saved output.
A platform is beta-ready only after every critical workflow passes twice and
the saved result reopens in an independent PDF viewer.
