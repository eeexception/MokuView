import XCTest
@testable import MokuView

@MainActor
final class PieChartControllerTests: XCTestCase {
    var store: FileStore!
    var provider: MockFileSystemProvider!
    var state: PieChartState!
    var controller: PieChartController!
    
    override func setUp() {
        provider = MockFileSystemProvider()
        store = FileStore(provider: provider)
        state = PieChartState()
        controller = PieChartController(state: state, store: store)
        
        // Setup mock tree structure
        let root = FileSystemNode(name: "Root", isDirectory: true, url: URL(fileURLWithPath: "/"))
        let child1 = FileSystemNode(name: "Child1", size: 60, logicalSize: 60, isDirectory: true, url: URL(fileURLWithPath: "/Child1"))
        let child2 = FileSystemNode(name: "Child2", size: 40, logicalSize: 40, isDirectory: false, url: URL(fileURLWithPath: "/Child2"))
        
        child1.parent = root
        child2.parent = root
        root.children = [child1, child2]
        root.size = 100
        
        if let rootUrl = root.url {
            provider.mockedVolumes = [rootUrl]
            provider.mockedResources[rootUrl] = FileSystemResourceValues(volumeAvailableCapacity: 100)
        }
        
        store.rootNode = root
    }
    
    func testDisplayChildren() {
        guard let rootNode = store.rootNode else { return XCTFail() }
        
        controller.toggleFreeSpace(false)
        let withoutFreeSpace = controller.displayChildren(for: rootNode)
        XCTAssertEqual(withoutFreeSpace.count, 2)
        XCTAssertFalse(withoutFreeSpace.contains(where: { $0.name == "Free Space" }))
        
        controller.toggleFreeSpace(true)
        let withFreeSpace = controller.displayChildren(for: rootNode)
        XCTAssertEqual(withFreeSpace.count, 3)
        XCTAssertTrue(withFreeSpace.contains(where: { $0.name == "Free Space" }))
    }
    
    func testTotalChartSize() {
        guard let rootNode = store.rootNode else { return XCTFail() }
        
        controller.toggleFreeSpace(false)
        XCTAssertEqual(controller.totalChartSize(for: rootNode), 100)
        
        controller.toggleFreeSpace(true)
        XCTAssertEqual(controller.totalChartSize(for: rootNode), 200) // 100 size + 100 free capacity
    }
    
    func testHandleAngleSelection() {
        guard let rootNode = store.rootNode, let child1 = rootNode.children?.first else { return XCTFail() }
        
        controller.toggleFreeSpace(false)
        
        controller.setAngleSelection(50)
        let selectedId = controller.handleAngleSelection(node: rootNode)
        
        XCTAssertEqual(selectedId, child1.id) // child1 takes 0-60
        XCTAssertNil(state.selectedAngle) // Clears selection
    }
}
