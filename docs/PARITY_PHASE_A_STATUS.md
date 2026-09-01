# Parity Phase A status

Updated: 2026-08-27

## Current increment: shared command surface

Implemented:

- A typed, searchable registry for document-level commands.
- Workflow categories for Output, Enhance, Organize, Protect, Sign, and Inspect.
- A searchable All tools dialog on desktop/tablet and a large bottom sheet on
  phones.
- One command dispatch path replacing the editor's duplicated string-based
  overflow-menu routing.
- `Cmd/Ctrl+K` access to All tools when a document is open.
- Unit coverage for command uniqueness, aliases, and category search.
- Widget coverage for opening and searching the adaptive tools surface.
- Independent in-memory sessions for up to eight open documents.
- Scrollable desktop/tablet tabs with active and modified indicators.
- Tab switching without recreating controllers, preserving each document's
  editor state and undo history.
- Duplicate-open detection that focuses the existing document tab.
- Tab-specific Save/Discard/Cancel handling and safe controller disposal.
- `Cmd/Ctrl+W` close-tab and `Cmd/Ctrl+Tab` tab-navigation shortcuts.
- Widget coverage proving that controllers survive tab switches and that tabs
  close independently.
- Persistent restoration of local document paths and the active tab after an
  application restart. Missing files are skipped safely, non-local temporary
  documents are not persisted, and the surviving session is rewritten.
- Unit coverage for session serialization/clearing and widget coverage proving
  that multiple tabs reopen in order with the saved active document selected.
- Adaptive Read, Edit, Comment, Fill & Sign, Organize, Convert, and Protect
  workspace navigation: a persistent rail on desktop and a scrollable bottom
  mode bar on phone/tablet.
- Read, Edit, and Comment modes arm the matching editor behavior; Fill & Sign,
  Organize, and Protect enter their existing focused workflows. Convert stays
  explicitly unavailable until the Phase C conversion engine is implemented.
- The editor dependency's contextual strip remains the single properties
  surface for selected tools and objects, avoiding conflicting duplicate state.
- Responsive editor chrome hides desktop-only actions at phone widths and
  keeps Save and All tools reachable without horizontal overflow.
- Widget coverage verifies desktop mode switching, phone mode navigation, and
  the absence of phone-width overflow.
- Desktop File, Edit, and categorized Tools menus use the same command
  registry and dispatch path as All tools. Menu state follows live Undo, Redo,
  and Save availability.
- `Cmd/Ctrl+Z` and `Cmd/Ctrl+Shift+Z` now join the existing open, save,
  save-as, print, tools, close-tab, and tab-navigation shortcuts.
- Right-clicking the document workspace exposes selection, content editing,
  comments, Fill & Sign, and All tools without bypassing workspace state.
- Native desktop drag-and-drop accepts several PDFs at once, validates their
  file headers, opens them as independent tabs, shows a visible drop target,
  and starts macOS security-scoped access when Finder supplies a bookmark.
- Focused widget coverage exercises desktop menus, a real secondary mouse
  click, shared command dispatch, and a synthetic native PDF drop.
- View menu controls now drive real per-tab viewer state: fit page, fit width,
  actual size, view-only left/right rotation, vertical continuous reading, and
  horizontal continuous reading. Viewer controllers are owned and disposed
  with their document sessions.
- Printing now accepts validated page expressions such as `1-3, 5, 8-10` and
  physical odd/even subsets, creates a standalone selected-page PDF, then
  hands it to the system print panel for paper, orientation, scaling, duplex,
  grayscale, pages-per-sheet, booklet, and poster capabilities.
- Unit coverage proves range de-duplication, boundary failures, empty-subset
  handling, and structural reopen of selected-page print output.

This registry is the source for the upcoming native menus, contextual actions,
customizable quick tools, and command palette. Document-edit tools supplied by
the editor package will be incorporated into the registry during the adaptive
mode-rail increment.

## Next increments

1. Drag-and-drop merge, insert, and reorder targets.
2. Single-page/two-page, full-screen, presentation, and view-history modes.
3. QPdf-owned cross-platform imposition controls where system print panels do
   not supply pages-per-sheet, booklet, poster, or grayscale.

## Phase exit gate

Parity Phase A remains in progress. It is complete only after the full exit
gate in `ACROBAT_REPLACEMENT_ROADMAP.md` passes on each primary platform.
