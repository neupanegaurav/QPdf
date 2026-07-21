#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_pdf="$repo_root/test_corpus/generated/case-001-a4-r0-text.pdf"
secret='OPENPDF-CORPUS-TEXT'
preserved='quick brown fox'
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/qpdf-redaction.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

for command_name in dart pdftotext pdftoppm; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command_name" >&2
    exit 69
  fi
done

if [ ! -f "$source_pdf" ]; then
  echo "Generate the deterministic corpus before running this gate." >&2
  exit 66
fi

(
  cd "$repo_root/apps/openpdf_studio"
  dart run tool/create_redaction_forensic_fixture.dart \
    "$source_pdf" "$work_dir/redacted.pdf"
)

pdftotext "$work_dir/redacted.pdf" "$work_dir/redacted.txt"
if grep -F "$secret" "$work_dir/redacted.txt" >/dev/null; then
  echo "Redacted text remains extractable through Poppler." >&2
  exit 1
fi
if ! grep -F "$preserved" "$work_dir/redacted.txt" >/dev/null; then
  echo "Content outside the redaction region was unexpectedly removed." >&2
  exit 1
fi

pdftoppm -f 1 -l 1 -singlefile -r 72 -png \
  "$work_dir/redacted.pdf" "$work_dir/redacted-page" >/dev/null 2>&1

"${PYTHON:-python3}" - "$work_dir/redacted.pdf" \
  "$work_dir/redacted-page.png" "$secret" "$preserved" <<'PY'
import re
import sys
from pathlib import Path

from PIL import Image
from pypdf import PdfReader

pdf_path, image_path, secret, preserved = sys.argv[1:]
pdf_bytes = Path(pdf_path).read_bytes()
if len(re.findall(br"startxref", pdf_bytes)) != 1:
    raise SystemExit("Redacted output is not a single compact PDF revision")
if secret.encode() in pdf_bytes:
    raise SystemExit("Secret remains in the physical PDF bytes")

reader = PdfReader(pdf_path)
decoded = bytearray()
for page in reader.pages:
    contents = page.get_contents()
    if contents is not None:
        decoded.extend(contents.get_data())
if secret.encode() in decoded:
    raise SystemExit("Secret remains in a decoded page-content stream")
if preserved.encode() not in decoded:
    raise SystemExit("Expected surrounding content is absent from decoded streams")

image = Image.open(image_path).convert("RGB")
# At 72 dpi, the PDF rectangle x=20..220, y=710..755 maps to image rows
# approximately 87..132 for the 842-point A4 page.
region = image.crop((24, 91, 216, 128))
pixels = region.get_flattened_data()
black_ratio = sum(max(pixel) < 32 for pixel in pixels) / len(pixels)
if black_ratio < 0.90:
    raise SystemExit(
        f"Rendered redaction fill is incomplete: black ratio {black_ratio:.3f}"
    )

print(
    "Redaction forensic gate passed: secret absent from extracted text, "
    "decoded streams, and physical bytes; compact revision and render verified."
)
PY
