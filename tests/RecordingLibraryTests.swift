import Foundation

@main
struct RecordingLibraryTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("recordings")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = folder.appendingPathComponent("older.wav")
        let new = folder.appendingPathComponent("newer.M4A")
        try Data([1, 2]).write(to: old)
        try Data([1, 2, 3]).write(to: new)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: new.path)
        try Data().write(to: folder.appendingPathComponent("notes.txt"))
        try Data().write(to: folder.appendingPathComponent(".hidden.wav"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("directory.wav"), withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside.wav")
        try Data([1]).write(to: outside)
        let link = folder.appendingPathComponent("linked.wav")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let items = try RecordingLibrary.recordings(in: folder)
        precondition(items.map(\.url.lastPathComponent) == ["newer.M4A", "older.wav"], "only direct audio files should appear, newest first")
        precondition(items[0].size == 3)
        let selected = try RecordingLibrary.recording(id: new.path, in: folder)
        precondition(selected == new)
        let folderWithoutDirectoryHint = URL(fileURLWithPath: folder.path, isDirectory: false)
        let selectedWithoutHint = try RecordingLibrary.recording(id: new.path, in: folderWithoutDirectoryHint)
        precondition(selectedWithoutHint == new, "folder URLs chosen before creation must work too")
        for invalid in [outside, link, folder.appendingPathComponent("notes.txt")] {
            do {
                _ = try RecordingLibrary.recording(id: invalid.path, in: folder)
                preconditionFailure("file operations must remain within the selected folder's audio files")
            } catch {}
        }
        try FileManager.default.removeItem(at: new)
        let refreshed = try RecordingLibrary.recordings(in: folder)
        precondition(refreshed.map(\.url.lastPathComponent) == ["older.wav"], "external deletion must be reflected by the next scan")
        let empty = try RecordingLibrary.recordings(in: root.appendingPathComponent("missing"))
        precondition(empty.isEmpty)
        print("recording library tests passed")
    }
}
