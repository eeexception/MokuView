import Foundation

struct FileSystemResourceValues: Sendable {
    var isDirectory: Bool?
    var isSymbolicLink: Bool?
    var fileSize: Int?
    var fileAllocatedSize: Int?
    var totalFileAllocatedSize: Int?
    var contentModificationDate: Date?
    var volumeName: String?
    var volumeTotalCapacity: Int?
    var volumeAvailableCapacity: Int?

    init(
        isDirectory: Bool? = nil,
        isSymbolicLink: Bool? = nil,
        fileSize: Int? = nil,
        fileAllocatedSize: Int? = nil,
        totalFileAllocatedSize: Int? = nil,
        contentModificationDate: Date? = nil,
        volumeName: String? = nil,
        volumeTotalCapacity: Int? = nil,
        volumeAvailableCapacity: Int? = nil
    ) {
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.fileSize = fileSize
        self.fileAllocatedSize = fileAllocatedSize
        self.totalFileAllocatedSize = totalFileAllocatedSize
        self.contentModificationDate = contentModificationDate
        self.volumeName = volumeName
        self.volumeTotalCapacity = volumeTotalCapacity
        self.volumeAvailableCapacity = volumeAvailableCapacity
    }
}

protocol FileSystemProviderType: Sendable {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func resourceValues(for url: URL, keys: Set<URLResourceKey>) throws -> FileSystemResourceValues
    func trashItem(at url: URL, resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws
    func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: FileManager.VolumeEnumerationOptions) -> [URL]?
    func posixPermissions(for url: URL) -> UInt16
}

struct LocalFileSystemProvider: FileSystemProviderType {
    init() {}

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }

    func resourceValues(for url: URL, keys: Set<URLResourceKey>) throws -> FileSystemResourceValues {
        let res = try url.resourceValues(forKeys: keys)
        return FileSystemResourceValues(
            isDirectory: res.isDirectory,
            isSymbolicLink: res.isSymbolicLink,
            fileSize: res.fileSize,
            fileAllocatedSize: res.fileAllocatedSize,
            totalFileAllocatedSize: res.totalFileAllocatedSize,
            contentModificationDate: res.contentModificationDate,
            volumeName: res.volumeName,
            volumeTotalCapacity: res.volumeTotalCapacity,
            volumeAvailableCapacity: res.volumeAvailableCapacity
        )
    }

    func trashItem(at url: URL, resultingItemURL outResultingURL: AutoreleasingUnsafeMutablePointer<NSURL?>?) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: outResultingURL)
    }

    func mountedVolumeURLs(includingResourceValuesForKeys propertyKeys: [URLResourceKey]?, options: FileManager.VolumeEnumerationOptions) -> [URL]? {
        return FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: propertyKeys, options: options)
    }

    func posixPermissions(for url: URL) -> UInt16 {
        var st = stat()
        if stat(url.path, &st) == 0 {
            return UInt16(st.st_mode & 0o7777)
        }
        return 0
    }
}
