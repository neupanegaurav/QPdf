# QPdf branding

## Product name

The user-facing product name is **QPdf**. The Dart package remains
`openpdf_studio`; mobile and desktop bundle/application identifiers use
`studio.gaurav.qpdf`.

## App icon

The production master is:

`apps/openpdf_studio/assets/branding/qpdf-icon-master.png`

It is an opaque, full-bleed square with important artwork inside the central safe area. Platform masks supply their own corner shape.

Regenerate every platform icon after changing the master:

```sh
cd apps/openpdf_studio
dart run flutter_launcher_icons
```

Generated targets:

- Android mipmap launcher icons
- iPhone and iPad AppIcon set
- macOS AppIcon set
- Windows `.ico`
- web favicon, standard icons, and maskable icons
- Linux packaging icon at `linux/runner/resources/qpdf.png`

The master was produced with the built-in image-generation workflow using the user-supplied reference artwork. The final prompt preserved the PDF document, pencil, signature stroke, and red `PDF` badge; removed the exterior white margin; extended the blue background to every edge; and constrained the mark to the central platform-safe area.
