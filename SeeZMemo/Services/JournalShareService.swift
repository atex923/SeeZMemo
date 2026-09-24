import SwiftUI
import UIKit

struct JournalSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

enum JournalShareService {
    static func text(for record: PlaceRecord) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        let address = record.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = "\(address)（\(record.coordinateText)）"
        return """
        <。喵仔流水帳。>
        店鋪名稱：\(record.name)
        店鋪類型：\(record.category)
        到遊感想：\(record.impressions ?? "")
        店鋪資訊：\(record.note)
        所在位置：\(position)
        紀錄時間：\(formatter.string(from: record.createdAt))

        #遊記 #食記 #流水帳本
        """
    }

    @MainActor
    static func payload(for record: PlaceRecord) -> JournalSharePayload {
        let shareText = text(for: record)
        UIPasteboard.general.string = shareText
        let images = record.sortedPhotos.compactMap { photo -> UIImage? in
            guard let image = UIImage(data: photo.imageData),
                  let data = compressedJPEG(from: image),
                  let compressed = UIImage(data: data) else { return nil }
            return compressed
        }
        return JournalSharePayload(items: [shareText] + images)
    }

    static func compressedJPEG(
        from image: UIImage,
        maximumDimension: CGFloat = AppLimits.sharedPhotoMaximumDimension,
        maximumBytes: Int = AppLimits.sharedPhotoMaximumBytes
    ) -> Data? {
        var working = image.resizedForSharing(maximumDimension: maximumDimension)
        var dimension = maximumDimension

        while dimension >= 320 {
            for quality in stride(from: 0.9, through: 0.3, by: -0.1) {
                if let data = working.jpegData(compressionQuality: quality), data.count <= maximumBytes {
                    return data
                }
            }
            dimension *= 0.82
            working = working.resizedForSharing(maximumDimension: dimension)
        }
        guard let finalData = working.jpegData(compressionQuality: 0.2), finalData.count <= maximumBytes else { return nil }
        return finalData
    }
}

private extension UIImage {
    func resizedForSharing(maximumDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maximumDimension else { return self }
        let scale = maximumDimension / longest
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
