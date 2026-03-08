import Foundation
@testable import MokuView

final class MockFileSystemProvider: @unchecked Sendable, FileSystemProviderType {
    var mockedContents: [URL: [URL]] = [:]
    var mockedResources: [URL: FileSystemResourceValues] = [:]
    var trashedURLs: [URL] = []
    var mockedVolumes: [URL]? = nil
    var mockedPermissions: [URL: UInt16] = [:]
    var throwErrorOnContents: Error?
    var throwErrorOnTrash: Error?
    
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        if let error = throwErrorOnContents {
            throw error
        }
        return mockedContents[url] ?? []
    }
    
    func resourceValues(for url: URL, keys: Set<URLResourceKey>) throws -> FileSystemResourceValues {
        return mockedResources[url] ?? FileSystemResourceValues()
    }
    
    func trashItem(at url: URL, resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        if let error = throwErrorOnTrash {
            throw error
        }
        trashedURLs.append(url)
    }
    
    func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: FileManager.VolumeEnumerationOptions) -> [URL]? {
        return mockedVolumes
    }
    
    func posixPermissions(for url: URL) -> UInt16 {
        return mockedPermissions[url] ?? 0
    }
}
