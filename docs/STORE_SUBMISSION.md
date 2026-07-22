# QPdf store submission pack

Updated: 2026-07-22 · App version `0.1.0+1` · ID `studio.gaurav.qpdf` (Android,
iOS, macOS)

Everything below is ready to copy and paste. Sections marked **YOU** need a
browser and the account owner's login; nothing in an API can do them.

---

## 1. Status board

| Step | State |
| --- | --- |
| Android upload keystore (`qpdf-upload-keystore.jks`) | Done — QPdf-specific, not NearU's |
| Signed release AAB | Done — `CN=Gaurav Neupane`, SHA-256 `64:5C:D8:52:0F:A6:96:09:1D:2E:F0:61:B1:96:BF:A1:17:2F:CE:4B:8A:2E:75:D3:9C:B1:95:53:B8:9A:4D:37` |
| Apple Bundle ID `studio.gaurav.qpdf` | Done — registered 2026-07-22, ASC id `X56L8H43B8`, platform UNIVERSAL |
| iOS/macOS export-compliance + privacy plist keys | Done — see §6 |
| **Play Console app record** | **YOU** — §3 |
| **Play: first AAB upload (browser only)** | **YOU** — §3 |
| **Play: grant `claude-play-publisher@nearu-play-publisher.iam.gserviceaccount.com`** | **YOU** — §3 |
| **App Store Connect app record** | **YOU** — §4 |
| Hosted privacy-policy URL | **YOU** — §5 (content already written) |
| Screenshots + feature graphic | **YOU** — §7 |
| iOS archive/upload | Blocked — this Mac has Command Line Tools only, no full Xcode |

Keystore backup is not optional. `apps/openpdf_studio/android/key.properties`
and `android/qpdf-upload-keystore.jks` are gitignored, so git is **not** a
backup. Lose them and you can never ship an update to the same Play listing
without a Google key-reset request. Copy both to a password manager or an
encrypted drive today.

---

## 2. Build size — the number Play actually cares about

The AAB on disk is 168 MB. That is **not** what users download.

| Piece | Size |
| --- | --- |
| AAB file on disk | 167.5 MB |
| … of which debug symbols + ProGuard map | 85.1 MB (stripped by Play, never shipped) |
| **Actual arm64-v8a download** | **31.4 MB** |
| On-device install footprint | 72.2 MB |

Play's per-download limit is 200 MB, so there is a wide margin. The biggest
shipped library is `libpdf_oxide.so` at 12.9 MB compressed — that is the PDF
engine itself, not an optional extra.

---

## 3. Google Play — **YOU**

1. <https://play.google.com/console> → **Create app**
   - App name: `QPdf - PDF Reader & Editor`
   - Default language: English (United States)
   - App or game: **App** · Free or paid: **Free**
   - Tick both declarations (developer program policies, US export laws).
2. **Set up your app** → work through the tasks with the answers in §8.
3. **Testing → Internal testing → Create new release**
   - Play App Signing: **accept the default** (Google holds the app signing key;
     your `qpdf-upload-keystore.jks` stays the upload key).
   - Upload `apps/openpdf_studio/build/app/outputs/bundle/release/app-release.aab`.
   - Release name: `0.1.0 (1)`. Release notes: see §8.
4. **Users and permissions → Invite new users**
   - Email: `claude-play-publisher@nearu-play-publisher.iam.gserviceaccount.com`
   - App permissions: QPdf → **Release to testing tracks**, **Release to
     production**, **View app information**.
5. Tell me when steps 1–4 are done. From then on I can run
   `store-upload-kit/.venv/bin/python store-upload-kit/android/play.py upload
   <aab> --track internal` and `… promote --from internal --to production
   --rollout 0.2` without you touching the browser.

Google requires that very first bundle to arrive through the browser; the API
returns `404 Package not found` until the listing exists.

---

## 4. App Store Connect — **YOU**

The Bundle ID is already registered, so the picker will offer it.

1. <https://appstoreconnect.apple.com/apps> → **+** → **New App**
   - Platforms: **iOS** (add macOS later as a separate platform on the same record)
   - Name: `QPdf - PDF Reader & Editor` (must be globally unique; if taken, use
     `QPdf: PDF Reader & Editor`)
   - Primary language: English (U.S.)
   - Bundle ID: `studio.gaurav.qpdf — QPdf`
   - SKU: `qpdf-ios-001`
   - User access: Full Access
2. Fill the listing from §8, then App Privacy from §9.
3. Build upload needs a Mac with **full stable Xcode**. This machine has only
   `/Library/Developer/CommandLineTools`, and macOS 27 / Xcode 27 beta would
   trigger an `ITMS-90111` rejection anyway. Options: install stable Xcode from
   the App Store on a non-beta macOS, or use Xcode Cloud (an
   `ios/Runner.xcodeproj/xcshareddata/xcodecloud/` folder already exists in this
   repo).
4. Once a build exists, `store-upload-kit/.venv/bin/python
   store-upload-kit/ios/asc.py builds <app-id>` reports processing state.

---

## 5. Privacy policy — needs a public URL

Both stores reject a submission without a reachable privacy-policy page.
`docs/PRIVACY.md` already has accurate content. Fastest hosting:

1. Push this repo to <https://github.com/neupanegaurav/QPdf> (nothing is pushed
   yet — `main` is 3 commits ahead of `origin/main`).
2. GitHub → **Settings → Pages → Source: Deploy from a branch → main / /docs**.
3. The URL becomes `https://neupanegaurav.github.io/QPdf/PRIVACY` — use that in
   both stores.

Accurate one-line summary for the store forms: *QPdf processes documents on the
device. It has no account, no analytics SDK, and no advertising SDK, and it
does not upload the PDFs you open.*

The only outbound request is the optional OCR model download from
`https://github.com/ben-milanko/dart-pdf/releases/download/ocr-models-v1/`,
verified against a pinned SHA-256 before use. Page content is never attached to
that request.

---

## 6. Platform config fixed for this submission

- `ios/Runner/Info.plist`
  - `ITSAppUsesNonExemptEncryption = false` — QPdf uses only standard exempt
    cryptography (HTTPS plus the platform's hash/signature algorithms). Without
    this key **every** TestFlight and App Store upload stalls on the manual
    export-compliance question. Confirm the declaration matches your reading of
    the export rules before your first submission.
  - `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription` —
    the document scanner pulls in `DKImagePickerController`, which links the
    Photos framework. A binary that links Photos without these strings is
    rejected at review, or crashes the first time the picker opens.
- `macos/Runner/Info.plist`
  - `LSApplicationCategoryType = public.app-category.productivity` — required by
    the Mac App Store.
  - `CFBundleDocumentTypes` for `com.adobe.pdf` — lets macOS offer QPdf as a PDF
    handler, matching the iOS configuration.
  - `ITSAppUsesNonExemptEncryption = false`, same reason as iOS.

Earlier in this branch: Android `INTERNET`/`CAMERA` moved into the `main`
manifest, macOS release entitlements granted user-selected file read-write,
`network.client`, and `print`. See `docs/COMPLETION_AUDIT.md`.

---

## 7. Graphics you still have to produce

| Asset | Spec | Store |
| --- | --- | --- |
| App icon | 512 × 512 PNG, 32-bit, no alpha | Play |
| Feature graphic | 1024 × 500 PNG/JPEG | Play |
| Phone screenshots | 2–8, 16:9–9:16, 320–3840 px | Play |
| Tablet screenshots | optional but strongly recommended | Play |
| iPhone 6.9" | 1290 × 2796 or 1320 × 2868 | App Store |
| iPad 13" | 2064 × 2752 | App Store |

`apps/openpdf_studio/assets/branding/qpdf-icon-master.png` is the icon source.
Screenshots need the app running: an Android emulator or the Samsung SM-T860
that already passed device testing is the quickest route — open a sample PDF and
capture Home, the page view, Fill & Sign, page organiser, and redaction.

---

## 8. Listing copy — paste as-is

**App name (30 char max)**
`QPdf - PDF Reader & Editor`

**Short description (80 char max)** — 79 chars
`Read, annotate, fill, sign, scan and OCR PDFs privately, right on your device.`

**Full description (4000 char max)**

```
QPdf is a local-first PDF workspace for phone, tablet and desktop. Your
documents stay on your device.

READ AND SEARCH
• Fast page rendering with text selection and in-document search
• Open PDFs straight from Files, email or any app that shares them

ANNOTATE AND MARK UP
• Highlight, underline, strike through and draw freehand
• Add notes and type text anywhere on a page

FILL AND SIGN
• Fill interactive PDF forms, including checkboxes and dropdowns
• Draw a signature or apply a cryptographic digital signature
• Create form fields of your own

ORGANISE PAGES
• Reorder, rotate, delete, extract and merge pages
• Combine several PDFs into one
• Add page numbers

CREATE AND CONVERT
• Build a PDF from photos
• Scan paper with the camera
• Add a searchable text layer with on-device OCR — pages are never uploaded

PROTECT
• Secure redaction produces an image-only copy and strips searchable text,
  interactive content, metadata and existing signatures
• PDF/UA and PDF/A accessibility and archiving audits

PRIVATE BY DESIGN
No account. No advertising SDK. No analytics SDK. QPdf does not upload the PDFs
you open. The only network request is an optional one-time OCR model download,
verified against a published checksum.

Free, with no subscription and no watermark.
```

**Category**: Productivity · **Tags**: PDF, documents, scanner, e-signature

**Apple subtitle (30 char max)**
`Edit, sign & scan PDFs offline`

**Apple keywords (100 char max)** — 98 chars
`pdf,editor,reader,annotate,sign,signature,scan,scanner,ocr,form,fill,merge,split,compress,document`

**Apple promotional text (170 char max)**
`A complete PDF workspace that keeps your documents on your device. Read, annotate, fill forms, sign, scan, OCR and redact — free, with no account and no watermark.`

**Release notes (0.1.0)**
```
First release.
• Read, search and annotate PDFs
• Fill and sign forms, type text anywhere on a page
• Reorder, merge, extract and rotate pages
• Build PDFs from photos, or scan with the camera
• On-device OCR adds searchable text without uploading pages
• Secure redaction and PDF/UA + PDF/A audits
```

**Support URL**: `https://github.com/neupanegaurav/QPdf/issues`
**Marketing URL**: `https://github.com/neupanegaurav/QPdf`

---

## 9. Questionnaire answers

### Play — Data safety

- Does your app collect or share any of the required user data types? **No**
- Is all user data encrypted in transit? **Yes** (only the OCR model fetch
  leaves the device, over HTTPS)
- Do you provide a way for users to request data deletion? **Not applicable —
  no data is collected.** Documents live in the user's own file storage and are
  deleted by deleting the file.
- Data collected: **none.** Recent-file history (path, display name, stable ID,
  last-opened time for up to 12 files) and the crash-recovery journal are stored
  only in app-private storage and never leave the device, which Play classes as
  not collected.

### Play — Content rating (IARC)

Category **Utility**. Answer *No* to violence, sexuality, language, controlled
substances, gambling, user-generated content sharing, and location sharing.
Expected outcome: Everyone / PEGI 3.

### Play — other declarations

- Ads: **No ads**
- App access: **All functionality is available without special access** (no
  login)
- Target audience: **18+** (a productivity tool, not designed for children);
  answer *No* to "appeals to children"
- Government app: **No** · Financial features: **None**
- News app: **No** · COVID-19 contact tracing: **No**
- Data deletion URL: not required, since nothing is collected

### Apple — App Privacy

Select **Data Not Collected**. Camera and Photos are used only in direct
response to a user action and nothing is transmitted, so no data type needs to
be disclosed.

### Apple — Age rating

Answer *None* to every content question. Expected result: **4+**.

### Apple — Export compliance

`ITSAppUsesNonExemptEncryption = false` is now in the plist, so App Store
Connect will not ask per upload. This declares that QPdf uses only exempt
cryptography (HTTPS and standard platform hash/signature algorithms).

---

## 10. What I can automate once the two app records exist

```bash
KIT=store-upload-kit
# Android — upload and promote without the browser
$KIT/.venv/bin/python $KIT/android/play.py status
$KIT/.venv/bin/python $KIT/android/play.py upload \
  apps/openpdf_studio/build/app/outputs/bundle/release/app-release.aab --track internal
$KIT/.venv/bin/python $KIT/android/play.py promote --from internal --to production --rollout 0.2

# Apple — inspect the account and uploaded builds
$KIT/.venv/bin/python $KIT/ios/asc.py apps
$KIT/.venv/bin/python $KIT/ios/asc.py bundleids
$KIT/.venv/bin/python $KIT/ios/asc.py builds <app-id>
```

`store-upload-kit/` holds live publishing credentials for both accounts. It has
its own `.gitignore` of `*`, and the repo's root `.gitignore` blocks `*.p8`,
service-account JSON and `secrets/`. Verified untracked. Never commit it.
