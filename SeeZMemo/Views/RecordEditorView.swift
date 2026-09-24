import PhotosUI
import SwiftData
import SwiftUI

struct RecordEditorView: View {
    private enum InputField: Hashable {
        case name, category, details, impressions, address, country
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: PlaceRecord

    @State private var location = LocationService()
    @State private var types = PlaceTypeMemory()
    @State private var cameraPresented = false
    @State private var ocrCameraPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showPhotoActions = false
    @State private var showOCRSources = false
    @State private var showOCRChoices = false
    @State private var ocrChoices: [String] = []
    @State private var isRecognizing = false
    @State private var showVisitCalendar = false
    @State private var sharePayload: JournalSharePayload?
    @State private var message: String?
    @AppStorage("SeeZMemo.saveCapturedToLibrary") private var saveCapturedToLibrary = true
    @FocusState private var focusedField: InputField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoSection
                nameSection
                categorySection
                detailsSection
                impressionsSection
                locationSection
                countrySection
                recordTimeSection
                visitDateSection
                shareSection
                actionSection
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(record.isDraft ? "新增店家" : "店家資料")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    focusedField = nil
                } label: {
                    Label("隱藏鍵盤", systemImage: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("隱藏鍵盤")
            }
        }
        .onAppear {
            if let coordinate = record.coordinate {
                Task { await location.reverseGeocode(coordinate) }
            } else {
                location.requestLocation()
            }
        }
        .onChange(of: location.coordinate?.latitude) { _, _ in syncLocation() }
        .onChange(of: location.address) { _, _ in syncLocation() }
        .onChange(of: location.country) { _, _ in syncCountry() }
        .onChange(of: photoSelection) { _, items in Task { await importPhotos(items) } }
        .fullScreenCover(isPresented: $cameraPresented) {
            CameraPicker { image in addImage(image) }.ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $ocrCameraPresented) {
            CameraPicker { image in recognize(image) }.ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoActions) {
            PhotoSourceSheet(cameraPresented: $cameraPresented, photoSelection: $photoSelection)
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(items: payload.items)
        }
        .confirmationDialog("辨識店家名稱", isPresented: $showOCRSources, titleVisibility: .visible) {
            Button("辨識首張照片") { recognizeFromCover() }
            Button("重新拍攝招牌") { ocrCameraPresented = true }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("選擇辨識結果", isPresented: $showOCRChoices, titleVisibility: .visible) {
            ForEach(ocrChoices.prefix(10), id: \.self) { choice in
                Button(choice) { record.name = choice; touch() }
            }
            Button("取消", role: .cancel) {}
        }
        .alert("店家大頭針", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "照片", detail: "\(record.photos.count) / \(AppLimits.maximumPhotos)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(record.sortedPhotos) { photo in
                        photoCard(photo)
                    }
                    if record.canAddPhoto {
                        Button { showPhotoActions = true } label: {
                            VStack(spacing: 9) {
                                Image(systemName: "plus.circle.fill").font(.title)
                                Text("加入照片").font(.subheadline.bold())
                            }
                            .frame(width: 130, height: 142)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func photoCard(_ photo: PlacePhoto) -> some View {
        let isCover = record.sortedPhotos.first?.id == photo.id
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if let image = UIImage(data: photo.imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 154, height: 112).clipped()
                }
                Button {
                    makeCover(photo)
                } label: {
                    Label(isCover ? "首張" : "設為首張", systemImage: isCover ? "star.fill" : "star")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isCover ? .orange : .accentColor)
                .disabled(isCover)
            }
            .frame(width: 154, height: 142)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Button(role: .destructive) { delete(photo) } label: {
                Image(systemName: "trash.fill").padding(9).background(.ultraThinMaterial, in: Circle())
            }
            .padding(7)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店家名稱", detail: nil)
            TextField("輸入店家名稱", text: $record.name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .onChange(of: record.name) { _, _ in touch() }
            Button { showOCRSources = true } label: {
                Label(isRecognizing ? "辨識中…" : "拍照辨識", systemImage: "viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecognizing || record.photos.isEmpty)
            Text("支援繁體中文、English、日本語、한국어").font(.caption).foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店家類型", detail: nil)
            TextField("例如：拉麵、甜點、特色雜貨", text: $record.category)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .category)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .onChange(of: record.category) { _, _ in touch() }
            HStack(spacing: 6) {
                ForEach(types.quickValues.prefix(4), id: \.self) { value in
                    Button { record.category = value; touch() } label: {
                        Text(value)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .padding(.horizontal, 3)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    if types.remainingValues.isEmpty {
                        Text("尚無其他類型")
                    } else {
                        ForEach(types.remainingValues, id: \.self) { value in
                            Button(value) { record.category = value; touch() }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill").font(.title3)
                }
                .accessibilityLabel("更多店家類型")
            }
        }
        .cardStyle()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "店家資料", detail: nil)
            TextField("菜單、營業時間、必買商品或其他資料", text: $record.note, axis: .vertical)
                .lineLimit(3...7)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .details)
                .onChange(of: record.note) { _, _ in touch() }
        }
        .cardStyle()
    }

    private var impressionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "到遊心得", detail: nil)
            TextField("記下這次到訪、想吃或想買的心得", text: optionalBinding(\.impressions), axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .impressions)
        }
        .cardStyle()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "位置", detail: nil)
            NavigationLink {
                MapEditorView(record: record)
            } label: {
                HStack(spacing: 10) {
                    Label(record.coordinateText, systemImage: "location.fill")
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: 4)
                    Image(systemName: "mappin.circle.fill").font(.system(size: 33)).foregroundStyle(.red)
                }
            }
            TextField("鄰近住址（可手動修正）", text: $record.address, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .address)
                .onChange(of: record.address) { _, _ in touch() }
        }
        .cardStyle()
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "國家", detail: record.countryWasManuallyEdited == true ? "手動設定" : "自動分析")
            TextField("例如：台灣、日本、韓國", text: optionalBinding(\.country) {
                record.countryWasManuallyEdited = true
            })
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .country)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
        }
        .cardStyle()
    }

    private var recordTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "紀錄時間", detail: nil)
            Label(record.createdAt.formatted(date: .long, time: .shortened), systemImage: "clock")
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var visitDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("拜訪時間").font(.headline)
                Spacer()
                Button("今日") {
                    record.visitDate = Calendar.current.startOfDay(for: .now)
                    showVisitCalendar = false
                    touch()
                }
                .buttonStyle(.bordered)
            }
            Button {
                focusedField = nil
                withAnimation { showVisitCalendar.toggle() }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text(record.visitDate?.formatted(date: .long, time: .omitted) ?? "點此選擇日期")
                    Spacer()
                    Image(systemName: showVisitCalendar ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.plain)

            if showVisitCalendar {
                DatePicker(
                    "拜訪日期",
                    selection: Binding(
                        get: { record.visitDate ?? Calendar.current.startOfDay(for: .now) },
                        set: { record.visitDate = $0; touch() }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
        .cardStyle()
    }

    private var shareSection: some View {
        Button {
            focusedField = nil
            sharePayload = JournalShareService.payload(for: record)
        } label: {
            Label("流水帳分享到 Facebook", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity, minHeight: 46)
        }
        .buttonStyle(.bordered)
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button("暫存") { save(draft: true) }
                .buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
            Button("完成") { save(draft: false) }
                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity)
                .disabled(record.photos.isEmpty)
        }
        .padding(.bottom, 16)
    }

    private func optionalBinding(_ keyPath: ReferenceWritableKeyPath<PlaceRecord, String?>, onSet: (() -> Void)? = nil) -> Binding<String> {
        Binding(
            get: { record[keyPath: keyPath] ?? "" },
            set: {
                record[keyPath: keyPath] = $0
                onSet?()
                touch()
            }
        )
    }

    private func syncLocation() {
        if record.latitude == nil, let coordinate = location.coordinate {
            record.latitude = coordinate.latitude
            record.longitude = coordinate.longitude
        }
        if record.address.isEmpty, !location.address.isEmpty { record.address = location.address }
        syncCountry()
        touch()
    }

    private func syncCountry() {
        guard record.countryWasManuallyEdited != true, !location.country.isEmpty else { return }
        record.country = location.country
        touch()
    }

    private func addImage(_ image: UIImage, saveToLibrary: Bool = true, gpsCoordinate: CLLocationCoordinate2D? = nil) {
        guard record.canAddPhoto, let data = image.seezMemoJPEGData() else { return }
        record.photos.append(PlacePhoto(
            imageData: data,
            sortOrder: record.photos.count,
            gpsLatitude: gpsCoordinate?.latitude,
            gpsLongitude: gpsCoordinate?.longitude
        ))
        touch()
        if saveToLibrary && saveCapturedToLibrary {
            Task {
                do {
                    try await PhotoLibraryService.saveCapturedImage(image)
                } catch {
                    message = "照片已加入店家紀錄，但無法存入手機相簿。請在設定中允許加入照片。"
                }
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var importedCoordinate: CLLocationCoordinate2D?
        for item in items.prefix(max(0, AppLimits.maximumPhotos - record.photos.count)) {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                let coordinate = PhotoMetadataService.coordinate(from: data)
                if importedCoordinate == nil { importedCoordinate = coordinate }
                addImage(image, saveToLibrary: false, gpsCoordinate: coordinate)
            }
        }
        if record.latitude == nil, let importedCoordinate {
            record.latitude = importedCoordinate.latitude
            record.longitude = importedCoordinate.longitude
            await location.reverseGeocode(importedCoordinate)
            syncLocation()
        }
        photoSelection = []
    }

    private func makeCover(_ photo: PlacePhoto) {
        record.makeCover(photo)
    }

    private func delete(_ photo: PlacePhoto) {
        record.photos.removeAll { $0.id == photo.id }
        modelContext.delete(photo)
        for (index, value) in record.sortedPhotos.enumerated() { value.sortOrder = index }
        touch()
    }

    private func recognizeFromCover() {
        guard let data = record.sortedPhotos.first?.imageData, let image = UIImage(data: data) else { return }
        recognize(image)
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        Task {
            defer { isRecognizing = false }
            do {
                ocrChoices = try await OCRService.recognize(image: image)
                record.recognizedText = ocrChoices.joined(separator: "\n")
                if ocrChoices.isEmpty { message = "照片中沒有辨識到清楚文字。" } else { showOCRChoices = true }
                touch()
            } catch {
                message = "文字辨識失敗，請換一張較清楚的招牌照片。"
            }
        }
    }

    private func touch() { record.updatedAt = .now }

    private func save(draft: Bool) {
        focusedField = nil
        record.isDraft = draft
        touch()
        if !record.category.isEmpty { types.remember(record.category) }
        do { try modelContext.save(); dismiss() } catch { message = "儲存失敗，請稍後再試。" }
    }
}

private struct SectionTitle: View {
    let title: String
    let detail: String?
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

private extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}

private struct PhotoSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cameraPresented: Bool
    @Binding var photoSelection: [PhotosPickerItem]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button { dismiss(); cameraPresented = true } label: {
                    Label("拍照", systemImage: "camera.fill").frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.borderedProminent)
                PhotosPicker(selection: $photoSelection, maxSelectionCount: AppLimits.maximumPhotos, matching: .images, preferredItemEncoding: .current) {
                    Label("從相簿選擇", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity, minHeight: 58)
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(20)
            .navigationTitle("加入照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
