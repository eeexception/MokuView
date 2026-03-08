import XCTest
@testable import MokuView

final class ScanActorTests: XCTestCase {
    func testIgnoredPathsAreSkipped() async throws {
        let provider = MockFileSystemProvider()
        let rootURL = URL(fileURLWithPath: "/")
        
        let ignoredURL = URL(fileURLWithPath: "/.Spotlight-V100")
        let notIgnoredURL = URL(fileURLWithPath: "/User")
        
        provider.mockedContents[rootURL] = [ignoredURL, notIgnoredURL]
        provider.mockedResources[ignoredURL] = FileSystemResourceValues(isDirectory: true, fileSize: 100)
        provider.mockedResources[notIgnoredURL] = FileSystemResourceValues(isDirectory: true, fileSize: 200)
        
        let actor = ScanActor(provider: provider)
        let rootNode = FileSystemNode(name: "Root", isDirectory: true, url: rootURL)
        
        await actor.shallowScan(node: rootNode)
        
        XCTAssertEqual(rootNode.children?.count, 1)
        XCTAssertEqual(rootNode.children?.first?.name, "User")
    }
    
    func testErrorHandlingWhenContentsThrows() async throws {
        let provider = MockFileSystemProvider()
        struct MockError: Error {}
        provider.throwErrorOnContents = MockError()
        
        let actor = ScanActor(provider: provider)
        let rootNode = FileSystemNode(name: "Root", isDirectory: true, url: URL(fileURLWithPath: "/"))
        
        await actor.shallowScan(node: rootNode)
        
        XCTAssertEqual(rootNode.children?.isEmpty, true)
    }
    
    func testSymlinkSkipping() async throws {
        let provider = MockFileSystemProvider()
        let rootURL = URL(fileURLWithPath: "/")
        
        let symlinkURL = URL(fileURLWithPath: "/symlink")
        let fileURL = URL(fileURLWithPath: "/file.txt")
        
        provider.mockedContents[rootURL] = [symlinkURL, fileURL]
        provider.mockedResources[symlinkURL] = FileSystemResourceValues(isSymbolicLink: true)
        provider.mockedResources[fileURL] = FileSystemResourceValues(isDirectory: false, isSymbolicLink: false)
        
        let actor = ScanActor(provider: provider)
        let rootNode = FileSystemNode(name: "Root", isDirectory: true, url: rootURL)
        
        await actor.shallowScan(node: rootNode)
        
        XCTAssertEqual(rootNode.children?.count, 1)
        XCTAssertEqual(rootNode.children?.first?.name, "file.txt")
    }
    
    func testLogicalVsAllocatedSize() async throws {
        let provider = MockFileSystemProvider()
        let rootURL = URL(fileURLWithPath: "/")
        let fileURL = URL(fileURLWithPath: "/file.txt")
        
        provider.mockedContents[rootURL] = [fileURL]
        provider.mockedResources[fileURL] = FileSystemResourceValues(
            isDirectory: false,
            fileSize: 100,
            fileAllocatedSize: nil,
            totalFileAllocatedSize: 4096
        )
        
        let actor = ScanActor(provider: provider)
        let rootNode = FileSystemNode(name: "Root", isDirectory: true, url: rootURL)
        
        let size = await actor.deepScan(node: rootNode, onProgress: { _, _, _ in })
        
        XCTAssertEqual(size, 4096)
        XCTAssertEqual(rootNode.logicalSize, 100)
        XCTAssertEqual(rootNode.size, 4096)
        XCTAssertEqual(rootNode.children?.first?.logicalSize, 100)
        XCTAssertEqual(rootNode.children?.first?.size, 4096)
    }
}
