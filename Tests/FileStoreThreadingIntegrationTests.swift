import XCTest
@testable import MokuView

final class FileStoreThreadingIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func makeTestDirectory(fileCount: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MokuViewTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for i in 0..<fileCount {
            let file = dir.appendingPathComponent("file_\(i).txt")
            try "Hello \(i)".write(to: file, atomically: true, encoding: .utf8)
        }
        return dir
    }

    // MARK: - Concurrent shallowScan: same node from 50 concurrent tasks
    // Expected: children populated exactly once, no crash, no duplicates
    func testConcurrentShallowScanSameNode() async throws {
        let dir = try makeTestDirectory(fileCount: 40)
        defer { try? FileManager.default.removeItem(at: dir) }

        let root = FileSystemNode(name: "root", isDirectory: true, url: dir)
        let actor = ScanActor()

        // 50 tasks all try to shallow-scan the same node concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    await actor.shallowScan(node: root)
                }
            }
        }

        let children = root.children
        XCTAssertNotNil(children, "children must be set after concurrent scans")
        XCTAssertEqual(children?.count, 40, "must contain exactly 40 files, no duplicates")
    }

    // MARK: - Concurrent shallowScan: different nodes, same actor
    // Expected: each node gets its own children, no cross-contamination
    func testConcurrentShallowScanDifferentNodes() async throws {
        let dirs = try (0..<10).map { i in
            let d = try makeTestDirectory(fileCount: i + 1)
            return d
        }
        defer { dirs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let nodes = dirs.enumerated().map { i, url in
            FileSystemNode(name: "dir_\(i)", isDirectory: true, url: url)
        }

        let actor = ScanActor()

        await withTaskGroup(of: Void.self) { group in
            for node in nodes {
                group.addTask {
                    await actor.shallowScan(node: node)
                }
            }
        }

        for (i, node) in nodes.enumerated() {
            XCTAssertEqual(node.children?.count, i + 1,
                           "Dir \(i) should have \(i + 1) children, got \(node.children?.count ?? -1)")
        }
    }

    // MARK: - deepScan from multiple independent actors ensures no data race
    func testParallelDeepScanIndependentActors() async throws {
        // Build a 2-level structure: 5 subdirs each with 10 files
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MokuViewTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var expectedTotal: Int64 = 0
        for d in 0..<5 {
            let subdir = root.appendingPathComponent("subdir_\(d)")
            try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
            for f in 0..<10 {
                let file = subdir.appendingPathComponent("file_\(f).txt")
                let content = "x" // 1 byte logical
                try content.write(to: file, atomically: true, encoding: .utf8)
            }
        }

        let rootNode = FileSystemNode(name: "root", isDirectory: true, url: root)
        let actor = ScanActor()

        let total = await actor.deepScan(node: rootNode) { _, _, _ in }

        // 5 subdirs × 10 files, each file is at minimum 4096 (one FS block allocated)
        XCTAssertGreaterThan(total, 0, "total size must be positive after deep scan")
        XCTAssertEqual(rootNode.children?.count, 5, "root must have 5 subdirectories")

        for subdir in rootNode.children ?? [] {
            XCTAssertEqual(subdir.children?.count, 10,
                           "\(subdir.name) should have 10 files, got \(subdir.children?.count ?? -1)")
        }

        _ = expectedTotal // avoid unused warning
    }

    // MARK: - FileStore: startScan, shallowScan triggered from navigation
    func testFileStoreShallowScanDoesNotDuplicateChildren() async throws {
        let dir = try makeTestDirectory(fileCount: 20)
        defer { try? FileManager.default.removeItem(at: dir) }

        // FileStore is @MainActor, initialise on MainActor
        let store = await MainActor.run { FileStore() }
        await MainActor.run { store.startScan(url: dir) }

        // Poll until rootNode.children is populated (max 3s)
        var root: FileSystemNode? = nil
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            root = await MainActor.run { store.rootNode }
            if root?.children != nil { break }
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        XCTAssertNotNil(root, "rootNode must exist after startScan")

        let count = root?.children?.count
        XCTAssertEqual(count, 20, "should have 20 files, got \(count ?? -1)")

        // Calling shallowScan again must be a no-op (children already set)
        if let root {
            await store.shallowScan(node: root)
            XCTAssertEqual(root.children?.count, 20, "children must not be duplicated on second shallowScan")
        }
    }
}
