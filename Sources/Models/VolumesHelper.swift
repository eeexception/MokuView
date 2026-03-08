import Foundation

struct VolumeInfo: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let totalCapacity: Int64
    let availableCapacity: Int64
    
    var usedCapacity: Int64 {
        totalCapacity - availableCapacity
    }
    
    var percentageFree: Double {
        if totalCapacity == 0 { return 0 }
        return Double(availableCapacity) / Double(totalCapacity)
    }
}

final class VolumesHelper {
    static func getMountedVolumes(provider: FileSystemProviderType = LocalFileSystemProvider()) -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        
        guard let paths = provider.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        
        var volumes: [VolumeInfo] = []
        for url in paths {
            guard let resources = try? provider.resourceValues(for: url, keys: Set(keys)) else { continue }
            
            let total = Int64(resources.volumeTotalCapacity ?? 0)
            let available = Int64(resources.volumeAvailableCapacity ?? 0)
            let name = resources.volumeName ?? url.lastPathComponent
            
            if total > 0 {
                // Skip the synthesized "FirmLinks" / duplicate Data volumes in modern macOS
                if name == "Update" || name == "Recovery" || name == "VM" || name == "Preboot" {
                    continue
                }
                
                volumes.append(VolumeInfo(name: name, url: url, totalCapacity: total, availableCapacity: available))
            }
        }
        
        return volumes.sorted { $0.url.path < $1.url.path }
    }
}
