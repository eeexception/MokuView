import XCTest
@testable import MokuView

@MainActor
final class FileStoreDeletionTests: XCTestCase {
    func testDeleteNodeSuccess() {
        let provider = MockFileSystemProvider()
        let store = FileStore(provider: provider)
        
        let parent = FileSystemNode(name: "Parent", size: 1000, logicalSize: 1000, isDirectory: true, url: URL(fileURLWithPath: "/parent"))
        let child = FileSystemNode(name: "Child", size: 500, logicalSize: 500, isDirectory: false, url: URL(fileURLWithPath: "/parent/child.txt"))
        parent.children = [child]
        parent.cachedFilesCount = 1
        child.parent = parent
        child.cachedFilesCount = 1
        
        let result = store.deleteNode(child)
        
        XCTAssertEqual(provider.trashedURLs.count, 1)
        XCTAssertEqual(provider.trashedURLs.first, URL(fileURLWithPath: "/parent/child.txt"))
        XCTAssertEqual(parent.children?.isEmpty, true)
        XCTAssertEqual(parent.size, 500)
        XCTAssertEqual(parent.logicalSize, 500)
        XCTAssertEqual(parent.cachedFilesCount, 0)
        
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got \(error)")
        }
    }
    
    func testDeleteNodeFailure() {
        let provider = MockFileSystemProvider()
        let store = FileStore(provider: provider)
        
        let childNoURL = FileSystemNode(name: "Child", size: 500, logicalSize: 500, isDirectory: false, url: nil)
        let result = store.deleteNode(childNoURL)
        
        switch result {
        case .success: XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual((error as NSError).code, 1)
        }
        XCTAssertEqual(provider.trashedURLs.count, 0)
    }
}
