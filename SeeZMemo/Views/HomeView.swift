import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<PlaceRecord> { $0.isDraft }, sort: \PlaceRecord.updatedAt, order: .reverse)
    private var drafts: [PlaceRecord]

    @State private var cameraPresented = false
    @State private var editingRecord: PlaceRecord?
    @State private var draftsExpanded = true
    @State private var nearbyRadius: CLLocationDistance = AppLimits.nearbyMapRadius
    @State private var automaticSyncRunning = false
    @AppStorage("SeeZMemo.autoSync") private var autoSync = false
    @AppStorage("SeeZMemo.wifiOnly") private var wifiOnly = true
    @AppStorage("SeeZMemo.syncFolderBookmark") private var folderBookmark = Data()
    @AppStorage("SeeZMemo.lastSync") private var lastSync = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.95), .white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        cameraButton
                        draftsSection
                        mapLink
                        versionFooter
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { RecordsBrowserView() } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("紀錄資料清單")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }.accessibilityLabel("設定")
                        Button { createBlankDraft() } label: { Image(systemName: "plus") }.accessibilityLabel("直接新增店家")
                    }
                }
            }
            .fullScreenCover(isPresented: $cameraPresented) {
                CameraPicker { image in createDraft(with: image) }
                    .ignoresSafeArea()
            }
            .navigationDestination(isPresented: Binding(
                get: { editingRecord != nil },
                set: { if !$0 { editingRecord = nil } }
            )) {
                if let editingRecord { RecordEditorView(record: editingRecord) }
            }
            .task { runAutomaticSyncIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { runAutomaticSyncIfNeeded() }
            }
        }
    }

    private var cameraButton: some View {
        Button { cameraPresented = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 34)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.33, blue: 0.39), Color(red: 0.72, green: 0.02, blue: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 34)
                    .fill(.ultraThinMaterial.opacity(0.28))
                RoundedRectangle(cornerRadius: 34)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
                Ellipse()
                    .fill(.white.opacity(0.24))
                    .frame(width: 220, height: 70)
                    .blur(radius: 12)
                    .offset(y: -62)
                Image(systemName: "camera.fill")
                    .font(.system(size: 66, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.black)
                    .padding(28)
                    .background(.white.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.22), radius: 13, y: 8)
            }
            .frame(maxWidth: .infinity, minHeight: 218)
            .shadow(color: Color.red.opacity(0.28), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("拍照新增店家")
        .accessibilityIdentifier("home.camera")
    }

    private var draftsSection: some View {
        DisclosureGroup(isExpanded: $draftsExpanded) {
            VStack(spacing: 12) {
                if drafts.isEmpty {
                    ContentUnavailableView("尚無草稿", systemImage: "mappin.and.ellipse", description: Text("可以拍照或點右上角＋新增店家。"))
                        .frame(maxWidth: .infinity, minHeight: 145)
                } else {
                    ForEach(drafts) { record in
                        Button { editingRecord = record } label: { DraftRow(record: record) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Text("草稿").font(.title3.bold())
                Spacer()
                Text("\(drafts.count) 筆").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }

    private var mapLink: some View {
        NavigationLink {
            NearbyPlacesMapView(radius: $nearbyRadius)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("地圖").font(.title3.bold())
                    Text("查看目前位置方圓 \(radiusText(nearbyRadius)) 內的店家")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "mappin.and.ellipse.circle.fill")
                    .font(.system(size: 38))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.red, .blue)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text(AppBuildInfo.homeVersionText(version: displayVersion))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private var displayVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private func createBlankDraft() {
        let record = PlaceRecord()
        modelContext.insert(record)
        try? modelContext.save()
        editingRecord = record
    }

    private func createDraft(with image: UIImage) {
        guard let data = image.seezMemoJPEGData() else { return }
        let record = PlaceRecord()
        record.photos.append(PlacePhoto(imageData: data, sortOrder: 0))
        modelContext.insert(record)
        try? modelContext.save()
        Task { try? await PhotoLibraryService.saveCapturedImage(image) }
    }

    private func radiusText(_ radius: CLLocationDistance) -> String {
        radius < 1_000 ? "\(Int(radius)) 公尺" : String(format: "%g 公里", radius / 1_000)
    }

    private func runAutomaticSyncIfNeeded() {
        guard autoSync, !folderBookmark.isEmpty, !automaticSyncRunning else { return }
        automaticSyncRunning = true
        Task {
            defer { automaticSyncRunning = false }
            guard await SyncConnectivity.isAllowed(wifiOnly: wifiOnly) else { return }
            do {
                var stale = false
                let folder = try URL(resolvingBookmarkData: folderBookmark, options: .withoutUI, bookmarkDataIsStale: &stale)
                guard !stale else { return }
                _ = try SyncService.synchronize(folder: folder, context: modelContext, cloudWins: true)
                lastSync = Date.now.timeIntervalSince1970
            } catch {
                // Automatic synchronization stays quiet; the settings page keeps manual recovery available.
            }
        }
    }
}

private struct DraftRow: View {
    let record: PlaceRecord

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let data = record.sortedPhotos.first?.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
                }
            }
            .frame(width: 74, height: 74)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 5) {
                Text(record.displayName).font(.headline)
                Text(record.address.isEmpty ? record.coordinateText : record.address)
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Text(record.updatedAt, style: .relative).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct NearbyPlacesMapView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case map = "地圖"
        case list = "清單"
        var id: Self { self }
    }

    @Environment(\.openURL) private var openURL
    @Query(sort: \PlaceRecord.updatedAt, order: .reverse) private var records: [PlaceRecord]
    @Binding var radius: CLLocationDistance
    @State private var location = LocationService()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )
    @State private var mode: DisplayMode = .map
    @State private var selectedRecord: PlaceRecord?

    private var currentLocation: CLLocation? {
        guard let coordinate = location.coordinate else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var nearbyRecords: [PlaceRecord] {
        guard let currentLocation else { return [] }
        return records
            .filter { ($0.distance(from: currentLocation) ?? .greatestFiniteMagnitude) <= radius }
            .sorted { ($0.distance(from: currentLocation) ?? .greatestFiniteMagnitude) < ($1.distance(from: currentLocation) ?? .greatestFiniteMagnitude) }
    }

    var body: some View {
        Group {
            if mode == .map { nearbyMap } else { nearbyList }
        }
        .navigationTitle("附近店家")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(AppLimits.mapRadiusOptions, id: \.self) { option in
                        Button {
                            radius = option
                            centerOnUser()
                        } label: {
                            if option == radius {
                                Label(radiusText(option), systemImage: "checkmark")
                            } else {
                                Text(radiusText(option))
                            }
                        }
                    }
                } label: { Image(systemName: "gearshape") }
                .accessibilityLabel("設定地圖範圍")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Picker("顯示模式", selection: $mode) {
                ForEach(DisplayMode.allCases) { value in
                    Label(value.rawValue, systemImage: value == .map ? "mappin.and.ellipse" : "list.bullet").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(.regularMaterial)
        }
        .onAppear { location.requestLocation() }
        .onChange(of: location.coordinate?.latitude) { _, _ in centerOnUser() }
        .navigationDestination(isPresented: Binding(
            get: { selectedRecord != nil },
            set: { if !$0 { selectedRecord = nil } }
        )) {
            if let selectedRecord { RecordEditorView(record: selectedRecord) }
        }
    }

    private var nearbyMap: some View {
        Map(position: $position) {
            if let coordinate = location.coordinate {
                MapCircle(center: coordinate, radius: radius)
                    .foregroundStyle(.blue.opacity(0.08))
                    .stroke(.blue.opacity(0.35), lineWidth: 2)
                UserAnnotation()
            }
            ForEach(nearbyRecords) { record in
                if let coordinate = record.coordinate {
                    Annotation("", coordinate: coordinate) {
                        Button { copyAndOpenRoute(for: record) } label: {
                            VStack(spacing: 3) {
                                VStack(spacing: 1) {
                                    Text(record.displayName).font(.caption.bold())
                                    if !record.category.isEmpty {
                                        Text(record.category).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                .lineLimit(1)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 34)).foregroundStyle(.red).shadow(radius: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
        .overlay(alignment: .bottom) {
            Text(location.coordinate == nil ? "正在取得目前位置…" : "\(radiusText(radius)) 內共 \(nearbyRecords.count) 間店家")
                .font(.subheadline.bold())
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 8)
        }
    }

    private var nearbyList: some View {
        List(nearbyRecords) { record in
            HStack(spacing: 12) {
                Button { selectedRecord = record } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.displayName).font(.headline)
                        Text(record.category.isEmpty ? "未設定類型" : record.category).foregroundStyle(.secondary)
                        if let currentLocation, let distance = record.distance(from: currentLocation) {
                            Text(distanceText(distance)).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button { copyAndOpenRoute(for: record) } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill").font(.title2)
                }
                .accessibilityLabel("複製地址並開啟 Google Maps")
            }
        }
        .overlay {
            if location.coordinate != nil && nearbyRecords.isEmpty {
                ContentUnavailableView("範圍內尚無店家", systemImage: "map", description: Text("可用右上角齒輪調整距離。"))
            }
        }
    }

    private func centerOnUser() {
        guard let coordinate = location.coordinate else { return }
        let delta = max(0.01, radius / 45_000)
        position = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        ))
    }

    private func copyAndOpenRoute(for record: PlaceRecord) {
        let query = record.address.isEmpty ? record.coordinateText : record.address
        UIPasteboard.general.string = query
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let appURL = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving"), UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(encoded)") {
            openURL(webURL)
        }
    }

    private func radiusText(_ value: CLLocationDistance) -> String {
        value < 1_000 ? "\(Int(value)) 公尺" : String(format: "%g 公里", value / 1_000)
    }

    private func distanceText(_ value: CLLocationDistance) -> String {
        value < 1_000 ? "直線距離 \(Int(value.rounded())) 公尺" : String(format: "直線距離 %.1f 公里", value / 1_000)
    }
}
