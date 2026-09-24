import XCTest
import UIKit
import CoreLocation
import ImageIO
@testable import SeeZMemo

final class PlaceRulesTests: XCTestCase {
    func testV010HomeVersionFormat() {
        XCTAssertEqual(AppBuildInfo.homeVersionText(version: "0.1.0"), "V0.1.0(20260925)")
        XCTAssertEqual(AppBuildInfo.developerName, "Atex Lin")
        XCTAssertEqual(AppBuildInfo.feedbackEmail, "atexapp.lin@gmail.com")
    }

    func testPhotoLimitIsTen() { XCTAssertEqual(AppLimits.maximumPhotos, 10) }

    func testNearbyMapRadiusIsTwoKilometers() {
        XCTAssertEqual(AppLimits.nearbyMapRadius, 2_000)
        XCTAssertEqual(AppLimits.mapRadiusOptions, [500, 1_000, 2_000, 5_000, 10_000])
    }

    func testRecordDistanceUsesSavedCoordinate() {
        let record = PlaceRecord(latitude: 25.0330, longitude: 121.5654)
        let sameLocation = CLLocation(latitude: 25.0330, longitude: 121.5654)
        XCTAssertEqual(record.distance(from: sameLocation) ?? -1, 0, accuracy: 0.1)
    }

    func testTypeMemoryMovesRecentValueToFront() {
        let suite = "PlaceRulesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = PlaceTypeMemory(defaults: defaults)
        memory.remember("拉麵")
        memory.remember("甜點")
        memory.remember("拉麵")
        XCTAssertEqual(memory.values.first, "拉麵")
        XCTAssertEqual(memory.values.filter { $0 == "拉麵" }.count, 1)
    }

    func testTypeMemoryShowsTopThreeAndNewestFourth() {
        let suite = "PlaceRulesTests.TypeStats.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = PlaceTypeMemory(defaults: defaults)
        for _ in 0..<4 { memory.remember("美食") }
        for _ in 0..<3 { memory.remember("甜點") }
        for _ in 0..<2 { memory.remember("咖啡") }
        memory.remember("書店")
        XCTAssertEqual(Array(memory.quickValues.prefix(3)), ["美食", "甜點", "咖啡"])
        XCTAssertEqual(memory.quickValues.last, "書店")
    }

    func testMakingCoverMovesPhotoToFirst() {
        let first = PlacePhoto(imageData: Data([1]), sortOrder: 0)
        let second = PlacePhoto(imageData: Data([2]), sortOrder: 1)
        let third = PlacePhoto(imageData: Data([3]), sortOrder: 2)
        let record = PlaceRecord(photos: [first, second, third])
        record.makeCover(third)
        XCTAssertEqual(record.sortedPhotos.map(\.id), [third.id, first.id, second.id])
    }

    func testJournalTextUsesRequiredFormat() {
        let date = Date(timeIntervalSince1970: 1_789_000_000)
        let record = PlaceRecord(
            name: "青沐食堂",
            category: "美食",
            address: "台北市信義區松智路17號",
            latitude: 25.033976,
            longitude: 121.564472,
            note: "午間定食",
            impressions: "想再拜訪",
            createdAt: date
        )
        let text = JournalShareService.text(for: record)
        XCTAssertTrue(text.contains("<。喵仔流水帳。>"))
        XCTAssertTrue(text.contains("店鋪名稱：青沐食堂"))
        XCTAssertTrue(text.contains("所在位置：台北市信義區松智路17號（25.033976, 121.564472）"))
        XCTAssertTrue(text.hasSuffix("#遊記 #食記 #流水帳本"))
    }

    func testSharedPhotoIsAtMost2048PixelsAnd500KB() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_400)).image { context in
            for row in 0..<40 {
                for column in 0..<50 {
                    UIColor(
                        hue: CGFloat((row * 13 + column * 7) % 100) / 100,
                        saturation: 0.9,
                        brightness: 0.9,
                        alpha: 1
                    ).setFill()
                    context.fill(CGRect(x: column * 60, y: row * 60, width: 60, height: 60))
                }
            }
        }
        let data = try XCTUnwrap(JournalShareService.compressedJPEG(from: image))
        let compressed = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(data.count, AppLimits.sharedPhotoMaximumBytes)
        XCTAssertLessThanOrEqual(max(compressed.size.width, compressed.size.height), AppLimits.sharedPhotoMaximumDimension)
    }

    func testOCRRecognizesEnglishShopSign() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 260)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 260))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 108, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "AOMORI CAFE".draw(at: CGPoint(x: 42, y: 64), withAttributes: attributes)
        }

        let recognized = try await OCRService.recognize(image: image)
            .joined(separator: " ")
            .uppercased()

        XCTAssertTrue(recognized.contains("AOMORI"), "OCR result: \(recognized)")
    }

    func testEmptyBackupAndInitialSyncEnvelopeRoundTrip() throws {
        let archive = SeeZBackupArchive(
            appVersion: "0.0.4",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            records: [],
            typeEntries: []
        )
        let envelope = SeeZSyncEnvelope(
            updatedAt: archive.createdAt,
            updatedBy: "Test iPhone",
            current: archive,
            history: []
        )
        let data = try BackupService.encoder.encode(envelope)
        let decoded = try BackupService.decoder.decode(SeeZSyncEnvelope.self, from: data)

        XCTAssertEqual(decoded.current.recordCount, 0)
        XCTAssertEqual(decoded.current.photoCount, 0)
        XCTAssertTrue(decoded.history.isEmpty)
        XCTAssertEqual(decoded.current.schemaVersion, SeeZBackupArchive.schemaVersion)
    }

    func testBackupPreservesPhotoIdentifiersAndOrder() throws {
        let firstID = UUID()
        let secondID = UUID()
        let record = PlaceRecord(photos: [
            PlacePhoto(id: secondID, imageData: Data([2]), sortOrder: 1),
            PlacePhoto(
                id: firstID,
                imageData: Data([1]),
                sortOrder: 0,
                gpsLatitude: 25.033976,
                gpsLongitude: 121.564472
            )
        ])
        let archived = RecordArchive(record)

        XCTAssertEqual(archived.photos.map(\.id), [firstID, secondID])
        XCTAssertEqual(archived.photos.map(\.sortOrder), [0, 1])
        XCTAssertEqual(archived.photos.first?.gpsLatitude, 25.033976)
        XCTAssertEqual(archived.photos.first?.gpsLongitude, 121.564472)
    }

    func testPlacePhotoKeepsGPSAfterImageDataIsReencoded() throws {
        let photo = PlacePhoto(
            imageData: Data([0xFF, 0xD8, 0xFF]),
            sortOrder: 0,
            gpsLatitude: 25.033976,
            gpsLongitude: 121.564472
        )

        let coordinate = try XCTUnwrap(photo.gpsCoordinate)
        XCTAssertEqual(coordinate.latitude, 25.033976, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, 121.564472, accuracy: 0.000001)
    }

    func testPhotoMetadataReadsGPSCoordinate() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        let sourceData = try XCTUnwrap(image.jpegData(compressionQuality: 0.9))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(sourceData as CFData, nil))
        let type = try XCTUnwrap(CGImageSourceGetType(source))
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, type, 1, nil))
        let metadata: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 25.033976,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 121.564472,
                kCGImagePropertyGPSLongitudeRef: "E"
            ]
        ]
        CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let coordinate = try XCTUnwrap(PhotoMetadataService.coordinate(from: output as Data))
        XCTAssertEqual(coordinate.latitude, 25.033976, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, 121.564472, accuracy: 0.000001)
    }
}
