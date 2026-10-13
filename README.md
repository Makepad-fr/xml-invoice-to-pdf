# XML to PDF

A minimal, black-and-white invoice reader. Convert UBL or CII XML to a readable PDF without uploading invoice data.

**[Open the converter](https://kaanyagci.github.io/xml-invoice-to-pdf/)**

## Use

Drop XML files onto the page, select a file to preview, and choose **Save PDF**.
Choose **Save all as one PDF** to combine valid invoices. The browser print dialog
lets you choose the destination. Enable **XML appendix** to include source fields
not displayed in the summary. Up to 50 files; 5 MB per file.

For offline use, download `index.html` and open it in Chrome or Firefox.
No installation, account, runtime libraries, server, telemetry or browser storage.
GitHub serves the application when you visit Pages; invoice processing stays
inside your browser. The app's Content Security Policy blocks outbound connections.
Browser extensions and cloud-synced save destinations are outside its control.

## Formats

- UBL Invoice / CreditNote (`Invoice-2` / `CreditNote-2` namespaces, including UBL 2.1).
- CII CrossIndustryInvoice (`:100` namespace), including Factur-X XML.
- Factur-X PDF is already readable; importing/extracting XML from PDFs is not supported.
- Proprietary XML, older CII namespaces, and arbitrary XML need a dedicated adapter.

This is a reading copy, not a certified Factur-X/PDF-A generator or a fiscal,
schema or EN 16931 validator. Amounts are copied without recalculation. Keep the
original XML. Embedded binary attachments are not reproduced in the browser PDF.
The appendix includes text fields and attributes, excluding namespace declarations
and binary payloads. Summary-only profiles may contain no invoice lines.

## Development

The buildless application is `index.html`. Only browser tests need Node.js:

```sh
npm ci
npx playwright install chromium
npm test
```

Tests use fictional fixtures. Never commit real invoices, generated PDFs, contact
details, credentials or account exports. CI runs on GitHub-hosted Ubuntu.

## License

MIT. See [LICENSE](LICENSE).

## macOS Finder Quick Action

Requires macOS 12+ and Apple's Command Line Tools (`xcode-select --install`).
Download/clone the repository, then run from its directory:

```sh
bash macos/install.sh
```

Select one or more XML files in Finder, then right-click → **Quick Actions** or
**Services** → **Convert to PDF**. No browser file selection or upload is needed.
The action appears for XML file types; eligibility as an invoice is checked when
it runs. Unsupported/malformed XML gets an error rather than a misleading PDF.

PDFs are saved beside their XMLs. Existing files are never overwritten: repeated
conversions use ` (1)`, ` (2)`, etc. A single valid embedded PDF is preserved
unchanged; otherwise a readable summary is rendered using the same HTML parser
inside native WebKit, without a server. Original XMLs remain untouched. A mixed
batch continues past failures and reports them. PDFs are created with user-only
permissions. The installer builds locally for your Mac; no signing bypass needed.

If the action is hidden, enable it under System Settings → Keyboard → Keyboard
Shortcuts → Services → Files and Folders. macOS may ask permission to access the
selected folder. Finder menus vary by macOS version. The native route uses system
print pagination, which can differ slightly from browser PDFs.

Installed files:
- `~/Library/Services/Convert to PDF.workflow`
- `~/Library/Application Support/XML to PDF/`

To uninstall, remove those two items in Finder. Re-run the installer to update.
