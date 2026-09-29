import Foundation
import Network
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    static let seezBackup = UTType(filenameExtension: "seezbackup", conformingTo: .json) ?? .json
    static let seezSync = UTType(filenameExtension: "seezmemosync", conformingTo: .json) ?? .json
}

struct PhotoArchive: Codable, Identifiable {
    var id: UUID; var data: Data; var createdAt: Date; var sortOrder: Int
    var gpsLatitude: Double?; var gpsLongitude: Double?
}

struct RecordArchive: Codable, Identifiable {
    var id: UUID; var name: String; var category: String; var address: String
    var latitude: Double?; var longitude: Double?; var note: String; var impressions: String?
    var country: String?; var countryWasManuallyEdited: Bool?; var recognizedText: String
    var createdAt: Date; var updatedAt: Date; var visitDate: Date?; var isDraft: Bool
    var photos: [PhotoArchive]

    init(_ value: PlaceRecord) {
        id = value.id; name = value.name; category = value.category; address = value.address
        latitude = value.latitude; longitude = value.longitude; note = value.note; impressions = value.impressions
        country = value.country; countryWasManuallyEdited = value.countryWasManuallyEdited
        recognizedText = value.recognizedText; createdAt = value.createdAt; updatedAt = value.updatedAt
        visitDate = value.visitDate; isDraft = value.isDraft
        photos = value.sortedPhotos.map { .init(id: $0.id, data: $0.imageData, createdAt: $0.createdAt, sortOrder: $0.sortOrder, gpsLatitude: $0.gpsLatitude, gpsLongitude: $0.gpsLongitude) }
    }
}

struct SeeZBackupArchive: Codable {
    static let schemaVersion = 1
    var schemaVersion = Self.schemaVersion
    var appVersion: String
    var createdAt: Date
    var records: [RecordArchive]
    var typeEntries: [PlaceTypeEntry]
    var recordCount: Int { records.count }
    var photoCount: Int { records.reduce(0) { $0 + $1.photos.count } }
}

struct SeeZSyncEnvelope: Codable {
    var schemaVersion = 1
    var updatedAt: Date
    var updatedBy: String
    var current: SeeZBackupArchive
    var history: [SeeZBackupArchive]
}

struct SeeZBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.seezBackup, .json] }
    var archive: SeeZBackupArchive
    init(archive: SeeZBackupArchive) { self.archive = archive }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.unreadable }
        archive = try BackupService.decoder.decode(SeeZBackupArchive.self, from: data)
        try BackupService.validate(archive)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try BackupService.encoder.encode(archive))
    }
}

enum RestoreMode { case merge, replace }
enum BackupError: LocalizedError {
    case unreadable, unsupported(Int), verification
    var errorDescription: String? {
        switch self {
        case .unreadable: "無法讀取備份檔。"
        case .unsupported(let value): "不支援備份格式版本 \(value)。"
        case .verification: "備份驗證失敗。"
        }
    }
}

enum SyncConnectivity {
    static func isAllowed(wifiOnly: Bool) async -> Bool {
        guard wifiOnly else { return true }
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "SeeZMemo.SyncConnectivity")
            monitor.pathUpdateHandler = { path in
                let allowed = path.status == .satisfied && path.usesInterfaceType(.wifi)
                monitor.cancel()
                continuation.resume(returning: allowed)
            }
            monitor.start(queue: queue)
        }
    }
}

enum BackupService {
    static var encoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.sortedKeys]; return e }
    static var decoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }

    @MainActor static func makeArchive(context: ModelContext) throws -> SeeZBackupArchive {
        let values = try context.fetch(FetchDescriptor<PlaceRecord>())
        return .init(appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.1", createdAt: .now, records: values.map(RecordArchive.init), typeEntries: PlaceTypeMemory().entries)
    }

    static func validate(_ archive: SeeZBackupArchive) throws {
        guard archive.schemaVersion == SeeZBackupArchive.schemaVersion else { throw BackupError.unsupported(archive.schemaVersion) }
        guard Set(archive.records.map(\.id)).count == archive.records.count else { throw BackupError.verification }
    }

    @MainActor static func restore(_ archive: SeeZBackupArchive, mode: RestoreMode, context: ModelContext) throws {
        try validate(archive)
        let existing = try context.fetch(FetchDescriptor<PlaceRecord>())
        if mode == .replace { existing.forEach(context.delete) }
        var byID = Dictionary(uniqueKeysWithValues: (mode == .replace ? [] : existing).map { ($0.id, $0) })
        for item in archive.records {
            if let old = byID[item.id], old.updatedAt >= item.updatedAt { continue }
            if let old = byID[item.id] { context.delete(old) }
            let value = PlaceRecord(id: item.id, name: item.name, category: item.category, address: item.address, latitude: item.latitude, longitude: item.longitude, note: item.note, impressions: item.impressions, country: item.country, countryWasManuallyEdited: item.countryWasManuallyEdited, recognizedText: item.recognizedText, createdAt: item.createdAt, updatedAt: item.updatedAt, visitDate: item.visitDate, isDraft: item.isDraft)
            item.photos.forEach { value.photos.append(PlacePhoto(id: $0.id, imageData: $0.data, sortOrder: $0.sortOrder, createdAt: $0.createdAt, gpsLatitude: $0.gpsLatitude, gpsLongitude: $0.gpsLongitude)) }
            context.insert(value); byID[item.id] = value
        }
        try context.save()
        PlaceTypeMemory().replace(with: archive.typeEntries)
    }
}

enum SafetyBackupStore {
    static var folder: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SeeZMemo/SafetyBackups", isDirectory: true) }
    static func save(_ archive: SeeZBackupArchive) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "Safety_\(Int(Date.now.timeIntervalSince1970)).seezbackup"
        try BackupService.encoder.encode(archive).write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]).sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
        for url in files.dropFirst(3) { try? FileManager.default.removeItem(at: url) }
    }
}

@MainActor enum SyncService {
    static let filename = "SeeZMemo.seezmemosync"
    static func synchronize(folder: URL, context: ModelContext, cloudWins: Bool) throws -> SeeZSyncEnvelope {
        let local = try BackupService.makeArchive(context: context)
        try SafetyBackupStore.save(local)
        let access = folder.startAccessingSecurityScopedResource(); defer { if access { folder.stopAccessingSecurityScopedResource() } }
        let url = folder.appendingPathComponent(filename)
        let envelope: SeeZSyncEnvelope
        if FileManager.default.fileExists(atPath: url.path) {
            let remote = try BackupService.decoder.decode(SeeZSyncEnvelope.self, from: Data(contentsOf: url))
            var merged = Dictionary(uniqueKeysWithValues: local.records.map { ($0.id, $0) })
            for item in remote.current.records {
                if let old = merged[item.id] { merged[item.id] = cloudWins ? item : (old.updatedAt >= item.updatedAt ? old : item) } else { merged[item.id] = item }
            }
            let current = SeeZBackupArchive(appVersion: local.appVersion, createdAt: .now, records: Array(merged.values), typeEntries: local.typeEntries)
            envelope = .init(updatedAt: .now, updatedBy: UIDevice.current.name, current: current, history: Array(([remote.current] + remote.history).prefix(3)))
        } else {
            envelope = .init(updatedAt: .now, updatedBy: UIDevice.current.name, current: local, history: [])
        }
        let data = try BackupService.encoder.encode(envelope)
        let temporary = folder.appendingPathComponent(".SeeZMemo.tmp")
        try data.write(to: temporary, options: [.atomic, .completeFileProtection])
        _ = try BackupService.decoder.decode(SeeZSyncEnvelope.self, from: Data(contentsOf: temporary))
        if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary) } else { try FileManager.default.moveItem(at: temporary, to: url) }
        let verified = try BackupService.decoder.decode(SeeZSyncEnvelope.self, from: Data(contentsOf: url))
        try BackupService.restore(verified.current, mode: .merge, context: context)
        return verified
    }
}
