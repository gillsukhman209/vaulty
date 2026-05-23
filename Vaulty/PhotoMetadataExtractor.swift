//
//  PhotoMetadataExtractor.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import Foundation
import ImageIO

struct PhotoMetadata {
    var capturedAt: Date?
    var width: Int
    var height: Int
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var isoSpeed: Int?
    var aperture: Double?
    var exposureTime: Double?
    var focalLength: Double?
    var latitude: Double?
    var longitude: Double?
}

enum PhotoMetadataExtractor {
    static func extract(from data: Data) -> PhotoMetadata {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return PhotoMetadata(capturedAt: nil, width: 0, height: 0)
        }

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]

        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let capturedAt = capturedDate(exif: exif, tiff: tiff)
        let isoSpeed = (exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first

        var latitude = gps?[kCGImagePropertyGPSLatitude as String] as? Double
        var longitude = gps?[kCGImagePropertyGPSLongitude as String] as? Double

        if (gps?[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" {
            latitude = latitude.map { -$0 }
        }
        if (gps?[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" {
            longitude = longitude.map { -$0 }
        }

        return PhotoMetadata(
            capturedAt: capturedAt,
            width: width,
            height: height,
            cameraMake: tiff?[kCGImagePropertyTIFFMake as String] as? String,
            cameraModel: tiff?[kCGImagePropertyTIFFModel as String] as? String,
            lensModel: exif?[kCGImagePropertyExifLensModel as String] as? String,
            isoSpeed: isoSpeed,
            aperture: exif?[kCGImagePropertyExifFNumber as String] as? Double,
            exposureTime: exif?[kCGImagePropertyExifExposureTime as String] as? Double,
            focalLength: exif?[kCGImagePropertyExifFocalLength as String] as? Double,
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func capturedDate(exif: [String: Any]?, tiff: [String: Any]?) -> Date? {
        let rawDate = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
            ?? exif?[kCGImagePropertyExifDateTimeDigitized as String] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime as String] as? String

        guard let rawDate else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: rawDate)
    }
}
