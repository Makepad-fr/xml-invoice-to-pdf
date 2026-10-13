import AppKit
import WebKit
import PDFKit

// Uses the same local HTML parser/renderer as the browser edition.
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
            let name = String(data: try JSONSerialization.data(withJSONObject: [file.lastPathComponent]), encoding: .utf8)!
            let js = """
            const bytes=Uint8Array.from(atob('\(data.base64EncodedString())'),c=>c.charCodeAt(0));
            const source=decode(bytes.buffer);
            if(/<!DOCTYPE|<!ENTITY/i.test(source)) throw Error('DTD and entity declarations are not allowed.');
            const doc=new DOMParser().parseFromString(source,'application/xml');
            if(doc.getElementsByTagName('parsererror').length) throw Error('Malformed XML.');
            if(doc.getElementsByTagName('*').length>30000) throw Error('Too many XML elements.');
            const rows=fields(doc.documentElement),model=parseInvoice(doc);
            document.querySelector('#appendix').checked=false;
            if(!document.querySelector('#native-print')){const style=document.createElement('style');style.id='native-print';style.textContent='@media print{body{font-size:13px}.parties{margin:20px 0}.notice{margin-top:14px;padding-top:8px}}';document.head.append(style);}
            render(model,null,\(name)[0],rows);
            const pdfs=Array.from(doc.getElementsByTagName('*')).filter(n=>n.localName==='EmbeddedDocumentBinaryObject'&&n.getAttribute('mimeCode')==='application/pdf');
            return pdfs.length===1 ? pdfs[0].textContent.replace(/\\s/g,'') : '';
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
                        self.printPDF(file)
                    }
                }
            }
        } catch { failed(file, error) }
    }
    func printPDF(_ file: URL) {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 595.28, height: 841.89)
        info.topMargin = 42.5; info.bottomMargin = 42.5; info.leftMargin = 36.85; info.rightMargin = 36.85
        info.isHorizontallyCentered = false; info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = temporary
        let operation = view.printOperation(with: info)
        operation.showsPrintPanel = false; operation.showsProgressPanel = false
        operation.runModal(for: window, delegate: self, didRun: #selector(printed(_:success:context:)), contextInfo: Unmanaged.passRetained(PrintJob(file: file, temp: temporary)).toOpaque())
    }
    @objc func printed(_ operation: NSPrintOperation, success: Bool, context: UnsafeMutableRawPointer?) {
        guard let context = context else { return }
        let job = Unmanaged<PrintJob>.fromOpaque(context).takeRetainedValue()
        defer { try? FileManager.default.removeItem(at: job.temp) }
        do {
            guard success, let pdf = PDFDocument(url: job.temp), pdf.pageCount > 0 else { throw problem("PDF rendering failed.") }
            try save(Data(contentsOf: job.temp), beside: job.file)
            next()
        } catch { failed(job.file,error) }
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
final class PrintJob { let file: URL; let temp: URL; init(file: URL,temp: URL){self.file=file;self.temp=temp} }
var args = Array(CommandLine.arguments.dropFirst())
let quiet = args.first == "--quiet"
if quiet { args.removeFirst() }
guard args.count >= 2 else { fputs("Usage: xml-to-pdf [--quiet] index.html invoice.xml ...\n",stderr); exit(2) }
let converter = Converter(html: URL(fileURLWithPath: args.removeFirst()), files: args.map {URL(fileURLWithPath:$0)}, quiet: quiet)
converter.start()
NSApplication.shared.run()
