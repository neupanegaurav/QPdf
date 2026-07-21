# QPdf app

Cross-platform Flutter shell for the QPdf reader and editor.

## Run

```sh
flutter pub get
flutter run -d chrome
```

Choose another installed Flutter device for Android, iOS, macOS, Windows, or Linux.

## Verify

```sh
flutter analyze
flutter test
flutter build web
```

The PDF UI currently uses an experimental pure-Dart adapter. Product code depends on `pdf_engine_api`; engine-specific parsing is isolated under `lib/src/engine/`.
