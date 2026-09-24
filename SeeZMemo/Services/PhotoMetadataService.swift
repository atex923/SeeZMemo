import CoreLocation
import Foundation
import ImageIO

enum PhotoMetadataService {
    static func coordinate(from imageData: Data) -> CLLocationCoordinate2D? {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let latitude = number(gps[kCGImagePropertyGPSLatitude]),
            let longitude = number(gps[kCGImagePropertyGPSLongitude])
        else { return nil }

        let latitudeReference = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
        let longitudeReference = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
        let signedLatitude = latitudeReference == "S" ? -abs(latitude) : abs(latitude)
        let signedLongitude = longitudeReference == "W" ? -abs(longitude) : abs(longitude)

        guard CLLocationCoordinate2DIsValid(.init(latitude: signedLatitude, longitude: signedLongitude)) else {
            return nil
        }
        return .init(latitude: signedLatitude, longitude: signedLongitude)
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
