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

This registry is the source for the upcoming native menus, contextual actions,
customizable quick tools, and command palette. Document-edit tools supplied by
the editor package will be incorporated into the registry during the adaptive
mode-rail increment.

## Next increments

1. Persist and restore open document paths and the active tab after restart.
2. Adaptive mode rail and contextual properties panel.
3. Desktop menu bar, right-click entry points, and expanded shortcuts.
4. Drag-and-drop open, merge, insert, and reorder.
5. Reading/display modes and advanced printing.

## Phase exit gate

Parity Phase A remains in progress. It is complete only after the full exit
gate in `ACROBAT_REPLACEMENT_ROADMAP.md` passes on each primary platform.
