# QPdf Phase 3 Status - Professional feature set

Updated: 2026-07-20

## Implemented

- Drawn signatures and locally generated self-signed cryptographic signatures,
  with clear trust semantics and post-signing modification protection.
- Signature inspection verifies byte ranges, cryptographic integrity,
  post-signing updates, embedded timestamps and PAdES level, while keeping
  cryptographic validity distinct from certificate-chain trust.
- Form authoring, field rename/type/style controls, filling, and flattening in
  the integrated editor.
- Existing-content text and image editing with explicit PDF-format limits.
- Structural PDF/UA and PDF/A standards audit with rule-level findings, plus
  PDF/A-1 conversion that deliberately removes forbidden encryption.
- True redaction, document comparison, metadata editing, Bates numbering, and
  repeatable headers/footers/watermarks.
- Reflow reading support and keyboard-accessible Material controls supplied by
  the editor and application shell.

## Explicit product boundaries

- A self-signed certificate is not a government/qualified electronic identity.
  Timestamp authorities, LTV, enterprise trust stores, and hardware tokens
  require external trust services and are not silently simulated.
- The audit reports machine-checkable PDF/UA and PDF/A structure; it does not
  claim human accessibility certification or universal PDF/A conversion.
- Cloud sync, collaboration, SSO, server automation, and office-format
  conversion are separate products. QPdf's first deployment stays local-first.

## Phase 3 exit

The scoped professional feature set is implemented for beta. External trust,
store signing, independent-viewer compatibility, adversarial security review,
and physical-device acceptance remain release gates in the release checklist.
