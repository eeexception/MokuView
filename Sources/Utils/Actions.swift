import Foundation
import AppKit

struct Actions {
    static func showInFinder(node: FileSystemNode) {
        if let url = node.url {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    static func copyPath(node: FileSystemNode) {
        if let url = node.url {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.path, forType: .string)
        }
    }
    
    static func copyPath(nodes: [FileSystemNode]) {
        let paths = nodes.compactMap { $0.url?.path }.joined(separator: "\n")
        guard !paths.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
    }
    
    static func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to scan"
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
