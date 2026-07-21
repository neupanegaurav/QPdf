# QPdf privacy model

QPdf is local-first. Opening, rendering, editing, scanning, search, form
filling, page operations, and native OCR do not upload document content.

## Network behavior

- The optional native OCR model downloads once from its pinned release URL.
  Model files are verified against published SHA-256 hashes before use. PDF
  pages are processed locally and are not sent with that request.
- The optional portable Smart Fill model downloads only after the user confirms
  its displayed size and license. QPdf verifies the pinned byte count and
  SHA-256 before use. Inference is in-process and receives only field names,
  short labels, and required flags—not PDF bytes, page/OCR text, current or
  entered values, coordinates, or signatures.
- Print and Share run only after a direct user action and hand the current PDF
  to the operating system's selected destination.
- QPdf currently has no account, advertising SDK, analytics SDK, cloud sync,
  or document telemetry.

## Local data

- Recent-document history stores the local path, display name, stable ID, and
  last-opened time for up to 12 files.
- Crash recovery stores a source-bound journal in the application's support
  directory. It normally contains only the incremental PDF suffix; compact
  operations require a full recovery snapshot.
- Successful Save, Save As, or explicit Discard removes the matching recovery
  journal.

Before store submission this document must become a hosted privacy-policy page
and be reconciled with each store's data-safety questionnaire.
