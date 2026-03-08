import SwiftUI

struct TopBarView: View {
    let selectedNode: FileSystemNode?
    let pathString: String
    let canGoBack: Bool
    let canGoUp: Bool
    let onBack: () -> Void
    let onUp: () -> Void
    let onPathSubmit: (String) -> Void
    let onRefresh: () -> Void
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        HStack(alignment: .center, spacing: UIConstants.General.mediumSpacing) {
            
            // Navigation buttons + Refresh
            HStack(spacing: UIConstants.General.smallSpacing) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                .help("Go Back")
                
                Button(action: onUp) {
                    Image(systemName: "arrow.up")
                }
                .disabled(!canGoUp)
                .help("Go Up")
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh scan")
            }
            .buttonStyle(.plain)
            .font(UIConstants.IconButton.font)
            .foregroundColor(UIConstants.IconButton.foregroundColor)
            
            // Address bar (takes all available space)
            PathTextField(
                pathString: pathString,
                onSubmit: onPathSubmit
            )
            
            // Stats
            if let node = selectedNode {
                HStack(spacing: UIConstants.General.largeSpacing) {
                    StatItem(icon: "internaldrive.fill", title: "Size", value: ByteCountFormatter.formattedSize(node.logicalSize))
                    StatItem(icon: "server.rack", title: "Allocated", value: ByteCountFormatter.formattedSize(node.size))
                    Text("Files: \(node.filesCount)").font(.subheadline).bold()
                    Text("Folders: \(node.foldersCount)").font(.subheadline).bold()
                    if let date = node.modificationDate {
                        Text("Modified: \(Self.dateFormatter.string(from: date))")
                            .font(.subheadline).bold()
                    }
                }
            }
        }
        .padding(.horizontal, UIConstants.TopBar.horizontalPadding)
        .padding(.vertical, UIConstants.TopBar.verticalPadding)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: UIConstants.General.smallSpacing) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text("\(title):").bold()
            Text(value)
        }
        .font(.subheadline)
    }
}
