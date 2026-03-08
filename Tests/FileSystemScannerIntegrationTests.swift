import XCTest
@testable import MokuView

/// Tests that validate the scanning logic using ScanActor directly.
final class FileSystemScannerIntegrationTests: XCTestCase {
    
    func testScanDirectoryReturnsCorrectNodeHierarchy() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? fileManager.removeItem(at: tempDir)
        }
        
        // Setup: Create a file
        let fileURL = tempDir.appendingPathComponent("test.txt")
        let data = Data(repeating: 1, count: 1024) // 1KB logical
        try data.write(to: fileURL)
        
        // Setup: Create a subfolder with a file
        let subfolderURL = tempDir.appendingPathComponent("subfolder")
        try fileManager.createDirectory(at: subfolderURL, withIntermediateDirectories: true)
        
        let subfileURL = subfolderURL.appendingPathComponent("subfile.bin")
        let subData = Data(repeating: 2, count: 2048) // 2KB logical
        try subData.write(to: subfileURL)
        
        // Action: Scan using ScanActor + deepScan
        let actor = ScanActor()
        let rootNode = FileSystemNode(
            name: tempDir.lastPathComponent,
            isDirectory: true,
            url: tempDir
        )
        let totalSize = await actor.deepScan(node: rootNode) { _, _, _ in }
        
        // Assertion: Root Node
        XCTAssertEqual(rootNode.name, tempDir.lastPathComponent)
        XCTAssertTrue(rootNode.isDirectory)
        // Size uses allocated bytes (typically 4096 per file on APFS), not logical size
        XCTAssertGreaterThan(rootNode.size, 0)
        XCTAssertEqual(rootNode.filesCount, 2)
        XCTAssertEqual(rootNode.foldersCount, 1)
        XCTAssertEqual(totalSize, rootNode.size)
        
        // Assertion: Children
        guard let children = rootNode.children else {
            XCTFail("Root node should have children")
            return
        }
        XCTAssertEqual(children.count, 2)
        
        // Check finding specific children
        let txtFile = children.first { $0.name == "test.txt" }
        XCTAssertNotNil(txtFile)
        XCTAssertFalse(txtFile!.isDirectory)
        XCTAssertGreaterThan(txtFile!.size, 0, "File size should be positive (allocated size)")
        
        let subfolder = children.first { $0.name == "subfolder" }
        XCTAssertNotNil(subfolder)
        XCTAssertTrue(subfolder!.isDirectory)
        XCTAssertGreaterThan(subfolder!.size, 0)
        XCTAssertEqual(subfolder!.filesCount, 1)
        XCTAssertEqual(subfolder!.foldersCount, 0)
    }
    
    func testScanDirectorySortsChildrenBySizeDescending() async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        // Create files with significantly different sizes to ensure sort order
        // even with block-aligned allocation
        let file1 = tempDir.appendingPathComponent("small.txt")
        try Data(repeating: 1, count: 100).write(to: file1)
        
        let file2 = tempDir.appendingPathComponent("large.txt")
        try Data(repeating: 2, count: 50_000).write(to: file2)
        
        let file3 = tempDir.appendingPathComponent("medium.txt")
        try Data(repeating: 3, count: 10_000).write(to: file3)
        
        let actor = ScanActor()
        let rootNode = FileSystemNode(
            name: tempDir.lastPathComponent,
            isDirectory: true,
            url: tempDir
        )
        _ = await actor.deepScan(node: rootNode) { _, _, _ in }
        
        if let children = rootNode.children {
            XCTAssertEqual(children.count, 3)
            // After deepScan, children are sorted by size descending
            XCTAssertEqual(children[0].name, "large.txt")
            XCTAssertEqual(children[1].name, "medium.txt")
            XCTAssertEqual(children[2].name, "small.txt")
        } else {
            XCTFail("Should have children")
        }
    }
}
