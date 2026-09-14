import Foundation
import CryptoKit

/// Memory + disk cache in front of `SefariaClient`. Liturgical text never changes,
/// so cached entries are kept indefinitely and make the app fully usable offline.
actor TextRepository {
    static let shared = TextRepository()

    private let client: SefariaClient
    private let directory: URL
    private var memory: [String: PrayerLeafText] = [:]
    private var inFlight: [String: Task<PrayerLeafText, Error>] = [:]

    init(client: SefariaClient = .shared) {
        self.client = client
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = caches.appending(path: "SefariaTexts", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func text(for ref: String) async throws -> PrayerLeafText {
        if let hit = memory[ref] { return hit }
        if let disk = readFromDisk(ref) {
            memory[ref] = disk
            return disk
        }
        if let running = inFlight[ref] { return try await running.value }

        let task = Task<PrayerLeafText, Error> { [client] in
            try await client.fetch(ref: ref)
        }
        inFlight[ref] = task
        defer { inFlight[ref] = nil }

        let result = try await task.value
        memory[ref] = result
        writeToDisk(result, for: ref)
        return result
    }

    func isCached(_ ref: String) -> Bool {
        memory[ref] != nil || FileManager.default.fileExists(atPath: fileURL(for: ref).path)
    }

    /// Fetches every ref, ignoring individual failures. Reports progress 0...1.
    func prefetch(refs: [String], progress: @Sendable @escaping (Double) -> Void) async {
        let unique = Array(Set(refs))
        guard !unique.isEmpty else { progress(1); return }
        var done = 0
        await withTaskGroup(of: Void.self) { group in
            var iterator = unique.makeIterator()
            var active = 0
            func launch(_ ref: String, group: inout TaskGroup<Void>) {
                group.addTask { _ = try? await self.text(for: ref) }
            }
            while active < 6, let ref = iterator.next() { launch(ref, group: &group); active += 1 }
            while await group.next() != nil {
                done += 1
                progress(Double(done) / Double(unique.count))
                if let ref = iterator.next() { launch(ref, group: &group) }
            }
        }
    }

    func clearDiskCache() {
        memory.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func diskCacheSize() -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    // MARK: - Disk

    private func fileURL(for ref: String) -> URL {
        let digest = SHA256.hash(data: Data(ref.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: digest + ".json")
    }

    private func readFromDisk(_ ref: String) -> PrayerLeafText? {
        guard let data = try? Data(contentsOf: fileURL(for: ref)) else { return nil }
        return try? JSONDecoder().decode(PrayerLeafText.self, from: data)
    }

    private func writeToDisk(_ text: PrayerLeafText, for ref: String) {
        guard let data = try? JSONEncoder().encode(text) else { return }
        try? data.write(to: fileURL(for: ref), options: .atomic)
    }
}
