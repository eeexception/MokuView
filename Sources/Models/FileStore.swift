import Foundation
import Observation

// ─────────────────────────────────────────────────────────────
// ScanActor: all tree mutation happens here, NEVER on MainActor
// ─────────────────────────────────────────────────────────────
actor ScanActor {

    private static let resourceKeys: [URLResourceKey] = [
        .fileSizeKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .contentModificationDateKey
    ]
    
    private let ignoredPaths: Set<String>
    private let provider: FileSystemProviderType

    init(
        provider: FileSystemProviderType = LocalFileSystemProvider(),
        ignoredPaths: Set<String> = [
            "/System/Volumes",
            "/.Spotlight-V100",
            "/.fseventsd",
            "/.DocumentRevisions-V100",
            "/.MobileBackups",
            "/.vol",
            "/dev",
            "/net",
            "/home"
        ]
    ) {
        self.provider = provider
        self.ignoredPaths = ignoredPaths
    }

    /// Populates `node.children` from the file system. No-op if already loaded or loading.
    func shallowScan(node: FileSystemNode, showHiddenFiles: Bool = true) async {
        guard node.isDirectory, let url = node.url, node.children == nil, !node.isLoading else { return }

        node.isLoading = true
        defer { node.isLoading = false }

        // Read the directory's own metadata (mdate, permissions) if not yet set
        if node.modificationDate == nil {
            if let res = try? provider.resourceValues(for: url, keys: [.contentModificationDateKey]) {
                node.modificationDate = res.contentModificationDate
            }
            node.posixPermissions = provider.posixPermissions(for: url)
        }

        let keys = Self.resourceKeys

        var options: FileManager.DirectoryEnumerationOptions = []
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let contents = try? provider.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            node.children = []
            return
        }

        var newChildren: [FileSystemNode] = []
        for childURL in contents {
            guard let resources = try? provider.resourceValues(for: childURL, keys: Set(keys)) else { continue }

            if resources.isSymbolicLink == true { continue }

            let path = childURL.path
            if self.ignoredPaths.contains(path) { continue }

            let isDir = resources.isDirectory ?? false

            var allocatedSize: Int64 = 0
            var logicalSize: Int64 = 0

            if !isDir {
                // Logical (apparent) size
                logicalSize = Int64(resources.fileSize ?? 0)
                // Allocated (disk) size — block-aligned
                if let bytes = resources.totalFileAllocatedSize {
                    allocatedSize = Int64(bytes)
                } else if let bytes = resources.fileAllocatedSize {
                    allocatedSize = Int64(bytes)
                } else {
                    allocatedSize = logicalSize
                }
            }

            let child = FileSystemNode(
                name: childURL.lastPathComponent,
                size: allocatedSize,
                logicalSize: logicalSize,
                isDirectory: isDir,
                url: childURL,
                children: nil
            )
            child.modificationDate = resources.contentModificationDate
            child.posixPermissions = provider.posixPermissions(for: childURL)

            newChildren.append(child)
        }

        newChildren.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for child in newChildren { child.parent = node }
        node.children = newChildren
    }

    /// Recursively computes sizes for every node in the subtree rooted at `node`.
    func deepScan(
        node: FileSystemNode,
        showHiddenFiles: Bool = true,
        onProgress: @Sendable @escaping (String, Int64, Int) -> Void
    ) async -> Int64 {
        if Task.isCancelled { return 0 }

        await shallowScan(node: node, showHiddenFiles: showHiddenFiles)

        guard let children = node.children, !children.isEmpty else {
            node.cachedFilesCount = node.isDirectory ? 0 : 1
            node.cachedFoldersCount = 0
            return node.size
        }

        var dirs: [FileSystemNode] = []
        var filesAllocatedTotal: Int64 = 0
        var filesLogicalTotal: Int64 = 0
        var fileCount: Int = 0

        for child in children {
            if child.isDirectory {
                dirs.append(child)
            } else {
                filesAllocatedTotal += child.size
                filesLogicalTotal += child.logicalSize
                fileCount += 1
                child.cachedFilesCount = 1
                child.cachedFoldersCount = 0
            }
        }

        if fileCount > 0 {
            onProgress(node.url?.path ?? node.name, filesAllocatedTotal, fileCount)
        }

        var totalAllocated: Int64 = filesAllocatedTotal

        if !dirs.isEmpty {
            let batchSize = min(dirs.count, 8)
            
            await withTaskGroup(of: Int64.self) { group in
                var index = 0
                
                for _ in 0..<batchSize where index < dirs.count {
                    let dir = dirs[index]
                    index += 1
                    group.addTask {
                        return await self.deepScan(node: dir, showHiddenFiles: showHiddenFiles, onProgress: onProgress)
                    }
                }
                
                for await childSize in group {
                    totalAllocated += childSize
                    if index < dirs.count {
                        let dir = dirs[index]
                        index += 1
                        group.addTask {
                            return await self.deepScan(node: dir, showHiddenFiles: showHiddenFiles, onProgress: onProgress)
                        }
                    }
                }
            }
        }

        node.size = totalAllocated
        // Aggregate logical sizes from all children (dirs already have their logicalSize set by deepScan)
        node.logicalSize = filesLogicalTotal + dirs.reduce(0) { $0 + $1.logicalSize }
        node.cachedFilesCount = children.reduce(0) { $0 + $1.cachedFilesCount }
        node.cachedFoldersCount = dirs.count + dirs.reduce(0) { $0 + $1.cachedFoldersCount }
        node.children = node.children?.sorted { $0.size > $1.size }

        return totalAllocated
    }

}

// ─────────────────────────────────────────────────────────────
// FileStore: @Observable, always accessed from the UI / MainActor
// ─────────────────────────────────────────────────────────────
@Observable
@MainActor
final class FileStore {
    var rootNode: FileSystemNode?
    var isScanning: Bool = false
    var currentScannedPath: String = ""
    var totalBytesScanned: Int64 = 0
    var totalFilesScanned: Int = 0
    var scanProgress: Double = 0

    /// O(1) node lookup by ID — built after scan completes
    private(set) var nodeIndex: [UUID: FileSystemNode] = [:]

    private var scanTask: Task<Void, Never>?
    let provider: FileSystemProviderType
    private let scanActor: ScanActor

    init(provider: FileSystemProviderType = LocalFileSystemProvider()) {
        self.provider = provider
        self.scanActor = ScanActor(provider: provider)
    }

    // MARK: - Public API

    func startScan(url: URL) {
        resetScanState(path: url.path)

        let root = FileSystemNode(
            name: url.path == "/" ? "Macintosh HD" : url.lastPathComponent,
            isDirectory: true,
            url: url
        )
        rootNode = root

        scanTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            await self.scanActor.shallowScan(node: root)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.nodeIndex = [root.id: root]
                if let children = root.children {
                    for child in children {
                        self.nodeIndex[child.id] = child
                    }
                }
            }

            guard !Task.isCancelled else { return }

            let accumulator = ProgressAccumulator()
            let throttle = ThrottleBox(interval: 0.1)

            _ = await self.scanActor.deepScan(node: root, onProgress: self.makeProgressCallback(accumulator: accumulator, throttle: throttle))

            let finalSnap = accumulator.snapshot()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.finishScanState(finalSnap: finalSnap)
                if let root = self.rootNode {
                    self.nodeIndex.removeAll(keepingCapacity: true)
                    self.buildIndex(from: root)
                }
            }
        }
    }
    
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        currentScannedPath = ""
    }

    func refreshNode(_ node: FileSystemNode) {
        resetScanState(path: node.url?.path ?? "")

        scanTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                if let children = node.children {
                    for child in children {
                        self.removeFromIndex(child)
                    }
                }
                node.children = nil
                self.nodeIndex[node.id] = node
            }
            
            let oldSize = await MainActor.run { node.size }
            let oldLogical = await MainActor.run { node.logicalSize }
            let oldFiles = await MainActor.run { node.cachedFilesCount }
            let oldFolders = await MainActor.run { node.cachedFoldersCount }

            let accumulator = ProgressAccumulator()
            let throttle = ThrottleBox(interval: 0.1)

            let newSize = await self.scanActor.deepScan(node: node, onProgress: self.makeProgressCallback(accumulator: accumulator, throttle: throttle))

            guard !Task.isCancelled else { return }

            let finalSnap = accumulator.snapshot()
            
            await MainActor.run { [weak self] in
                guard let self else { return }
                
                let diffSize = newSize - oldSize
                let diffLogical = node.logicalSize - oldLogical
                let diffFiles = node.cachedFilesCount - oldFiles
                let diffFolders = node.cachedFoldersCount - oldFolders
                
                var ancestor = node.parent
                while let a = ancestor {
                    a.size += diffSize
                    a.logicalSize += diffLogical
                    a.cachedFilesCount += diffFiles
                    a.cachedFoldersCount += diffFolders
                    ancestor = a.parent
                }
                
                self.finishScanState(finalSnap: finalSnap)
                
                if let children = node.children {
                    for child in children {
                        self.buildIndex(from: child)
                    }
                }
            }
        }
    }

    /// Loads children for `node` if not already loaded or loading.
    /// - Thread-safe: `ScanActor.shallowScan` uses `node.isLoading` to prevent duplicate scans.
    /// - After completion, updates `nodeIndex` cache with new children.
    func shallowScan(node: FileSystemNode) async {
        // Skip if already loaded OR currently being scanned (isLoading prevents duplicate I/O)
        guard node.children == nil, !node.isLoading else { return }
        await scanActor.shallowScan(node: node)
        // Update nodeIndex cache with newly loaded children
        if let children = node.children {
            for child in children {
                nodeIndex[child.id] = child
            }
        }
    }
    
    func deleteNode(_ node: FileSystemNode) -> Result<Void, Error> {
        guard let url = node.url else {
            return .failure(NSError(domain: "MokuView", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Node has no file URL"
            ]))
        }
        
        do {
            try provider.trashItem(at: url, resultingItemURL: nil)
        } catch {
            return .failure(error)
        }
        
        if let parent = node.parent {
            parent.children?.removeAll { $0.id == node.id }
            var ancestor: FileSystemNode? = parent
            while let a = ancestor {
                a.size -= node.size
                a.logicalSize -= node.logicalSize
                a.cachedFilesCount -= node.cachedFilesCount
                a.cachedFoldersCount -= (node.isDirectory ? 1 : 0) + node.cachedFoldersCount
                ancestor = a.parent
            }
        }
        
        removeFromIndex(node)
        return .success(())
    }

    func findNode(by id: UUID) -> FileSystemNode? {
        if let found = nodeIndex[id] { return found }
        // Fallback: if deepScan populated a node but hasn't yet rebuilt the index
        return rootNode?.findNode(by: id)
    }
    
    /// Asynchronously resolves a node by its Unix path.
    /// If intermediate directories are not scanned, it performs shallow scans along the way.
    func resolveNode(byPath targetPath: String) async -> FileSystemNode? {
        guard let root = rootNode, let rootURL = root.url else { return nil }
        
        let rootPath = rootURL.path
        if targetPath == rootPath { return root }
        // Ensure the path is within the current root volume
        guard targetPath.hasPrefix(rootPath == "/" ? "/" : rootPath + "/") else { return nil }
        
        var relativePath = targetPath
        if rootPath != "/" {
            relativePath = String(targetPath.dropFirst(rootPath.count))
        }
        let components = relativePath.components(separatedBy: "/").filter { !$0.isEmpty }
        
        var currentNode = root
        for component in components {
            if currentNode.children == nil {
                await shallowScan(node: currentNode)
            }
            guard let children = currentNode.children else { return nil }
            guard let nextNode = children.first(where: { $0.url?.lastPathComponent == component }) else { return nil }
            currentNode = nextNode
        }
        
        return currentNode
    }

    private func buildIndex(from node: FileSystemNode) {
        nodeIndex[node.id] = node
        guard let children = node.children else { return }
        for child in children {
            buildIndex(from: child)
        }
    }
    
    private func removeFromIndex(_ node: FileSystemNode) {
        nodeIndex.removeValue(forKey: node.id)
        guard let children = node.children else { return }
        for child in children {
            removeFromIndex(child)
        }
    }

    private func resetScanState(path: String) {
        scanTask?.cancel()
        totalBytesScanned = 0
        totalFilesScanned = 0
        scanProgress = 0
        isScanning = true
        currentScannedPath = path
    }

    private func finishScanState(finalSnap: (bytes: Int64, files: Int, dirs: Int)) {
        self.isScanning = false
        self.scanProgress = 1.0
        self.currentScannedPath = ""
        self.totalBytesScanned = finalSnap.bytes
        self.totalFilesScanned = finalSnap.files
    }

    private func makeProgressCallback(accumulator: ProgressAccumulator, throttle: ThrottleBox) -> @Sendable (String, Int64, Int) -> Void {
        return { path, bytes, count in
            accumulator.add(bytes: bytes, files: count)
            guard throttle.shouldUpdate() else { return }
            let snap = accumulator.snapshot()
            let p = path
            Task { @MainActor [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.currentScannedPath = p
                self.totalBytesScanned = snap.bytes
                self.totalFilesScanned = snap.files
                let n = Double(snap.dirs)
                self.scanProgress = 1.0 - 1.0 / (1.0 + log2(1.0 + n / 10.0))
            }
        }
    }
}
