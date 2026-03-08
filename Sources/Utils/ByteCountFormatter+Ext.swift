import Foundation

extension ByteCountFormatter {
    /// Returns formatted byte string, using "0 KB" instead of the default "Zero KB".
    static func formattedSize(_ bytes: Int64) -> String {
        if bytes == 0 { return "0 KB" }
        return string(fromByteCount: bytes, countStyle: .file)
    }
}
