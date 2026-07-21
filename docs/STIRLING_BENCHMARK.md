# Stirling-PDF benchmark for QPdf

Updated: 2026-07-19

The user selected [Stirling-PDF](https://github.com/Stirling-Tools/Stirling-PDF)
as a product reference. QPdf should adopt its task-oriented clarity, not copy
its implementation or become a thin web wrapper.

Stirling-PDF's current public documentation describes 60+ tools, stateful
processing, full page-edit history, desktop “Open with” integration, local
processing, automation, APIs, and 40+ languages. Its architecture is a
Java/TypeScript web and server platform with desktop distribution. QPdf's
different advantage is one Flutter application that installs directly on
Android, iPhone/iPad, macOS, Windows, and Linux and performs core workflows
inside the device app.

## Product mapping

| Stirling-style workflow | QPdf implementation |
| --- | --- |
| Tool dashboard | Home quick-action cards |
| Stateful file reuse | One live editor session with undo/redo and recovery |
| Recent work | Persistent Recent documents list with last-opened time |
| Sign | Primary Fill & Sign home action and persistent editor shortcut |
| Merge and organize | Merge home action plus editable thumbnail/page tools |
| Scan and OCR | Native mobile scanner plus private on-device OCR |
| Edit and annotate | Integrated content, annotation, form, and page tools |
| Protect/redact | Password open plus true apply-redaction workflow |
| Watermark/Bates/page numbering | Document actions in the editor |
| Compare | Text and page-structure comparison report |
| Local privacy | No account, ads, analytics, or document upload |

## Priority rule

Fill & Sign remains first because it is the most common user workflow. The
home screen must never bury it inside an “all tools” catalog. Secondary batch
and conversion tools can expand in categorized sections after the signed-form
workflow has passed real phone and tablet testing.

## License boundary

Stirling-PDF is open-core: its root license is MIT, with separately licensed
directories. QPdf does not import or copy Stirling code. Any future reuse must
identify the exact source path and preserve the applicable notice before code
is introduced.
