import Foundation

/// FileSystemNode is a reference‑type tree node representing a file or directory.
///
/// ## Threading Model
/// - All **writes** (size, children, cachedFilesCount, cachedFoldersCount, parent)
///   happen inside `ScanActor`, which serialises them through Swift actor isolation.
/// - **Reads** happen on `@MainActor` (UI) after an async hop from ScanActor.
/// - Each TaskGroup child task in `deepScan` operates on a **disjoint subtree**,
///   so two concurrent tasks never write to the same node instance.
/// - `@unchecked Sendable` is required because the class crosses actor boundaries.
///   The invariants above ensure safe concurrent access in practice.
final class FileSystemNode: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    /// Disk-allocated size in bytes (block-aligned). Used for charts, sorting, percentages.
    var size: Int64
    /// Logical (apparent) file size in bytes.
    var logicalSize: Int64
    let isDirectory: Bool
    let url: URL?
    weak var parent: FileSystemNode?

    /// File/directory modification date.
    var modificationDate: Date?
    /// POSIX permission bits (lower 12 bits of st_mode, e.g. 0o755).
    var posixPermissions: UInt16 = 0

    /// Set to `true` while `ScanActor.shallowScan` is loading children.
    /// Prevents duplicate I/O when two tasks call shallowScan on the same node.
    var isLoading: Bool = false

    // Protected by the caller holding ScanActor context
    var children: [FileSystemNode]?

    // Cached counts — populated once during scan, O(1) to read
    var cachedFilesCount: Int = 0
    var cachedFoldersCount: Int = 0

    // MARK: - Cached computed helpers

    var filesCount: Int { cachedFilesCount }
    var foldersCount: Int { cachedFoldersCount }

    /// Formats POSIX permissions as a Unix-style string, e.g. "drwxr-xr-x" or "-rw-r--r--".
    var formattedPermissions: String {
        let typeChar: Character = isDirectory ? "d" : "-"
        var result = String(typeChar)
        let bits: [(UInt16, Character)] = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x"),
        ]
        for (mask, char) in bits {
            result.append(posixPermissions & mask != 0 ? char : "-")
        }
        return result
    }

    init(id: UUID = UUID(), name: String, size: Int64 = 0, logicalSize: Int64 = 0, isDirectory: Bool, url: URL? = nil, children: [FileSystemNode]? = nil) {
        self.id = id
        self.name = name
        self.size = size
        self.logicalSize = logicalSize
        self.isDirectory = isDirectory
        self.url = url
        self.children = children
    }

    static func == (lhs: FileSystemNode, rhs: FileSystemNode) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Sample data

    static var sampleData: FileSystemNode {
        let child1 = FileSystemNode(name: "Documents", size: 10_000_000_000, logicalSize: 9_500_000_000, isDirectory: true, children: [
            FileSystemNode(name: "Work", size: 8_000_000_000, logicalSize: 7_600_000_000, isDirectory: true, children: [
                FileSystemNode(name: "ProjectA", size: 5_000_000_000, logicalSize: 4_800_000_000, isDirectory: true, children: [
                    FileSystemNode(name: "Data.bin", size: 4_000_000_000, logicalSize: 3_800_000_000, isDirectory: false),
                    FileSystemNode(name: "Code", size: 1_000_000_000, logicalSize: 1_000_000_000, isDirectory: true)
                ]),
                FileSystemNode(name: "Resume.pdf", size: 3_000_000_000, logicalSize: 2_800_000_000, isDirectory: false)
            ]),
            FileSystemNode(name: "Photos", size: 2_000_000_000, logicalSize: 1_900_000_000, isDirectory: true, children: [])
        ])

        let child2 = FileSystemNode(name: "Downloads", size: 15_000_000_000, logicalSize: 14_500_000_000, isDirectory: true, children: [
            FileSystemNode(name: "LargeMovie.mp4", size: 10_000_000_000, logicalSize: 9_800_000_000, isDirectory: false),
            FileSystemNode(name: "archive.zip", size: 5_000_000_000, logicalSize: 4_700_000_000, isDirectory: false)
        ])

        return FileSystemNode(name: "Macintosh HD", size: 25_000_000_000, logicalSize: 24_000_000_000, isDirectory: true, children: [child1, child2])
    }

    // MARK: - Tree navigation helpers (O(N) — prefer nodeIndex / parent chain where possible)

    func node(atPath targetPath: String, currentPath: String = "") -> FileSystemNode? {
        let newPath = currentPath.isEmpty ? name : "\(currentPath)/\(name)"
        if targetPath == newPath { return self }
        if targetPath.hasPrefix(newPath + "/") {
            if let children = children {
                for child in children {
                    if let found = child.node(atPath: targetPath, currentPath: newPath) { return found }
                }
            }
        }
        return nil
    }
    
    /// Fallback O(N) lookup by ID for when cache isn't fully built yet
    func findNode(by targetId: UUID) -> FileSystemNode? {
        if id == targetId { return self }
        if let children = children {
            for child in children {
                if let found = child.findNode(by: targetId) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - Optimized helpers using parent chain (O(depth) instead of O(N))

    var pathFromRoot: String {
        var components: [String] = []
        var current: FileSystemNode? = self
        while let node = current {
            components.append(node.name)
            current = node.parent
        }
        return components.reversed().joined(separator: "/")
    }

    var ancestorIdsFromRoot: [UUID] {
        var ids: [UUID] = []
        var current: FileSystemNode? = self
        while let node = current {
            ids.append(node.id)
            current = node.parent
        }
        return ids.reversed()
    }
}
