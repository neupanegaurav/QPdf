# QPdf

Flutter application repository for an offline-first PDF reader and editor targeting:

- Android
- iPhone and iPad
- macOS
- Windows
- Linux (after the first four targets are stable)
- Web (viewer and light editing only; not a launch blocker)

The product goal is an easy, Acrobat/Stirling-style workflow with a strong free
feature set and direct installation on each platform. QPdf prioritizes Home,
Recent documents, and Fill & Sign, then exposes the deeper editor tools.

The application shell uses a restrained, Apple-inspired adaptive design:
system typography, neutral grouped surfaces, generous spacing, a focused blue
accent, and a prominent Fill & Sign entry point. The same layout remains
responsive and accessible on Android, Apple, desktop, and web targets.

Start with [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).

The scoped Phase 0-3 implementation is present. See the phase status files and
[docs/DEVICE_TEST_PLAN.md](docs/DEVICE_TEST_PLAN.md) for the remaining physical
device acceptance work.

The current completion evidence and the distinction between locally test-ready
builds and public-release gates are recorded in
[docs/COMPLETION_AUDIT.md](docs/COMPLETION_AUDIT.md).

Phase 0's engine decision is recorded in [docs/ENGINE_DECISION.md](docs/ENGINE_DECISION.md), and ongoing public-MVP work is tracked in [docs/PHASE_1_STATUS.md](docs/PHASE_1_STATUS.md).

The task-dashboard direction and feature comparison with the user's
Stirling-PDF reference are recorded in
[docs/STIRLING_BENCHMARK.md](docs/STIRLING_BENCHMARK.md).

The generated compatibility corpus and verification commands are documented in [test_corpus/README.md](test_corpus/README.md).

Current device-test artifacts and platform-specific signing status are recorded
in [docs/BUILD_ARTIFACTS.md](docs/BUILD_ARTIFACTS.md).

Product naming and icon regeneration are documented in [docs/BRANDING.md](docs/BRANDING.md).

Performance targets and the large-document benchmark are documented in [docs/PERFORMANCE_BUDGETS.md](docs/PERFORMANCE_BUDGETS.md).

## Recommended product promise

> Open, read, annotate, organize, fill, sign, redact, scan, and export PDFs on all your devices. Your documents stay on your device unless you choose to share or sync them.

## Proposed delivery sequence

1. Reader and page organizer
2. Annotations, forms, drawn signatures, and reliable saving
3. True redaction, OCR, scan-to-PDF, encryption, and desktop printing
4. Existing-text and image editing
5. Certificate signatures, validation, accessibility, and professional tools
