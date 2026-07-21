# QPdf Phase 2 Status - Strong free editor

Updated: 2026-07-20

## Implemented

- Native Android/iOS document scanning with camera/gallery capture and crop.
- Private on-device OCR with verified model management and a selectable text
  layer; web builds isolate the native runtime and clearly report the limit.
- Secure redaction with irreversible confirmation and a conservative image-only
  full-document rewrite that prevents hidden text or source pixels remaining.
- Existing page-content selection, text replacement, image replacement, font
  substitution limits, and added text/image content.
- Headers/footers and page numbers, diagonal text watermarks, zero-padded
  Bates numbering, and editable document information.
- AES-256 password add/change/remove controls with selectable user permissions.
- Structure-preserving image optimization and hidden-metadata removal with
  explicit full-rewrite/signature warnings.
- Page merge, split/extract, insert, delete, duplicate, rotate, crop, and
  reorder workflows.
- Text/page-structure comparison with an explicit limitation notice.
- Print, share, images-to-PDF, and scan-to-PDF.

## Verification

- Watermark and Bates output reopen successfully and are covered by tests.
- The repository-owned forensic redaction gate burns a repeated known secret
  on every page, then proves it absent from Poppler extraction, decoded page
  streams, and physical PDF bytes. It also verifies a single compact revision,
  preserved surrounding text, and a solid rendered fill.
- A separate regression test first proves that ordinary partial image redaction
  retains the original image object, then proves QPdf's secure flatten removes
  that source image hash and the old object graph.
- A deterministic 29 MB scan-style fixture passes the render time/memory gate.
- Native OCR is conditionally isolated so web and Wasm builds remain valid.
- Camera permissions and minimum platform versions are configured.

## Explicit limits

- Web OCR and camera scanning are not enabled; native apps provide them.
- Comparison aligns pages by position and is not a legal/forensic visual diff.
- Arbitrary Word-like paragraph reflow, every conversion format, and repair of
  every malformed PDF remain outside the first deployment candidate.
- Secure redaction deliberately produces an image-only document. Search,
  selectable text, forms, links, comments, bookmarks, accessibility structure,
  metadata, and signatures are removed; the app warns before applying it.
