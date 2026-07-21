# Vendored dependencies

## pdf_manipulator 2.1.4

QPdf vendors the Dart API and build-hook layer from `pdf_manipulator` 2.1.4
under its upstream MIT license. The large Rust source fallback, examples, and
tests are intentionally not duplicated. Native and web engines are downloaded
from the upstream v2.1.4 release and verified against the unchanged SHA-256
manifest in `lib/src/hook/asset_hashes.dart`.

QPdf carries one compatibility patch in `hook/build.dart`: upstream publishes
only signed/hash-pinned `.a` archives for iOS, while Flutter 3.44 requests a
bundled dynamic asset. The hook verifies the published archive and links its
objects into the requested `@rpath` dylib with Xcode before registration.
Android, macOS, Windows, Linux, and web behavior is otherwise unchanged.

Upstream: <https://github.com/whuppi/pdf_manipulator>
