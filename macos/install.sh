#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
install_dir="$HOME/Library/Application Support/XML to PDF"
workflow_dir="$HOME/Library/Services/Convert to PDF.workflow"
if [[ -e "$workflow_dir" ]]; then
  existing_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$workflow_dir/Contents/Info.plist" 2>/dev/null || true)
  if [[ "$existing_id" != io.github.xml-invoice-to-pdf.finder ]]; then
    echo 'A different Convert to PDF service already exists. Rename it before installing.' >&2
    exit 1
  fi
fi
mkdir -p "$project_dir/build" "$install_dir"
xcrun swiftc "$project_dir/macos/Convert.swift" -o "$project_dir/build/xml-to-pdf"
install -m 755 "$project_dir/build/xml-to-pdf" "$install_dir/xml-to-pdf"
install -m 644 "$project_dir/index.html" "$install_dir/index.html"
xcrun swift "$project_dir/macos/Install.swift"
/System/Library/CoreServices/pbs -flush
/System/Library/CoreServices/pbs -update
printf 'Ready: Finder → select XML files → right-click → Quick Actions or Services → Convert to PDF.\n'
