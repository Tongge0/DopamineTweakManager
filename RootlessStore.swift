import Foundation

enum StoreError: LocalizedError {
    case missingStatus
    case unreadable(String)
    case invalidManifest
    case noPackages

    var errorDescription: String? {
        switch self {
        case .missingStatus: return "Không tìm thấy dpkg status trong các đường dẫn Rootless phổ biến."
        case .unreadable(let p): return "Không đọc được: \(p). Có thể app chưa có quyền truy cập."
        case .invalidManifest: return "Backup không hợp lệ hoặc thiếu manifest.json."
        case .noPackages: return "Chưa chọn package nào."
        }
    }
}

final class RootlessStore {
    static let shared = RootlessStore()
    private let fm = FileManager.default

    private let statusPaths = [
        "/var/jb/var/lib/dpkg/status",
        "/var/jb/lib/dpkg/status"
    ]
    private let sourcesPath = "/var/jb/etc/apt/sources.list.d"
    private let prefsPath = "/var/mobile/Library/Preferences"
    private let archivesPath = "/var/jb/var/cache/apt/archives"

    private init() {}

    func loadPackages() throws -> [TweakPackage] {
        guard let path = statusPaths.first(where: { fm.isReadableFile(atPath: $0) }) else {
            throw StoreError.missingStatus
        }
        guard let data = fm.contents(atPath: path),
              let text = String(data: data, encoding: .utf8) else {
            throw StoreError.unreadable(path)
        }

        return text.components(separatedBy: "\n\n").compactMap { paragraph in
            let fields = parseFields(paragraph)
            guard let package = fields["Package"],
                  let status = fields["Status"],
                  status.contains("installed") else { return nil }
            return TweakPackage(
                package: package,
                name: fields["Name"] ?? package,
                version: fields["Version"] ?? "unknown",
                architecture: fields["Architecture"] ?? "unknown",
                description: fields["Description"] ?? ""
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func parseFields(_ paragraph: String) -> [String: String] {
        var result: [String: String] = [:]
        var current: String?
        for line in paragraph.components(separatedBy: .newlines) {
            if line.hasPrefix(" "), let key = current {
                result[key, default: ""] += "\n" + line
            } else if let range = line.range(of: ": ") {
                let key = String(line[..<range.lowerBound])
                result[key] = String(line[range.upperBound...])
                current = key
            } else {
                current = nil
            }
        }
        return result
    }

    func makeBackup(selected: [TweakPackage], includeSources: Bool,
                    includePreferences: Bool) throws -> URL {
        guard !selected.isEmpty else { throw StoreError.noPackages }

        let root = fm.temporaryDirectory.appendingPathComponent("DopamineBackup-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let debFolder = root.appendingPathComponent("deb-cache", isDirectory: true)
        try fm.createDirectory(at: debFolder, withIntermediateDirectories: true)

        let manifest = BackupManifest(
            formatVersion: 1,
            createdAt: Date(),
            deviceOS: ProcessInfo.processInfo.operatingSystemVersionString,
            jailbreak: "Dopamine Rootless",
            packages: selected.map {
                BackupPackage(package: $0.package, name: $0.name, version: $0.version,
                              architecture: $0.architecture, description: $0.description)
            },
            includedSources: includeSources,
            includedPreferences: includePreferences
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: root.appendingPathComponent("manifest.json"), options: .atomic)

        try "Backup manifest only guarantees package names and versions. DEB files are copied only if present in local apt cache.".write(
            to: root.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8
        )

        // DEB chỉ được copy nếu đã có trong apt cache.
        if let cached = try? fm.contentsOfDirectory(atPath: archivesPath) {
            for file in cached where file.hasSuffix(".deb") {
                if selected.contains(where: { file.hasPrefix($0.package + "_") }) {
                    try? fm.copyItem(at: URL(fileURLWithPath: archivesPath).appendingPathComponent(file),
                                     to: debFolder.appendingPathComponent(file))
                }
            }
        }

        if includeSources && fm.isReadableFile(atPath: sourcesPath) {
            try fm.copyItem(at: URL(fileURLWithPath: sourcesPath),
                            to: root.appendingPathComponent("sources", isDirectory: true))
        }

        if includePreferences && fm.isReadableFile(atPath: prefsPath) {
            let dest = root.appendingPathComponent("preferences", isDirectory: true)
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            let names = (try? fm.contentsOfDirectory(atPath: prefsPath)) ?? []
            for name in names where name.hasSuffix(".plist") {
                try? fm.copyItem(at: URL(fileURLWithPath: prefsPath).appendingPathComponent(name),
                                 to: dest.appendingPathComponent(name))
            }
        }
        return root
    }

    func readManifest(folder: URL) throws -> BackupManifest {
        let url = folder.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url) else { throw StoreError.invalidManifest }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let value = try? decoder.decode(BackupManifest.self, from: data),
              value.formatVersion == 1 else { throw StoreError.invalidManifest }
        return value
    }
}
