import XCTest
@testable import MokuView

final class VolumesHelperTests: XCTestCase {
    func testGetMountedVolumes() {
        let provider = MockFileSystemProvider()
        
        let validURL = URL(fileURLWithPath: "/Volumes/Data")
        let ignoredURL = URL(fileURLWithPath: "/Volumes/Update")
        let firmLinkURL = URL(fileURLWithPath: "/Volumes/Recovery")
        
        provider.mockedVolumes = [validURL, ignoredURL, firmLinkURL]
        provider.mockedResources[validURL] = FileSystemResourceValues(
            volumeName: "Data",
            volumeTotalCapacity: 1000,
            volumeAvailableCapacity: 400
        )
        provider.mockedResources[ignoredURL] = FileSystemResourceValues(
            volumeName: "Update",
            volumeTotalCapacity: 500,
            volumeAvailableCapacity: 200
        )
        provider.mockedResources[firmLinkURL] = FileSystemResourceValues(
            volumeName: "Recovery",
            volumeTotalCapacity: 500,
            volumeAvailableCapacity: 200
        )
        
        let volumes = VolumesHelper.getMountedVolumes(provider: provider)
        
        XCTAssertEqual(volumes.count, 1)
        XCTAssertEqual(volumes.first?.name, "Data")
        XCTAssertEqual(volumes.first?.totalCapacity, 1000)
        XCTAssertEqual(volumes.first?.availableCapacity, 400)
        XCTAssertEqual(volumes.first?.usedCapacity, 600)
        XCTAssertEqual(volumes.first?.percentageFree, 0.4)
    }
}
