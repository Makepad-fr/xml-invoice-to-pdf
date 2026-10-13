# XML to PDF

A minimal, black-and-white tool to recover the original PDF embedded in a UBL or
CII invoice XML. It downloads the **unchanged PDF bytes**: no converter labels,
footers, watermarks, added pages, print dialog, or reconstructed layout.

**[Open the converter](https://makepad-fr.github.io/xml-invoice-to-pdf/)**

## Use

Drop XML files onto the page, select an invoice, and click **Export PDF** for a
direct download. The preview shows the original attachment. If an XML contains
multiple PDFs, select the correct attachment; the tool does not guess which is
the invoice. **Export all (ZIP)** preserves each selected PDF as its own unchanged
file, with unique filenames. A failed or unresolved file blocks batch export so
nothing is silently omitted; remove it or resolve its attachment selection first.
Up to 50 XML files, each up to 5 MB. Browsers without inline PDF viewing can still
download the file.

An XML with no embedded PDF has no original visual layout to recover. Export is
unavailable for that file, with an explanation in the UI. No approximate invoice
is silently substituted. External PDF links are never fetched.

For offline use, download `index.html` and open it in Chrome or Firefox. The PDF
validator is bundled inline; no runtime downloads, account, server, telemetry or
browser storage are required. GitHub serves the application when you visit Pages;
invoice processing stays inside your browser. The Content Security Policy blocks
outbound connections. Browser extensions and cloud-synced save folders are outside
its control.

## Formats

- UBL Invoice / CreditNote (`Invoice-2` / `CreditNote-2` namespaces, including UBL 2.1)
  with an embedded `application/pdf` attachment.
- CII CrossIndustryInvoice (`:100` namespace) with an embedded PDF attachment.
- Standalone Factur-X PDF is already readable; PDF-to-XML extraction is not included.
- XML-only invoices, proprietary XML, and external attachment URLs cannot provide
  an exact original through this tool.

PDFs are structurally checked using the bundled MIT-licensed pdf-lib 1.17.1 and
then downloaded without re-serialization, preserving metadata, forms, signatures,
attachments and supplier formatting. This does not verify authenticity, legal
compliance, signatures, or whether an attachment's figures match its enclosing XML.
Malformed or encrypted PDFs are rejected. Keep the original XML.

## Development

The self-contained application is `index.html`. Browser tests need Node.js:

```sh
npm ci
npx playwright install chromium
npm test
```

Rebuild the inlined validator after dependency changes with
`node scripts/embed-pdf-validator.cjs`. Tests verify byte equality of actual
downloads, ZIP integrity, no print calls, bad inputs and zero outgoing requests.

Tests use fictional fixtures. Never commit real invoices, generated PDFs, contact
details, credentials or account exports. CI runs on GitHub-hosted Ubuntu.

## License

MIT. See [LICENSE](LICENSE).

## macOS Finder Quick Action

Requires macOS 12+ and Apple's Command Line Tools (`xcode-select --install`).
Clone the organization repository and install the Finder action:

```sh
git clone https://github.com/Makepad-fr/xml-invoice-to-pdf.git
cd xml-invoice-to-pdf
bash macos/install.sh
```

Select one or more XML files in Finder, then right-click → **Quick Actions** or
**Services** → **Convert to PDF**. No browser file selection or upload is needed.
The action appears for XML file types; eligibility as an invoice is checked when
it runs. Unsupported/malformed XML gets an error rather than a misleading PDF.

PDFs are saved beside their XMLs. Existing files are never overwritten: repeated
conversions use ` (1)`, ` (2)`, etc. A single valid embedded PDF is preserved
unchanged; XML without an embedded PDF is rejected rather than reconstructed. Multiple
PDF attachments require selection in the browser. All processing is local. Original XMLs remain untouched. A mixed
batch continues past failures and reports them. PDFs are created with user-only
permissions. The installer builds locally for your Mac; no signing bypass needed.

If the action is hidden, enable it under System Settings → Keyboard → Keyboard
Shortcuts → Services → Files and Folders. macOS may ask permission to access the
selected folder. Finder menus vary by macOS version. The Finder action preserves the original PDF bytes just like the browser.

Installed files:
- `~/Library/Services/Convert to PDF.workflow`
- `~/Library/Application Support/XML to PDF/`

To uninstall, remove those two items in Finder. Re-run the installer to update.
