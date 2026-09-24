import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var records: [PlaceRecord]
    @AppStorage("SeeZMemo.saveCapturedToLibrary") private var saveToLibrary = true
    @AppStorage("SeeZMemo.autoSync") private var autoSync = false
    @AppStorage("SeeZMemo.wifiOnly") private var wifiOnly = true
    @AppStorage("SeeZMemo.syncFolderName") private var folderName = ""
    @AppStorage("SeeZMemo.syncFolderBookmark") private var folderBookmark = Data()
    @AppStorage("SeeZMemo.lastSync") private var lastSync = 0.0
    @State private var exportDocument: SeeZBackupDocument?
    @State private var importing = false
    @State private var selectingFolder = false
    @State private var pendingImport: SeeZBackupArchive?
    @State private var showImportChoice = false
    @State private var showFirstSync = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("一般設定") {
                Toggle("拍攝照片同步到手機相簿", isOn: $saveToLibrary)
                Link("開啟 iPhone App 權限設定", destination: URL(string: UIApplication.openSettingsURLString)!)
            }
            Section("資料同步") {
                HStack {
                    Text("雲端資料夾"); Spacer(); Text(folderName.isEmpty ? "尚未設定" : folderName).foregroundStyle(.secondary).lineLimit(1)
                    Button { selectingFolder = true } label: { Image(systemName: "folder.badge.gearshape").frame(width: 44, height: 44) }.accessibilityLabel("設定雲端位置")
                }
                Toggle("自動同步", isOn: $autoSync)
                Toggle("僅使用 Wi-Fi", isOn: $wifiOnly)
                Button("立即同步", systemImage: "arrow.triangle.2.circlepath") { beginSync() }
                if lastSync > 0 { LabeledContent("最後成功同步", value: Date(timeIntervalSince1970: lastSync).formatted()) }
            }
            Section("備份與匯入") {
                Button("建立完整備份到雲端硬碟", systemImage: "externaldrive.badge.plus") { prepareExport() }
                Button("匯入備份", systemImage: "square.and.arrow.down") { importing = true }
            }
            Section("資料統計") {
                LabeledContent("草稿", value: "\(records.filter(\.isDraft).count)")
                LabeledContent("完成紀錄", value: "\(records.filter { !$0.isDraft }.count)")
                LabeledContent("照片", value: "\(records.reduce(0) { $0 + $1.photos.count })")
            }
            Section("移除 App 前準備") {
                NavigationLink("選擇是否保留資料") { RemovalPreparationView() }
            }
            Section("關於") {
                LabeledContent("程式", value: "店家大頭針")
                LabeledContent("版本", value: "V\(appVersion) (\(buildNumber))")
                LabeledContent("程式設計者", value: AppBuildInfo.developerName)
                Button(action: openFeedbackEmail) {
                    HStack(spacing: 12) {
                        Text("使用回饋信箱")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(AppBuildInfo.feedbackEmail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("寄送使用回饋至 \(AppBuildInfo.feedbackEmail)")
            }
        }
        .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }), document: exportDocument, contentType: .seezBackup, defaultFilename: "SeeZMemo_Backup") { result in message = (try? result.get()) != nil ? "完整備份已儲存。" : "備份失敗。" }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.seezBackup, .json]) { readImport($0) }
        .fileImporter(isPresented: $selectingFolder, allowedContentTypes: [.folder]) { saveFolder($0) }
        .confirmationDialog("匯入這份備份？", isPresented: $showImportChoice) {
            Button("合併並排除重複資料") { restore(.merge) }
            Button("清除現有資料後還原", role: .destructive) { restore(.replace) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("尚未建立第一份同步資料", isPresented: $showFirstSync) { Button("建立第一份同步資料並同步") { performSync() }; Button("取消", role: .cancel) {} } message: { Text("是否將目前 iPhone 資料寫入雲端並開始同步？") }
        .alert("店家大頭針", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} } message: { Text(message ?? "") }
    }

    private func prepareExport() { do { exportDocument = SeeZBackupDocument(archive: try BackupService.makeArchive(context: context)) } catch { message = error.localizedDescription } }
    private var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0" }
    private var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "8" }
    private func openFeedbackEmail() {
        guard let url = URL(string: "mailto:\(AppBuildInfo.feedbackEmail)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIPasteboard.general.string = AppBuildInfo.feedbackEmail
            message = "裝置沒有可用的郵件 App，已複製使用回饋信箱。"
        }
    }
    private func readImport(_ result: Result<URL, Error>) { do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; let archive = try BackupService.decoder.decode(SeeZBackupArchive.self, from: Data(contentsOf: url)); try BackupService.validate(archive); pendingImport = archive; showImportChoice = true } catch { message = error.localizedDescription } }
    private func restore(_ mode: RestoreMode) { guard let pendingImport else { return }; do { try SafetyBackupStore.save(try BackupService.makeArchive(context: context)); try BackupService.restore(pendingImport, mode: mode, context: context); message = "資料還原完成。" } catch { message = error.localizedDescription } }
    private func saveFolder(_ result: Result<URL, Error>) { do { let url = try result.get(); folderBookmark = try url.bookmarkData(options: .minimalBookmark); folderName = url.lastPathComponent } catch { message = error.localizedDescription } }
    private func folderURL() throws -> URL { var stale = false; let url = try URL(resolvingBookmarkData: folderBookmark, options: .withoutUI, bookmarkDataIsStale: &stale); if stale { throw BackupError.unreadable }; return url }
    private func beginSync() { guard !folderBookmark.isEmpty else { message = "尚未設定雲端資料夾，請點右側圖示選擇資料夾。"; return }; do { let folder = try folderURL(); let access = folder.startAccessingSecurityScopedResource(); defer { if access { folder.stopAccessingSecurityScopedResource() } }; if !FileManager.default.fileExists(atPath: folder.appendingPathComponent(SyncService.filename).path) { showFirstSync = true } else { performSync() } } catch { message = error.localizedDescription } }
    private func performSync() {
        Task {
            guard await SyncConnectivity.isAllowed(wifiOnly: wifiOnly) else {
                message = "目前不是 Wi-Fi 連線；可連接 Wi-Fi，或關閉「僅使用 Wi-Fi」後再同步。"
                return
            }
            do {
                _ = try SyncService.synchronize(folder: folderURL(), context: context, cloudWins: true)
                lastSync = Date.now.timeIntervalSince1970
                message = "同步完成。"
            } catch { message = error.localizedDescription }
        }
    }
}

private struct RemovalPreparationView: View {
    @Environment(\.modelContext) private var context
    @State private var document: SeeZBackupDocument?
    @State private var understands = false
    var body: some View { Form {
        Section { Text("iOS 刪除 App 時會移除本機資料；請先在此選擇是否建立可還原備份。").foregroundStyle(.secondary) }
        Section("保留資料（建議）") { Text("建立並驗證完整備份，刪除 App 後可重新安裝並還原。"); Button("建立可還原備份") { document = try? SeeZBackupDocument(archive: BackupService.makeArchive(context: context)) } }
        Section("不保留本機資料") { Toggle("我了解刪除 App 後，本機資料無法復原", isOn: $understands); Text("設定 → 一般 → iPhone 儲存空間 → 店家大頭針\n「卸載 App」保留本機資料；「刪除 App」移除本機資料。").foregroundStyle(.secondary) }
    }.navigationTitle("移除 App 前準備").fileExporter(isPresented: Binding(get: { document != nil }, set: { if !$0 { document = nil } }), document: document, contentType: .seezBackup, defaultFilename: "SeeZMemo_Backup") { _ in } }
}
