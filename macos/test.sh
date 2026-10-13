#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p build
xcrun swiftc macos/Convert.swift -o build/xml-to-pdf
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
node tests/fixtures.cjs "$test_dir/invoice.xml"
node -e 'const fs=require("fs");const text=fs.readFileSync(process.argv[1],"utf8");fs.writeFileSync(process.argv[2],Buffer.from(text.match(/<cbc:EmbeddedDocumentBinaryObject[^>]*>([^<]+)/)[1],"base64"));' "$test_dir/invoice.xml" "$test_dir/expected.pdf"
printf '<broken>' > "$test_dir/invalid.xml"
cp tests/fixtures/demo.xml "$test_dir/no-original.xml"
build/xml-to-pdf --quiet "$project_dir/index.html" "$test_dir/invoice.xml"
cmp "$test_dir/invoice.pdf" "$test_dir/expected.pdf"
if build/xml-to-pdf --quiet "$project_dir/index.html" "$test_dir/invalid.xml" "$test_dir/no-original.xml" "$test_dir/invoice.xml"; then
  echo 'Expected errors for invalid XML and missing original PDF' >&2; exit 1
fi
test ! -e "$test_dir/invalid.pdf"
test ! -e "$test_dir/no-original.pdf"
cmp "$test_dir/invoice (1).pdf" "$test_dir/expected.pdf"
cmp "$test_dir/invoice.pdf" "$test_dir/expected.pdf"
echo 'PASS native exact bytes, malformed XML, missing original, mixed batch continuation and no overwrite'
