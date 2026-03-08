import XCTest
@testable import MokuView

@MainActor
final class TrashControllerTests: XCTestCase {
    var store: FileStore!
    var provider: MockFileSystemProvider!
    var trashState: TrashState!
    var navigationState: NavigationState!
    var controller: TrashController!
    
    override func setUp() async throws {
        provider = MockFileSystemProvider()
        store = FileStore(provider: provider)
        trashState = TrashState()
        navigationState = NavigationState()
        
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
        
        controller = TrashController(state: trashState, store: store, navigationState: navigationState)
    }
    
    func testTrashFlowSuccess() async {
        guard let child1 = store.rootNode?.children?.first else { return XCTFail() }
        
        provider.throwErrorOnTrash = nil
        
        navigationState.selection = child1.id
        controller.requestTrash(nodes: [child1])
        
        XCTAssertTrue(trashState.showTrashConfirmation)
        XCTAssertEqual(trashState.nodesToTrash.count, 1)
        
        controller.confirmTrash()
        
        XCTAssertFalse(trashState.showTrashConfirmation)
        XCTAssertFalse(trashState.showTrashError)
        XCTAssertEqual(navigationState.selection, store.rootNode?.id)
        
        XCTAssertNil(store.findNode(by: child1.id))
    }
    
    func testTrashFlowError() async {
        guard let child1 = store.rootNode?.children?.first else { return XCTFail() }
        
        provider.throwErrorOnTrash = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
        
        controller.requestTrash(nodes: [child1])
        controller.confirmTrash()
        
        XCTAssertFalse(trashState.showTrashConfirmation)
        XCTAssertTrue(trashState.showTrashError)
        XCTAssertNotNil(trashState.trashError)
        
        // Node should still exist
        XCTAssertNotNil(store.findNode(by: child1.id))
    }
}
