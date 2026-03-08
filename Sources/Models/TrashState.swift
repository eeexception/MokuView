import Foundation
import Observation

@Observable
@MainActor
final class TrashState {
    var showTrashConfirmation = false
    var nodesToTrash: [FileSystemNode] = []
    var trashError: String?
    var showTrashError = false
}
