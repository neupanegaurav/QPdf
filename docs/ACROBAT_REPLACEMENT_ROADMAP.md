# QPdf Acrobat-replacement roadmap

Updated: 2026-08-27

## Goal

Make QPdf the default PDF application for ordinary personal and office work
first, then add professional, collaborative, and specialist workflows without
making the common interface feel like a catalog of rarely used tools.

This roadmap starts after the repository's existing Phase 0-3 work. To avoid
confusing the two plans, the new releases are named **Parity Phase A-H**.

## Product rules

1. Prioritize by user frequency: open/read, edit, fill/sign, comment, convert,
   scan, organize, protect, and print come before specialist tools.
2. A phase is complete only when saved output reopens correctly in QPdf and at
   least two independent PDF viewers.
3. Keep documents local by default. Cloud, collaboration, and AI are optional
   services, never requirements for opening or editing a PDF.
4. Keep one obvious primary action on every screen. Less-used commands belong
   in `More`, the command palette, or a categorized All tools view.
5. Desktop, tablet, and phone use the same concepts but not the same toolbar
   density.
6. Do not expose a feature as complete when it only works on sample files.

## Shared layout target

### Home

- Primary cards: Open PDF, Fill & Sign, Scan, Convert, Combine.
- Continue section: recent and pinned documents with recovery state.
- All tools: grouped into Edit, Convert, Organize, Protect, Sign, Scan, and
  Advanced. It must be searchable and customizable.
- Desktop also supports drag-and-drop and a compact batch-work area.

### Document workspace

- Top bar: document name, undo/redo, search, share, save, and overflow.
- Mode rail: Read, Edit, Comment, Fill & Sign, Organize, Convert, Protect.
- Left panel on desktop/tablet: thumbnails, bookmarks, search, comments,
  attachments, and layers.
- Contextual properties panel appears only for the selected tool or object.
- Phone uses a bottom mode bar and sheets instead of permanent side panels.
- Desktop supports tabs, multiple windows, menus, shortcuts, right-click, and
  a command palette.

### Interaction standards

- Remember recent tools and per-tool properties without changing documents.
- Every destructive action has preview, undo where technically possible, and
  a clear Save as copy option.
- Show task progress, cancellation, failed-file details, and recovery actions.
- Keyboard, screen reader, 200% text scale, touch, mouse, and stylus workflows
  are release gates rather than later polish.

## Parity Phase A - Reliability and workspace foundation

**Purpose:** make the already-implemented feature set comfortable enough to be
the user's default PDF application.

Implementation progress is tracked in
[PARITY_PHASE_A_STATUS.md](PARITY_PHASE_A_STATUS.md).

### Features

- Document tabs on desktop and tablet; multiple windows on desktop.
- Drag-and-drop open, merge, insert, and reorder.
- Pin, rename, remove, and reveal recent documents.
- Restore tabs and unsaved recovery sessions after restart.
- Full menu bar, right-click menus, command palette, and documented shortcuts.
- Customizable quick tools and remembered tool properties.
- Fit page, fit width, actual size, continuous, single-page, and two-page views.
- Page history, previous/next view, full-screen reading, and presentation mode.
- Complete print dialog for ranges, current view, odd/even pages, scaling,
  multiple pages per sheet, booklet, poster, comments, and grayscale.

### Layout delivery

- Replace the growing editor overflow menu with the mode rail and contextual
  properties panel.
- Add the searchable All tools surface while retaining the five primary Home
  actions.

### Exit gate

- A user can make QPdf the OS default, open several documents, edit, print,
  save, close, reopen, and recover a forced-crash session on each primary
  platform without losing work.

## Parity Phase B - Daily editing, navigation, and review

**Purpose:** close the most visible gaps in routine office PDF work.

### Features

- Create, rename, nest, reorder, import, and export bookmarks.
- Create and edit internal links, web links, email links, named destinations,
  page labels, and initial-view settings.
- Add, inspect, save, and remove file attachments safely.
- Complete comments panel with author, type, page, status, date, filters,
  replies, resolve/reopen, and comment search.
- Import/export comments using XFDF/FDF and generate a comment summary.
- Alignment guides, snapping, multi-select, group, lock, arrange, duplicate,
  distribute, and precise position/size controls for edited objects.
- Clipboard image/text paste and copy with formatting where possible.
- Find-and-replace for editable text with an explicit scope and preview.
- Background, header/footer, watermark, crop, page-number, and Bates templates.

### Layout delivery

- Add persistent Bookmarks, Comments, and Attachments tabs to the side panel.
- Add a compact object properties inspector on desktop/tablet and a bottom
  properties sheet on phone.

### Exit gate

- A multi-reviewer annotated document can be edited, filtered, summarized,
  exported, reopened, and exchanged with Acrobat without losing standard
  comments, bookmarks, links, or attachments.

## Parity Phase C - Create and convert

**Purpose:** eliminate the need to keep Acrobat only for file conversion.

### Features

- Export PDF to DOCX, XLSX, PPTX, HTML, TXT, EPUB, JPEG, PNG, and TIFF.
- Create PDF from images, text, clipboard, scanned pages, and supported Office
  documents.
- Export selected pages, images, tables, or detected document regions.
- Preserve reading order, tables, lists, headings, links, and images where the
  source structure permits it.
- Provide a conversion-quality report and warn when OCR, fonts, or complex
  layout make the result approximate.
- Batch conversion with output naming, collision, and folder rules.
- Platform share extensions and `Print to QPdf`/virtual-printer integration
  where supported.

### Layout delivery

- Add a Convert workspace with source preview, output format, page range,
  quality controls, and a side-by-side result preview.
- Add Convert as a primary Home card only after DOCX and image export meet the
  exit gate.

### Exit gate

- The conversion corpus meets documented semantic and visual thresholds for
  born-digital, scanned, table-heavy, multilingual, and mixed-layout PDFs.

## Parity Phase D - Scan, OCR, batch, and automation

**Purpose:** make repetitive and paper-document workflows faster than Acrobat.

### Features

- Continuous scanning with automatic capture and page-boundary detection.
- Perspective correction, dewarp, deskew, rotation, background cleanup,
  shadow/stain/punch-hole removal, and color modes.
- Receipt, ID card, whiteboard, book, and document scan presets.
- Downloadable offline OCR languages, confidence display, correction UI, and
  searchable-image versus editable-text output modes.
- Guided Actions builder for ordered operations across files and folders.
- Preset actions for OCR, optimize, sanitize, redact, convert, watermark,
  protect, PDF/A, and archive.
- Watched folders on desktop, a local CLI, and a versioned local automation API.
- Job queue with pause, cancel, retry, per-file reports, and resumable recovery.

### Layout delivery

- Desktop Home gains a batch drop zone and job drawer.
- Scan uses a capture-first phone interface; cleanup and page management follow
  as separate steps instead of crowding the camera screen.

### Exit gate

- A 100-file mixed batch can be interrupted and resumed without corrupting
  input files, and OCR text geometry remains correct after every page rotation.

## Parity Phase E - Forms, signatures, accessibility, and compliance

**Purpose:** support legal, government, education, and regulated office work.

### Features

- Automatic form-field detection plus date, image, button, barcode, and
  certificate-signature fields.
- Field alignment, duplication, tab order, validation, calculations,
  conditional behavior, and FDF/XFDF/XML/JSON/CSV data exchange.
- A restricted, opt-in form scripting runtime; unsupported XFA remains clearly
  detected and read-only unless a safe implementation is selected.
- Import PFX/P12 identities and use OS certificate stores, secure hardware, and
  PKCS#11 where available.
- Chain validation, OCSP/CRL checks, RFC 3161 timestamps, certification
  signatures, and PAdES B-B/B-T/B-LT/B-LTA.
- Tag-tree and reading-order editors, table/header repair, alt text, document
  language, artifacts, form tooltips, and accessibility preview.
- PDF/UA validation with assisted fixes and exportable compliance reports.
- Broader PDF/A conversion and validation profiles.

### Layout delivery

- Form authoring, signature validation, and accessibility repair each receive a
  focused workspace; they are not added as more editor overflow items.
- Trust status always distinguishes document integrity, certificate validity,
  identity trust, and post-signing changes.

### Exit gate

- Independent validators accept the promised PDF/A, PDF/UA, and PAdES levels;
  a qualified accessibility reviewer completes a representative manual audit.

## Parity Phase F - Optional QPdf Cloud

**Purpose:** replace Adobe's sharing, review, synchronization, and signature
request services without weakening the local-first application.

### Features

- Optional account with end-to-end encrypted document sync and version history.
- Share links with view/comment/download permissions, expiry, and revocation.
- Real-time comments, mentions, assignments, review deadlines, and notifications.
- Signature requests with recipient order, reminders, templates, bulk send,
  audit trail, signer authentication, and completion certificates.
- Web forms and a browser-only review/signing experience for recipients.
- Google Drive, OneDrive, Dropbox, Box, and SharePoint connectors.
- Organization controls: SSO, SCIM, retention, regional storage, audit export,
  and administrative policy.

### Layout delivery

- Local files and cloud workspaces are visibly distinct.
- Share and Request signatures use guided flows with a final recipient and
  permission review before anything is sent.

### Exit gate

- Third-party security review, privacy review, tenant-isolation tests, restore
  drills, deletion verification, abuse controls, and regional legal review pass.

## Parity Phase G - Optional document intelligence

**Purpose:** provide Acrobat Studio-style assistance while preserving trust.

### Features

- Summaries and question answering with clickable page-level citations.
- Multi-document workspaces containing PDFs, Office files, and web sources.
- Contract clause, obligation, deadline, and risk extraction.
- Table and structured-data extraction to CSV/XLSX.
- Natural-language PDF actions that always preview the exact planned commands.
- Local model option for suitable devices and explicit opt-in cloud processing.
- Per-workspace retention, training, sharing, and deletion controls.

### Layout delivery

- Assistant lives in a collapsible source-aware panel, not over the page.
- Answers display citations, confidence/limitations, and a clear distinction
  between source text and generated interpretation.

### Exit gate

- Citation accuracy, prompt-injection resistance, destructive-action approval,
  privacy, and representative quality evaluations pass before public release.

## Parity Phase H - Specialist and legacy workflows

**Purpose:** serve users who genuinely need the long tail of Acrobat Pro.

### Features

- PDF/X profiles, output intents, separations, ink coverage, color conversion,
  transparency preview, printer marks, bleed/trim boxes, and preflight fixes.
- Measurement calibration, distance/perimeter/area tools, layers, and geospatial
  information.
- PDF Portfolios and advanced embedded-file management.
- Opt-in, sandboxed playback for supported audio, video, and 3D content.
- Large collection indexes and enterprise search catalogs.

### Exit gate

- Each specialist module has a named customer use case, a dedicated corpus,
  security boundaries, and an owner. Do not delay common-workflow releases for
  this phase.

## Release sizing and priority

| Phase | User value | Dependency/risk | Suggested release treatment |
| --- | --- | --- | --- |
| A | Very high | Medium | Next release |
| B | Very high | Medium | Next major release |
| C | Very high | High | Incremental format-by-format releases |
| D | High | High | Desktop and mobile tracks may ship separately |
| E | Medium/high | Very high | Professional beta before general release |
| F | High for teams | Very high | Separate optional service |
| G | Optional | Very high | Separate opt-in module/service |
| H | Specialist | Very high | Demand-led modules |

## Workstream requirements for every phase

Every feature must include, in the same phase:

- engine/API contract and graceful unsupported-state behavior;
- adaptive desktop, tablet, and phone interaction design;
- keyboard and accessibility behavior;
- undo/redo and safe-save behavior where applicable;
- corpus fixtures, save/reopen tests, independent-viewer checks, hostile-input
  tests, and performance/memory budgets;
- localization-ready strings, help text, and migration/recovery behavior;
- platform support table and honest limitations in release notes.

## Immediate next backlog

Start Parity Phase A in this order:

1. Extract the editor's document commands into a searchable command registry.
2. Build the adaptive mode rail and contextual properties panel from that
   registry without removing existing commands.
3. Add desktop/tablet document tabs and persist/restore the session.
4. Add drag-and-drop, menu, context-menu, and command-palette entry points.
5. Complete display modes and the advanced print workflow.
6. Run keyboard, screen-reader, crash-recovery, save/reopen, and multi-document
   performance gates before beginning Phase B.
