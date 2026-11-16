import Foundation

struct TweakPackage: Identifiable, Hashable {
    var id: String { package }
    let package: String
    let name: String
    let version: String
    let architecture: String
    let description: String
}

struct BackupManifest: Codable {
    let formatVersion: Int
    let createdAt: Date
    let deviceOS: String
    let jailbreak: String
    let packages: [BackupPackage]
    let includedSources: Bool
    let includedPreferences: Bool
}

struct BackupPackage: Codable, Identifiable {
    var id: String { package }
    let package: String
    let name: String
    let version: String
    let architecture: String
    let description: String
}
