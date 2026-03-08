import SwiftUI

struct MainSplitView: View {
    let store: FileStore
    @Bindable var navigationState: NavigationState
    @Bindable var trashState: TrashState
    let navigationController: NavigationController
    let trashController: TrashController
    let pieChartController: PieChartController
    @State private var isSidebarVisible = true
    
    var body: some View {
        let selectedNode = navigationState.selection.flatMap { store.findNode(by: $0) } ?? store.rootNode ?? FileSystemNode(name: "", size: 0, isDirectory: true)
        let pathStr = selectedNode.pathFromRoot

        VStack(spacing: 0) {
            TopBarView(
                selectedNode: selectedNode,
                pathString: pathStr,
                canGoBack: navigationController.canGoBack,
                canGoUp: navigationController.canGoUp,
                onBack: {
                    navigationController.goBack()
                },
                onUp: {
                    navigationController.goUp()
                },
                onPathSubmit: { newPath in
                    Task {
                        if let node = await store.resolveNode(byPath: newPath) {
                            await MainActor.run {
                                navigationController.setSelection(node.id)
                            }
                        }
                    }
                },
                onRefresh: {
                    store.refreshNode(selectedNode)
                }
            )
            .id(navigationState.selection)

            HSplitView {
                if let r = store.rootNode, isSidebarVisible {
                    TreeNavigationView(
                        rootNode: r,
                        store: store,
                        selection: Binding(
                            get: { navigationState.selection },
                            set: { navigationController.setSelection($0) }
                        ),
                        expandedIds: Binding(
                            get: { navigationState.expandedIds },
                            set: { navigationController.setExpandedIds($0) }
                        ),
                        onVolumeSelect: { url in
                            store.startScan(url: url)
                            navigationController.setSelection(nil)
                        },
                        onRequestTrash: { nodes in
                            trashController.requestTrash(nodes: nodes)
                        }
                    )
                    .frame(
                        minWidth: UIConstants.Sidebar.minWidth,
                        idealWidth: UIConstants.Sidebar.idealWidth,
                        maxWidth: UIConstants.Sidebar.maxWidth,
                        maxHeight: .infinity
                    )
                }

                VStack(spacing: 0) {
                    if let selection = navigationState.selection,
                       let selectedNode = store.findNode(by: selection),
                       store.rootNode != nil {
                        
                        // DaisyDisk/WinDirStat behavior:
                        // - File selected → show parent folder's chart (file visible among siblings)
                        // - Empty dir (children == []) → show parent folder's chart (dir visible among siblings)
                        // - Loading dir (children == nil) → show spinner
                        // - Dir with children → show its own chart
                        let hasChildren = selectedNode.children.map { !$0.isEmpty } ?? false
                        let isLoading = selectedNode.isDirectory && selectedNode.children == nil
                        
                        let displayNode: FileSystemNode = hasChildren
                            ? selectedNode
                            : (selectedNode.parent ?? selectedNode)
                        
                        let highlightId: FileSystemNode.ID? = hasChildren ? nil : selection
                        
                        if isLoading {
                            ProgressView("Loading...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                // Immediately trigger shallowScan for this node.
                                // If NavigationController already started it, isLoading flag
                                // in ScanActor prevents duplicate I/O (thread-safe).
                                .task(id: selectedNode.id) {
                                    await store.shallowScan(node: selectedNode)
                                }
                        } else {
                            PieChartAnalysisView(
                                node: displayNode,
                                state: pieChartController.state,
                                controller: pieChartController,
                                onToggleSidebar: {
                                    isSidebarVisible.toggle()
                                },
                                selection: Binding(
                                    get: { navigationState.selection },
                                    set: { navigationController.setSelection($0) }
                                ),
                                onRequestTrash: { nodes in
                                    trashController.requestTrash(nodes: nodes)
                                }
                            )
                            .onChange(of: navigationState.selection) { _, newSelection in
                                // Highlight file or empty dir in parent folder's table
                                if let id = newSelection, let node = store.findNode(by: id) {
                                    let showInParent = !node.isDirectory || (node.children?.isEmpty == true)
                                    pieChartController.setListSelection(showInParent ? [id] : [])
                                } else {
                                    pieChartController.setListSelection([])
                                }
                            }
                            .onAppear {
                                if let id = highlightId {
                                    pieChartController.setListSelection([id])
                                }
                            }
                        }
                    } else {
                        Text("Select a folder to view analysis")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Status bar
            StatusBarView(
                isScanning: store.isScanning,
                progress: store.scanProgress,
                currentPath: store.currentScannedPath,
                filesScanned: store.totalFilesScanned,
                bytesScanned: store.totalBytesScanned,
                onCancel: {
                    store.cancelScan()
                }
            )
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(
                get: { trashState.showTrashConfirmation },
                set: { if !$0 { trashController.cancelTrash() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Move \(trashState.nodesToTrash.count > 1 ? "\(trashState.nodesToTrash.count) items" : "\"\(trashState.nodesToTrash.first?.name ?? "")\"") to Trash", role: .destructive) {
                trashController.confirmTrash()
            }
            Button("Cancel", role: .cancel) {
                trashController.cancelTrash()
            }
        } message: {
            if trashState.nodesToTrash.count == 1 {
                Text("This will move \"\(trashState.nodesToTrash.first?.name ?? "")\" to the Trash.")
            } else {
                Text("This will move \(trashState.nodesToTrash.count) items to the Trash.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { trashState.showTrashError },
            set: { if !$0 { trashController.dismissTrashError() } }
        )) {
            Button("OK") { trashController.dismissTrashError() }
        } message: {
            Text(trashState.trashError ?? "An unknown error occurred.")
        }
    }
}
