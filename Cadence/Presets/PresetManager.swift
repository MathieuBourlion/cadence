import Foundation

/// Saves, loads, and deletes Cadence preset JSON files from
/// ~/Library/Application Support/Cadence/presets/
struct PresetManager {

    private let presetsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        presetsDirectory = appSupport.appendingPathComponent("Cadence/presets", isDirectory: true)
    }

    init(presetsDirectory: URL) {
        self.presetsDirectory = presetsDirectory
    }

    // MARK: - Directory

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
    }

    private func url(for name: String) -> URL {
        presetsDirectory.appendingPathComponent("\(name).json")
    }

    // MARK: - CRUD

    func save(_ sequence: CadenceSequence, name: String) throws {
        try ensureDirectoryExists()
        let stripped = sequence.strippedForPreset()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stripped)
        try data.write(to: url(for: name), options: .atomic)
    }

    func load(name: String) throws -> CadenceSequence {
        let data = try Data(contentsOf: url(for: name))
        return try JSONDecoder().decode(CadenceSequence.self, from: data)
    }

    func delete(name: String) throws {
        try FileManager.default.removeItem(at: url(for: name))
    }

    func listPresets() throws -> [String] {
        guard FileManager.default.fileExists(atPath: presetsDirectory.path) else {
            return []
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: presetsDirectory,
            includingPropertiesForKeys: [.nameKey],
            options: .skipsHiddenFiles
        )
        return files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func presetExists(name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: name).path)
    }
}
