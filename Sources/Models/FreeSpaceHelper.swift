import Foundation

struct FreeSpaceHelper {
    static let freeSpaceNodeId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

    static func getDisplayChildren(
        for node: FileSystemNode,
        rootNode: FileSystemNode,
        includeFreeSpace: Bool,
        provider: FileSystemProviderType = LocalFileSystemProvider()
    ) -> [FileSystemNode] {
        var items = node.children ?? []
        if includeFreeSpace, let freeBytes = getVolumeFreeSpace(for: node, rootNode: rootNode, provider: provider) {
            let freeNode = FileSystemNode(
                id: freeSpaceNodeId,
                name: "Free Space",
                size: freeBytes,
                logicalSize: freeBytes,
                isDirectory: false,
                url: nil
            )
            items.append(freeNode)
        }
        return items
    }

    static func getVolumeFreeSpace(
        for node: FileSystemNode,
        rootNode: FileSystemNode,
        provider: FileSystemProviderType = LocalFileSystemProvider()
    ) -> Int64? {
        guard let url = node.url ?? rootNode.url,
              let resources = try? provider.resourceValues(for: url, keys: [.volumeAvailableCapacityKey]),
              let available = resources.volumeAvailableCapacity else { return nil }
        return Int64(available)
    }
}
