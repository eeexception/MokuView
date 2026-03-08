import Foundation
import Observation

@Observable
@MainActor
final class NavigationState {
    var selection: FileSystemNode.ID?
    var expandedIds: Set<FileSystemNode.ID> = []
    
    var history: [FileSystemNode.ID] = []
    var isNavigatingBack = false
}
