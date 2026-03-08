import Foundation

@MainActor
final class NavigationController {
    let state: NavigationState
    let store: FileStore
    
    private let maxHistorySize = 100
    
    init(state: NavigationState, store: FileStore) {
        self.state = state
        self.store = store
    }
    
    var canGoBack: Bool { !state.history.isEmpty }
    
    var canGoUp: Bool {
        guard let sel = state.selection, let node = store.findNode(by: sel) else { return false }
        return sel != store.rootNode?.id && node.parent != nil
    }
    
    func goBack() {
        if let last = state.history.popLast() {
            state.isNavigatingBack = true
            state.selection = last
        }
    }
    
    func goUp() {
        if let sel = state.selection, let node = store.findNode(by: sel), let parent = node.parent {
            setSelection(parent.id)
        }
    }
    
    func setSelection(_ id: FileSystemNode.ID?) {
        let oldValue = state.selection
        
        if let old = oldValue, !state.isNavigatingBack {
            state.history.append(old)
            if state.history.count > maxHistorySize {
                state.history.removeFirst(state.history.count - maxHistorySize)
            }
        }
        
        state.isNavigatingBack = false
        state.selection = id
        
        if let newId = id, let node = store.findNode(by: newId) {
            let ancestors = node.ancestorIdsFromRoot
            state.expandedIds.formUnion(ancestors)
            
            Task {
                await store.shallowScan(node: node)
            }
        }
    }
    
    func setExpandedIds(_ ids: Set<FileSystemNode.ID>) {
        state.expandedIds = ids
    }
}
