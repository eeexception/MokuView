import Foundation

@MainActor
final class TrashController {
    let state: TrashState
    let store: FileStore
    let navigationState: NavigationState // Needed to reset selection after deletion
    
    init(state: TrashState, store: FileStore, navigationState: NavigationState) {
        self.state = state
        self.store = store
        self.navigationState = navigationState
    }
    
    func requestTrash(nodes: [FileSystemNode]) {
        state.nodesToTrash = nodes
        state.showTrashConfirmation = true
    }
    
    func confirmTrash() {
        var errors: [String] = []
        var parentsToRefresh = Set<FileSystemNode>()
        
        for node in state.nodesToTrash {
            if let parent = node.parent {
                parentsToRefresh.insert(parent)
            }
            let result = store.deleteNode(node)
            if case .failure(let error) = result {
                errors.append("\(node.name): \(error.localizedDescription)")
            } else if navigationState.selection == node.id {
                navigationState.selection = node.parent?.id
            }
        }
        state.nodesToTrash = []
        
        for parent in parentsToRefresh {
            store.refreshNode(parent)
        }
        
        if !errors.isEmpty {
            state.trashError = errors.joined(separator: "\n")
            state.showTrashConfirmation = false
            state.showTrashError = true
        } else {
            state.showTrashConfirmation = false
        }
    }
    
    func cancelTrash() {
        state.nodesToTrash = []
        state.showTrashConfirmation = false
    }
    
    func dismissTrashError() {
        state.trashError = nil
        state.showTrashError = false
    }
}
