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
