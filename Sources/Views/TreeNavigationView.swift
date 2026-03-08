import SwiftUI

struct TreeNavigationView: View {
    let rootNode: FileSystemNode
    let store: FileStore
    @Binding var selection: FileSystemNode.ID?
    @Binding var expandedIds: Set<FileSystemNode.ID>
    let onVolumeSelect: (URL) -> Void
    let onRequestTrash: ([FileSystemNode]) -> Void
    
    @State private var volumes: [VolumeInfo] = []
    
    var body: some View {
        List(selection: $selection) {
            Section("Current Scan") {
                RecursiveTreeView(node: rootNode, parentSize: rootNode.size, store: store, selection: $selection, expandedIds: $expandedIds, onRequestTrash: onRequestTrash)
            }
            
            Section("Connected Disks") {
                ForEach(volumes) { volume in
                    VolumeRowView(volume: volume)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onVolumeSelect(volume.url)
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear {
            volumes = VolumesHelper.getMountedVolumes(provider: store.provider)
        }
    }
}

struct VolumeRowView: View {
    let volume: VolumeInfo
    
    var body: some View {
        HStack {
            Image(systemName: "externaldrive.fill")
                .foregroundColor(.accentColor)
                .font(.title3)
            VStack(alignment: .leading, spacing: UIConstants.General.smallSpacing) {
                Text(volume.name).bold().lineLimit(1)
                
                HStack {
                    Text("\(ByteCountFormatter.formattedSize(volume.availableCapacity)) free / \(ByteCountFormatter.formattedSize(volume.totalCapacity))")
                    Spacer()
                    Text(String(format: "%.0f%%", volume.percentageFree * 100))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * CGFloat(1.0 - volume.percentageFree))
                    }
                }
                .frame(height: UIConstants.Tree.progressBarHeight)
                .cornerRadius(UIConstants.Tree.cornerRadius)
            }
            Spacer()
        }
        .padding(.vertical, UIConstants.Tree.rowVerticalPaddingVolume)
    }
}

struct RecursiveTreeView: View {
    let node: FileSystemNode
    let parentSize: Int64
    let store: FileStore
    @Binding var selection: FileSystemNode.ID?
    @Binding var expandedIds: Set<FileSystemNode.ID>
    let onRequestTrash: ([FileSystemNode]) -> Void
    
    var body: some View {
        Group {
            if node.isDirectory, let children = node.children, !children.isEmpty {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedIds.contains(node.id) },
                        set: { isExpanded in
                            if isExpanded { expandedIds.insert(node.id) }
                            else { expandedIds.remove(node.id) }
                        }
                    )
                ) {
                    ForEach(children) { child in
                        RecursiveTreeView(node: child, parentSize: node.size, store: store, selection: $selection, expandedIds: $expandedIds, onRequestTrash: onRequestTrash)
                    }
                } label: {
                    TreeRowContent(node: node, parentSize: parentSize)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = node.id }
                        .contextMenu { contextMenuItems(for: node) }
                }
                .tag(node.id)
            } else {
                TreeRowContent(node: node, parentSize: parentSize)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = node.id }
                    .tag(node.id)
                    .contextMenu { contextMenuItems(for: node) }
            }
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for n: FileSystemNode) -> some View {
        Button("Show in Finder") { Actions.showInFinder(node: n) }
        Button("Copy file path") { Actions.copyPath(node: n) }
        Divider()
        Button("Move to Trash", role: .destructive) {
            onRequestTrash([n])
        }
    }
}

struct TreeRowContent: View {
    let node: FileSystemNode
    let parentSize: Int64
    
    var body: some View {
        HStack {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(node.isDirectory ? .blue : .primary)
            Text(node.name)
                .lineLimit(1)
            Spacer()
            Text(ByteCountFormatter.formattedSize(node.size))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress Bar representing percentage of parent
            let percentage = parentSize > 0 ? (Double(node.size) / Double(parentSize)) : 0.0
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(percentage))
                }
            }
            .frame(width: UIConstants.Tree.progressBarWidth, height: UIConstants.Tree.progressBarHeight)
            .cornerRadius(UIConstants.Tree.cornerRadius)
        }
        .padding(.vertical, UIConstants.Tree.rowVerticalPadding)
    }
}
