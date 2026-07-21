import 'dart:io';

/// Whether a path returned when the user picks a document can be safely
/// overwritten in place.
///
/// On desktop the picker returns a durable filesystem path that is the user's
/// real file, so an atomic overwrite reaches the document they opened. On
/// Android and iOS `file_picker` returns a transient cache copy of a
/// `content://`/document-provider file; writing back to that copy never
/// reaches the original, so those platforms must export through the system
/// "save a copy" sheet instead.
bool get supportsInPlacePickedSave =>
    !(Platform.isAndroid || Platform.isIOS);
