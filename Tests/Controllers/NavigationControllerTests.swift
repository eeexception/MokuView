import XCTest
@testable import MokuView

@MainActor
final class NavigationControllerTests: XCTestCase {
    var store: FileStore!
    var provider: MockFileSystemProvider!
    var state: NavigationState!
    var controller: NavigationController!
    
    override func setUp() async throws {
        provider = MockFileSystemProvider()
        store = FileStore(provider: provider)
        state = NavigationState()
        
        // Setup mock tree structure
        let root = FileSystemNode(name: "Root", isDirectory: true, url: URL(fileURLWithPath: "/"))
        root.size = 100
        
        if let rootUrl = root.url {
            let child1Url = URL(fileURLWithPath: "/Child1")
            let child2Url = URL(fileURLWithPath: "/Child2")
            
            provider.mockedVolumes = [rootUrl]
            provider.mockedResources[rootUrl] = FileSystemResourceValues(volumeAvailableCapacity: 100)
            
            provider.mockedContents[rootUrl] = [child1Url, child2Url]
            provider.mockedResources[child1Url] = FileSystemResourceValues(isDirectory: true, fileSize: 50, fileAllocatedSize: 50)
            provider.mockedResources[child2Url] = FileSystemResourceValues(isDirectory: false, fileSize: 50, fileAllocatedSize: 50)
        }
        
        store.rootNode = root
        await store.shallowScan(node: root) // populates index
        
        controller = NavigationController(state: state, store: store)
    }
    
    func testNavigationHistory() {
        guard let child1 = store.rootNode?.children?.first else { return XCTFail() }
        
        controller.setSelection(child1.id)
        XCTAssertEqual(state.history.count, 0)
        XCTAssertEqual(state.selection, child1.id)
        
        guard let child2 = store.rootNode?.children?.last else { return XCTFail() }
        controller.setSelection(child2.id)
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history.first, child1.id)
        XCTAssertEqual(state.selection, child2.id)
        
        controller.goBack()
        XCTAssertEqual(state.selection, child1.id)
        XCTAssertEqual(state.history.count, 0)
    }
    
    func testNavigationGoUp() {
        guard let child1 = store.rootNode?.children?.first else { return XCTFail() }
        
        controller.setSelection(child1.id)
        XCTAssertTrue(controller.canGoUp)
        
        controller.goUp()
        XCTAssertEqual(state.selection, store.rootNode?.id)
        XCTAssertFalse(controller.canGoUp) // Root cannot go up
    }
}
