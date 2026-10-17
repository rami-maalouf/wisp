import Foundation

struct RecordingItem {
    let url: URL
    let modified: Date
    let size: Int64

    func status(dateFormatter: DateFormatter) -> [String: String] {
        ["id": url.path, "name": url.lastPathComponent,
         "detail": "\(dateFormatter.string(from: modified)) · \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"]
    }
}

enum RecordingLibrary {
    private static let extensions: Set<String> = ["wav", "m4a", "mp3", "aif", "aiff", "caf", "flac", "aac", "ogg", "opus"]
    private static let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]

    static func recordings(in folder: URL) throws -> [RecordingItem] {
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
        return files.compactMap { url -> RecordingItem? in
            guard extensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
            return RecordingItem(url: url, modified: values.contentModificationDate ?? .distantPast, size: Int64(values.fileSize ?? 0))
        }.sorted {
            $0.modified == $1.modified ? $0.url.lastPathComponent < $1.url.lastPathComponent : $0.modified > $1.modified
        }
    }

    static func recording(id: String, in folder: URL) throws -> URL {
        let url = URL(fileURLWithPath: id).standardizedFileURL
        guard url.deletingLastPathComponent().path == folder.standardizedFileURL.path,
              extensions.contains(url.pathExtension.lowercased()) else {
            throw NSError(domain: "RecordingLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose an audio file in the current recording folder."])
        }
        let values = try url.resourceValues(forKeys: keys)
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw NSError(domain: "RecordingLibrary", code: 2, userInfo: [NSLocalizedDescriptionKey: "This recording is no longer available. Refresh Recents."])
        }
        return url
    }
}
