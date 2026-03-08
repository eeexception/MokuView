import SwiftUI
import Charts

struct PieChartAnalysisView: View {
    let node: FileSystemNode
    @Bindable var state: PieChartState
    let controller: PieChartController
    let onToggleSidebar: () -> Void
    @Binding var selection: FileSystemNode.ID?
    let onRequestTrash: ([FileSystemNode]) -> Void
    
    var body: some View {
        VStack {
            if let children = node.children, !children.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: UIConstants.General.smallSpacing) {
                        Button(action: onToggleSidebar) {
                            Image(systemName: "sidebar.left")
                        }
                        .buttonStyle(.plain)
                        .font(UIConstants.IconButton.font)
                        .foregroundColor(UIConstants.IconButton.foregroundColor)
                        .frame(
                            width: UIConstants.IconButton.frameSize,
                            height: UIConstants.IconButton.frameSize,
                            alignment: .center
                        )
                        .help("Toggle Sidebar")
                        
                        Toggle("Show Free Space", isOn: Binding(
                            get: { state.includeFreeSpace },
                            set: { controller.toggleFreeSpace($0) }
                        ))
                    }
                    Spacer()
                }
                .padding(.bottom, UIConstants.General.smallSpacing)
                
                let displayChildren = controller.displayChildren(for: node)
                let totalChartSize = controller.totalChartSize(for: node)
                
                Chart(displayChildren) { child in
                    if child.name == "Free Space" {
                        SectorMark(
                            angle: .value("Size", child.size),
                            innerRadius: .ratio(UIConstants.PieChart.innerRadiusRatio),
                            angularInset: UIConstants.PieChart.angularInset
                        )
                        .foregroundStyle(Color.green.opacity(0.8))
                        .annotation(position: .overlay) {
                            if child.size > Int64(Double(totalChartSize) / UIConstants.PieChart.smallSliceThreshold) {
                                Text(child.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        SectorMark(
                            angle: .value("Size", child.size),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Name", child.name))
                        .annotation(position: .overlay) {
                            if child.size > (totalChartSize / 20) {
                                Text(child.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .chartLegend(position: .trailing)
                .chartAngleSelection(value: Binding(
                    get: { state.selectedAngle },
                    set: { controller.setAngleSelection($0) }
                ))
                .onTapGesture {
                    if let newSelection = controller.handleAngleSelection(node: node) {
                        selection = newSelection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                
                Table(of: FileSystemNode.self, selection: Binding(
                    get: { state.listSelection },
                    set: { controller.setListSelection($0) }
                )) {
                    TableColumn("Name") { child in
                        HStack(spacing: UIConstants.Tree.iconTextSpacing) {
                            if child.name == "Free Space" {
                                Image(systemName: "circle.dashed")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: child.isDirectory ? "folder.fill" : "doc.text.fill")
                                    .foregroundColor(child.isDirectory ? .blue : .primary)
                            }
                            Text(child.name)
                                .foregroundColor(child.name == "Free Space" ? .green : .primary)
                        }
                    }
                    TableColumn("Logical Size") { child in
                        Text(ByteCountFormatter.formattedSize(child.logicalSize))
                            .monospacedDigit()
                    }
                    TableColumn("Allocated") { child in
                        Text(ByteCountFormatter.formattedSize(child.size))
                            .monospacedDigit()
                    }
                    TableColumn("Files") { child in
                        Text("\(child.filesCount)")
                            .monospacedDigit()
                    }
                    TableColumn("Folders") { child in
                        Text("\(child.foldersCount)")
                            .monospacedDigit()
                    }
                    TableColumn("% of Parent") { child in
                        let percentage = totalChartSize > 0 ? (Double(child.size) / Double(totalChartSize)) : 0.0
                        Text(String(format: "%.1f %%", percentage * 100))
                            .monospacedDigit()
                    }
                    TableColumn("Attributes") { child in
                        if child.name == "Free Space" {
                            Text("-")
                        } else {
                            Text(child.formattedPermissions)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                } rows: {
                    ForEach(displayChildren) { child in
                        TableRow(child)
                    }
                }
                .contextMenu(forSelectionType: FileSystemNode.ID.self) { items in
                    if items.count == 1, let firstId = items.first, let child = displayChildren.first(where: { $0.id == firstId }), child.name != "Free Space" {
                        Button("Show in Finder") {
                            Actions.showInFinder(node: child)
                        }
                        Button("Copy file path") {
                            Actions.copyPath(node: child)
                        }
                        Divider()
                        Button("Move to Trash", role: .destructive) {
                            onRequestTrash([child])
                        }
                    } else if items.count > 1 {
                        let selectedNodes = displayChildren.filter { items.contains($0.id) && $0.name != "Free Space" }
                        Button("Copy \(selectedNodes.count) item paths") {
                            Actions.copyPath(nodes: selectedNodes)
                        }
                        Divider()
                        Button("Move \(selectedNodes.count) items to Trash", role: .destructive) {
                            onRequestTrash(selectedNodes)
                        }
                    }
                } primaryAction: { items in
                    if items.count == 1, let firstId = items.first, let child = displayChildren.first(where: { $0.id == firstId }) {
                        if child.isDirectory && child.name != "Free Space" {
                            selection = child.id
                        }
                    }
                }
            } else {
                Text(node.isDirectory ? "Empty Directory" : "File: \(ByteCountFormatter.formattedSize(node.size))")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
