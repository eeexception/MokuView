import Foundation
import Observation

@Observable
@MainActor
final class PieChartState {
    var selectedAngle: Int64?
    var listSelection = Set<FileSystemNode.ID>()
    var includeFreeSpace = false
}
