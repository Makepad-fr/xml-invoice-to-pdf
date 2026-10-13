#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p build
xcrun swiftc macos/Convert.swift -o build/xml-to-pdf
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
cp tests/fixtures/demo.xml "$test_dir/invoice.xml"
printf '<broken>' > "$test_dir/invalid.xml"
build/xml-to-pdf --quiet "$project_dir/index.html" "$test_dir/invoice.xml"
test -s "$test_dir/invoice.pdf"
original_hash="$(shasum -a 256 "$test_dir/invoice.pdf")"
if build/xml-to-pdf --quiet "$project_dir/index.html" "$test_dir/invalid.xml" "$test_dir/invoice.xml"; then
  echo 'Expected failure for invalid XML' >&2; exit 1
fi
test ! -e "$test_dir/invalid.pdf"
test -s "$test_dir/invoice (1).pdf"
test "$original_hash" = "$(shasum -a 256 "$test_dir/invoice.pdf")"
echo 'PASS native PDF generation, malformed XML, mixed batch continuation and no overwrite'
