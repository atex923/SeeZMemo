import MapKit
import SwiftUI

struct MapEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: PlaceRecord
    @State private var position: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var location = LocationService()
    @State private var message: String?
    @State private var isSearchingAddress = false
    @State private var coordinateIsNearby = false
    @FocusState private var addressFocused: Bool

    init(record: PlaceRecord) {
        self.record = record
        let coordinate = CLLocationCoordinate2D(latitude: record.latitude ?? 25.0330, longitude: record.longitude ?? 121.5654)
        _selectedCoordinate = State(initialValue: coordinate)
        _position = State(initialValue: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))))
    }

    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $position) {
                    Annotation("店家位置", coordinate: selectedCoordinate) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 43)).foregroundStyle(.red).shadow(radius: 4)
                    }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) { setCoordinate(coordinate) }
                }
                .overlay(alignment: .top) {
                    Text("輕點地圖修正大頭針位置").font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule()).padding(.top, 12)
                }
            }
            .frame(maxHeight: .infinity)

            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "location.fill").foregroundStyle(.red)
                        Text(String(format: "%.6f, %.6f", selectedCoordinate.latitude, selectedCoordinate.longitude))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(coordinateIsNearby ? .red : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer()
                    }
                    HStack(alignment: .top, spacing: 8) {
                        TextField("鄰近住址（可手動修正）", text: $record.address, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .focused($addressFocused)
                            .submitLabel(.search)
                            .onSubmit { searchAddress() }
                        Button { searchAddress() } label: {
                            Image(systemName: isSearchingAddress ? "hourglass" : "magnifyingglass")
                                .frame(width: 44, height: 44)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSearchingAddress || record.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("依地址重新定位")
                    }
                    Button { loadCoverPhotoGPS() } label: {
                        Label("載入首張照片 GPS", systemImage: "location.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    Button("套用位置") {
                        record.latitude = selectedCoordinate.latitude
                        record.longitude = selectedCoordinate.longitude
                        record.updatedAt = .now
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: addressFocused ? 230 : 300)
            .background(.regularMaterial)
        }
        .navigationTitle("修正位置").navigationBarTitleDisplayMode(.inline)
        .onChange(of: location.address) { _, address in if !address.isEmpty { record.address = address } }
        .onChange(of: location.country) { _, country in
            if record.countryWasManuallyEdited != true, !country.isEmpty { record.country = country }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    addressFocused = false
                } label: {
                    Label("隱藏鍵盤", systemImage: "keyboard.chevron.compact.down")
                }
            }
        }
        .alert("店家大頭針", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        coordinateIsNearby = false
        updateMap(to: coordinate)
        Task { await location.reverseGeocode(coordinate) }
    }

    private func updateMap(to coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
        }
    }

    private func loadCoverPhotoGPS() {
        guard let photo = record.sortedPhotos.first else {
            message = "尚未加入首張照片。"
            return
        }
        guard let coordinate = photo.gpsCoordinate ?? PhotoMetadataService.coordinate(from: photo.imageData) else {
            message = "首張照片沒有保存的 GPS 座標。舊版匯入並壓縮過的照片可能已失去 GPS，請重新從相簿加入原始照片。"
            return
        }
        setCoordinate(coordinate)
        message = "已載入首張照片 GPS，請確認位置後按「套用位置」。"
    }

    private func searchAddress() {
        let query = record.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isSearchingAddress else { return }
        addressFocused = false
        isSearchingAddress = true
        Task {
            defer { isSearchingAddress = false }
            let geocoder = CLGeocoder()
            if let mark = try? await geocoder.geocodeAddressString(
                query,
                in: nil,
                preferredLocale: Locale(identifier: "zh_Hant_TW")
            ).first,
               let coordinate = mark.location?.coordinate {
                coordinateIsNearby = false
                updateMap(to: coordinate)
                let address = formattedAddress(from: mark)
                if !address.isEmpty { record.address = address }
                if record.countryWasManuallyEdited != true { record.country = mark.country }
                return
            }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(center: selectedCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25))
            do {
                let response = try await MKLocalSearch(request: request).start()
                let origin = CLLocation(latitude: selectedCoordinate.latitude, longitude: selectedCoordinate.longitude)
                guard let nearest = response.mapItems.min(by: {
                    ($0.placemark.location?.distance(from: origin) ?? .greatestFiniteMagnitude) <
                    ($1.placemark.location?.distance(from: origin) ?? .greatestFiniteMagnitude)
                }) else {
                    message = "搜尋不到這個地址，請修改文字後再試。"
                    return
                }
                coordinateIsNearby = true
                updateMap(to: nearest.placemark.coordinate)
                let address = formattedAddress(from: nearest.placemark)
                if !address.isEmpty { record.address = address }
                if record.countryWasManuallyEdited != true { record.country = nearest.placemark.country }
                message = "找不到完全相符的地址，已載入最近的地址座標；紅色座標表示鄰近點位。"
            } catch {
                message = "搜尋不到這個地址，請修改文字後再試。"
            }
        }
    }

    private func formattedAddress(from mark: CLPlacemark) -> String {
        let street = [mark.thoroughfare, mark.subThoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined()
        return [mark.administrativeArea, mark.locality, mark.subLocality, street]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, value in if !result.contains(value) { result.append(value) } }
            .joined()
    }
}
