import Foundation

@MainActor
final class PieChartController {
    let state: PieChartState
    let store: FileStore
    
    init(state: PieChartState, store: FileStore) {
        self.state = state
        self.store = store
    }
    
    func toggleFreeSpace(_ include: Bool) {
        state.includeFreeSpace = include
    }
    
    func setAngleSelection(_ angle: Int64?) {
        state.selectedAngle = angle
    }
    
    func setListSelection(_ selection: Set<FileSystemNode.ID>) {
        state.listSelection = selection
    }
    
    func displayChildren(for node: FileSystemNode) -> [FileSystemNode] {
        guard let rootNode = store.rootNode else { return node.children ?? [] }
        return FreeSpaceHelper.getDisplayChildren(
            for: node,
            rootNode: rootNode,
            includeFreeSpace: state.includeFreeSpace,
            provider: store.provider
        )
    }
    
    func totalChartSize(for node: FileSystemNode) -> Int64 {
        guard let rootNode = store.rootNode else { return node.size }
        if state.includeFreeSpace, let freeBytes = FreeSpaceHelper.getVolumeFreeSpace(for: node, rootNode: rootNode, provider: store.provider) {
            return node.size + freeBytes
        }
        return node.size
    }
    
    func handleAngleSelection(node: FileSystemNode) -> FileSystemNode.ID? {
        guard let newValue = state.selectedAngle else { return nil }
        
        let children = displayChildren(for: node)
        var accumulated: Int64 = 0
        
        for child in children {
            accumulated += child.size
            if newValue <= accumulated {
                if child.isDirectory && child.name != "Free Space" {
                    state.selectedAngle = nil
                    return child.id
                }
                break
            }
        }
        
        return nil
    }
}
