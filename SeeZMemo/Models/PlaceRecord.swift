import CoreLocation
import Foundation
import SwiftData

@Model
final class PlaceRecord {
    var id: UUID
    var name: String
    var category: String
    var address: String
    var latitude: Double?
    var longitude: Double?
    var note: String
    var impressions: String?
    var country: String?
    var countryWasManuallyEdited: Bool?
    var recognizedText: String
    var createdAt: Date
    var updatedAt: Date
    var visitDate: Date?
    var isDraft: Bool

    @Relationship(deleteRule: .cascade, inverse: \PlacePhoto.record)
    var photos: [PlacePhoto]

    init(
        id: UUID = UUID(),
        name: String = "",
        category: String = "",
        address: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        note: String = "",
        impressions: String? = nil,
        country: String? = nil,
        countryWasManuallyEdited: Bool? = nil,
        recognizedText: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        visitDate: Date? = nil,
        isDraft: Bool = true,
        photos: [PlacePhoto] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.impressions = impressions
        self.country = country
        self.countryWasManuallyEdited = countryWasManuallyEdited
        self.recognizedText = recognizedText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visitDate = visitDate
        self.isDraft = isDraft
        self.photos = photos
    }

    var coordinateText: String {
        guard let latitude, let longitude else { return "尚未取得座標" }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    var canAddPhoto: Bool { photos.count < AppLimits.maximumPhotos }

    var sortedPhotos: [PlacePhoto] {
        photos.sorted {
            if $0.sortOrder == $1.sortOrder { return $0.createdAt < $1.createdAt }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var displayName: String { name.isEmpty ? "未命名店家" : name }
    var displayCountry: String { country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? country! : "未設定國家" }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from location: CLLocation) -> CLLocationDistance? {
        guard let coordinate else { return nil }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func makeCover(_ photo: PlacePhoto) {
        let ordered = sortedPhotos
        photo.sortOrder = 0
        var next = 1
        for value in ordered where value.id != photo.id {
            value.sortOrder = next
            next += 1
        }
        updatedAt = .now
    }
}

@Model
final class PlacePhoto {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var createdAt: Date
    var sortOrder: Int
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var record: PlaceRecord?

    init(
        id: UUID = UUID(),
        imageData: Data,
        sortOrder: Int,
        createdAt: Date = .now,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }

    var gpsCoordinate: CLLocationCoordinate2D? {
        guard let gpsLatitude, let gpsLongitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: gpsLatitude, longitude: gpsLongitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
}

enum AppLimits {
    static let maximumPhotos = 10
    static let nearbyMapRadius: CLLocationDistance = 2_000
    static let mapRadiusOptions: [CLLocationDistance] = [500, 1_000, 2_000, 5_000, 10_000]
    static let sharedPhotoMaximumBytes = 500_000
    static let sharedPhotoMaximumDimension: CGFloat = 2_048
}

enum AppBuildInfo {
    static let compilationDate = "20260925"
    static let developerName = "Atex Lin"
    static let feedbackEmail = "atexapp.lin@gmail.com"

    static func homeVersionText(version: String) -> String {
        "V\(version)(\(compilationDate))"
    }
}
