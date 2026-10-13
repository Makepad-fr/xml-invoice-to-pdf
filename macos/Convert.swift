import AppKit
import WebKit
import PDFKit

// Validates attachments using the browser edition; never renders a replacement PDF.
final class Converter: NSObject, WKNavigationDelegate {
    let app = NSApplication.shared
    var view: WKWebView!
    var window: NSWindow!
    var files: [URL]
    let html: URL
    var failures = [String]()
    var outputs = [URL]()
    let quiet: Bool
    init(html: URL, files: [URL], quiet: Bool) {
        self.html = html; self.files = files; self.quiet = quiet
        super.init()
    }
    func start() {
        app.setActivationPolicy(.accessory)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 794, height: 1123), configuration: config)
        view.navigationDelegate = self
        window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = view
        view.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.standardizedFileURL == html.standardizedFileURL ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { next() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failures.append("Could not load the local converter: \(error.localizedDescription)"); finish()
    }
    func next() {
        guard !files.isEmpty else { finish(); return }
        let file = files.removeFirst()
        do {
            guard file.pathExtension.lowercased() == "xml" else { throw problem("Only XML files are supported.") }
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 && size <= 5 * 1024 * 1024 else { throw problem("File must be between 1 byte and 5 MB.") }
            let data = try Data(contentsOf: file)
            let js = """
            const bytes=Uint8Array.from(atob('\(data.base64EncodedString())'),c=>c.charCodeAt(0));
            const attachments=await extractOriginals(bytes.buffer);
            if(attachments.length!==1) throw Error('Multiple PDF attachments: use the browser tool to select the invoice PDF.');
            if(attachments[0].error) throw Error(attachments[0].error);
            return pdfCandidates(invoiceDocument(bytes.buffer))[0].textContent.replace(/\\s/g,'');
            """
            view.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { result in
                switch result {
                case .failure(let error): self.failed(file, error)
                case .success(let value):
                    // Preserve the existing PDF when an invoice contains exactly one valid PDF.
                    if let base64 = value as? String, !base64.isEmpty,
                       let embedded = Data(base64Encoded: base64), embedded.starts(with: Data("%PDF-".utf8)),
                       let pdf = PDFDocument(data: embedded), pdf.pageCount > 0 {
                        do {try self.save(embedded, beside: file); self.next()} catch {self.failed(file,error)}
                    } else {
                        self.failed(file, self.problem("The original PDF attachment could not be read. No substitute PDF was created."))
                    }
                }
            }
        } catch { failed(file, error) }
    }
    func save(_ data: Data, beside file: URL) throws {
        let directory = file.deletingLastPathComponent()
        let staged = directory.appendingPathComponent(".xml-to-pdf-" + UUID().uuidString)
        try data.write(to: staged, options: [.atomic])
        defer { try? FileManager.default.removeItem(at: staged) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staged.path)
        let stem = file.deletingPathExtension().lastPathComponent
        for index in 0..<1000 {
            let candidate = directory.appendingPathComponent(stem + (index == 0 ? "" : " (\(index))") + ".pdf")
            do {
                // Hard-link creation is atomic and cannot overwrite an existing file or symlink.
                try FileManager.default.linkItem(at: staged, to: candidate)
                outputs.append(candidate); print(candidate.path); return
            } catch let error as NSError {
                if FileManager.default.fileExists(atPath: candidate.path) || error.code == NSFileWriteFileExistsError { continue }
                throw error
            }
        }
        throw problem("Too many existing PDFs with this name.")
    }
    func problem(_ text: String) -> NSError { NSError(domain: "XMLtoPDF", code: 1, userInfo: [NSLocalizedDescriptionKey:text]) }
    func failed(_ file: URL, _ error: Error) {
        let nsError = error as NSError
        let detail = nsError.userInfo["WKJavaScriptExceptionMessage"] as? String ?? error.localizedDescription
        failures.append(file.lastPathComponent + ": " + detail)
        next()
    }
    func finish() {
        if !failures.isEmpty {
            let message = failures.joined(separator: "\n")
            FileHandle.standardError.write(Data((message+"\n").utf8))
            if !quiet { let alert=NSAlert(); alert.messageText="Some invoices could not be converted";alert.informativeText=message;alert.runModal() }
        }
        if !quiet && !outputs.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(outputs) }
        exit(failures.isEmpty ? 0 : 1)
    }
}
var args = Array(CommandLine.arguments.dropFirst())
let quiet = args.first == "--quiet"
if quiet { args.removeFirst() }
guard args.count >= 2 else { fputs("Usage: xml-to-pdf [--quiet] index.html invoice.xml ...\n",stderr); exit(2) }
let converter = Converter(html: URL(fileURLWithPath: args.removeFirst()), files: args.map {URL(fileURLWithPath:$0)}, quiet: quiet)
converter.start()
NSApplication.shared.run()
