import Foundation
let fm=FileManager.default
let home=fm.homeDirectoryForCurrentUser
let workflow=home.appendingPathComponent("Library/Services/Convert to PDF.workflow")
let contents=workflow.appendingPathComponent("Contents")
try fm.createDirectory(at:contents.appendingPathComponent("Resources"),withIntermediateDirectories:true)
func write(_ object: [String:Any], _ name: String) throws {
    try PropertyListSerialization.data(fromPropertyList:object,format:.xml,options:0).write(to:contents.appendingPathComponent(name),options:.atomic)
}
let command="exec \"$HOME/Library/Application Support/XML to PDF/xml-to-pdf\" \"$HOME/Library/Application Support/XML to PDF/index.html\" \"$@\""
let service:[String:Any]=[
 "NSMenuItem":["default":"Convert to PDF"],"NSMessage":"runWorkflowAsService",
 "NSSendFileTypes":["public.xml"],"NSRequiredContext":["NSApplicationIdentifier":"com.apple.finder"]
]
try write(["CFBundleIdentifier":"io.github.xml-invoice-to-pdf.finder","CFBundleName":"Convert to PDF","CFBundleVersion":"1.0","NSServices":[service]],"Info.plist")
let action:[String:Any]=[
 "ActionBundlePath":"/System/Library/Automator/Run Shell Script.action",
 "ActionName":"Run Shell Script", "BundleIdentifier":"com.apple.RunShellScript",
 "AMActionVersion":"2.0.3","CFBundleVersion":"2.0.3","Class Name":"RunShellScriptAction",
 "ActionParameters":["COMMAND_STRING":command,"inputMethod":1,"shell":"/bin/zsh","source":"","CheckedForUserDefaultShell":true],
 "AMAccepts":["Container":"List","Optional":true,"Types":["com.apple.cocoa.string"]],
 "AMProvides":["Container":"List","Types":["com.apple.cocoa.string"]],
 "AMParameterProperties":["COMMAND_STRING":[:],"inputMethod":[:],"shell":[:],"source":[:]],
 "UUID":UUID().uuidString,"InputUUID":UUID().uuidString,"OutputUUID":UUID().uuidString,
 "Application":["Automator"],"CanShowWhenRun":false,"CanShowSelectedItemsWhenRun":false,"arguments":[:]
]
try write(["AMDocumentVersion":"2","AMApplicationVersion":"2.10","AMApplicationBuild":"523",
 "actions":[["action":action]],"connectors":[:],
 "workflowMetaData":["workflowTypeIdentifier":"com.apple.Automator.servicesMenu","serviceInputTypeIdentifier":"com.apple.Automator.fileSystemObject","serviceOutputTypeIdentifier":"com.apple.Automator.nothing","serviceProcessesInput":0,"serviceApplicationBundleID":"com.apple.finder","serviceApplicationPath":"/System/Library/CoreServices/Finder.app"]],"Resources/document.wflow")
print("Installed Finder Quick Action: \(workflow.path)")
