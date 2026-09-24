import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

struct RecordsBrowserView: View {
    enum DisplayMode { case list, map }
    enum SortOption: String, CaseIterable, Identifiable {
        case time = "時間"
        case name = "名稱"
        case country = "國家"
        case distance = "使用者距離"
        var id: Self { self }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlaceRecord.updatedAt, order: .reverse) private var records: [PlaceRecord]
    @State private var location = LocationService()
    @State private var mode: DisplayMode = .list
    @State private var sortOption: SortOption = .time
    @State private var searchText = ""
    @State private var selectedRecord: PlaceRecord?
    @State private var pendingDelete: PlaceRecord?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapPosition: MapCameraPosition = .automatic

    private var currentLocation: CLLocation? {
        guard let coordinate = location.coordinate else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var filteredRecords: [PlaceRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = records.filter { record in
            guard !query.isEmpty else { return true }
            return [record.name, record.category, record.note, record.impressions ?? "", record.address, record.country ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
        return filtered.sorted(by: recordComesFirst)
    }

    private var visibleMapRecords: [PlaceRecord] {
        guard let region = visibleRegion else { return filteredRecords.filter { $0.coordinate != nil } }
        return filteredRecords.filter { record in
            guard let coordinate = record.coordinate else { return false }
            return region.contains(coordinate)
        }
    }

    var body: some View {
        Group {
            if mode == .list { recordsList } else { recordsMap }
        }
        .navigationTitle("紀錄資料")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜尋名稱、類型、國家或資料")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button { mode = .map } label: {
                        Image(systemName: mode == .map ? "mappin.and.ellipse.circle.fill" : "mappin.and.ellipse")
                    }
                    .accessibilityLabel("地圖模式")
                    Button { mode = .list } label: {
                        Image(systemName: mode == .list ? "list.bullet.circle.fill" : "list.bullet")
                    }
                    .accessibilityLabel("清單模式")
                }
            }
        }
        .onAppear { location.requestLocation() }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            if mode == .map, let coordinate = location.coordinate {
                mapPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                ))
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedRecord != nil },
            set: { if !$0 { selectedRecord = nil } }
        )) {
            if let selectedRecord { RecordEditorView(record: selectedRecord) }
        }
        .alert("刪除紀錄？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("取消", role: .cancel) { pendingDelete = nil }
            Button("刪除", role: .destructive) { deletePendingRecord() }
        } message: {
            Text("照片與店家資料將一起刪除，此動作無法復原。")
        }
    }

    private var recordsList: some View {
        List {
            Section {
                Menu {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                        .disabled(option == .distance && currentLocation == nil)
                    }
                } label: {
                    HStack {
                        Label("排序", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text(sortOption.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }

                if currentLocation == nil {
                    Text("開啟定位後可使用距離排序")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if filteredRecords.isEmpty {
                ContentUnavailableView("尚無符合紀錄", systemImage: "list.bullet.rectangle", description: Text("新增店家後會顯示在這裡。"))
            } else {
                ForEach(filteredRecords) { record in
                    Button { selectedRecord = record } label: {
                        RecordListRow(record: record, currentLocation: currentLocation)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { pendingDelete = record } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var recordsMap: some View {
        Map(position: $mapPosition) {
            if location.coordinate != nil { UserAnnotation() }
            ForEach(visibleMapRecords) { record in
                if let coordinate = record.coordinate {
                    Annotation("", coordinate: coordinate) {
                        Button { selectedRecord = record } label: {
                            VStack(spacing: 3) {
                                Text(record.displayName).font(.caption.bold()).lineLimit(1)
                                if !record.category.isEmpty {
                                    Text(record.category).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 32)).foregroundStyle(.red).shadow(radius: 2)
                            }
                            .padding(.horizontal, 7).padding(.top, 5)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
        .onMapCameraChange(frequency: .onEnd) { context in visibleRegion = context.region }
        .overlay(alignment: .bottom) {
            Text("瀏覽範圍共 \(visibleMapRecords.count) 間店家")
                .font(.subheadline.bold())
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 14)
        }
    }

    private func recordComesFirst(_ lhs: PlaceRecord, _ rhs: PlaceRecord) -> Bool {
        switch sortOption {
        case .time:
            return lhs.createdAt > rhs.createdAt
        case .name:
            return strokeOrdered(lhs.displayName, rhs.displayName)
        case .country:
            let left = lhs.displayCountry
            let right = rhs.displayCountry
            if left == right { return strokeOrdered(lhs.displayName, rhs.displayName) }
            return strokeOrdered(left, right)
        case .distance:
            guard let currentLocation else { return lhs.createdAt > rhs.createdAt }
            return (lhs.distance(from: currentLocation) ?? .greatestFiniteMagnitude) <
                (rhs.distance(from: currentLocation) ?? .greatestFiniteMagnitude)
        }
    }

    private func strokeOrdered(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [], range: nil, locale: Locale(identifier: "zh_Hant@collation=stroke")) == .orderedAscending
    }

    private func deletePendingRecord() {
        guard let pendingDelete else { return }
        modelContext.delete(pendingDelete)
        try? modelContext.save()
        self.pendingDelete = nil
    }
}

private struct RecordListRow: View {
    let record: PlaceRecord
    let currentLocation: CLLocation?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = record.sortedPhotos.first?.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 62, height: 62)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.displayName).font(.headline).lineLimit(1)
                    if record.isDraft { Text("草稿").font(.caption2).foregroundStyle(.orange) }
                }
                Text([record.category, record.country ?? ""].filter { !$0.isEmpty }.joined(separator: "・"))
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text(record.createdAt, format: .dateTime.year().month().day())
                    if let currentLocation, let distance = record.distance(from: currentLocation) {
                        Text("・\(distanceText(distance))")
                    }
                }
                .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func distanceText(_ distance: CLLocationDistance) -> String {
        distance < 1_000 ? "\(Int(distance.rounded())) 公尺" : String(format: "%.1f 公里", distance / 1_000)
    }
}

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeRange = (center.latitude - span.latitudeDelta / 2)...(center.latitude + span.latitudeDelta / 2)
        let longitudeRange = (center.longitude - span.longitudeDelta / 2)...(center.longitude + span.longitudeDelta / 2)
        return latitudeRange.contains(coordinate.latitude) && longitudeRange.contains(coordinate.longitude)
    }
}
