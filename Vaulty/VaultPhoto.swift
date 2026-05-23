//
//  VaultPhoto.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import Foundation
import SwiftData

@Model
final class VaultPhoto {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var originalFileName: String
    var contentTypeIdentifier: String
    var importedAt: Date
    var capturedAt: Date?
    var fileSize: Int64
    var width: Int
    var height: Int
    var sourceAssetIdentifier: String?
    var note: String
    var isFavorite: Bool

    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var isoSpeed: Int?
    var aperture: Double?
    var exposureTime: Double?
    var focalLength: Double?
    var latitude: Double?
    var longitude: Double?

    init(
        id: UUID = UUID(),
        fileName: String,
        originalFileName: String,
        contentTypeIdentifier: String,
        importedAt: Date = Date(),
        capturedAt: Date?,
        fileSize: Int64,
        width: Int,
        height: Int,
        sourceAssetIdentifier: String?,
        note: String = "",
        isFavorite: Bool = false,
        cameraMake: String?,
        cameraModel: String?,
        lensModel: String?,
        isoSpeed: Int?,
        aperture: Double?,
        exposureTime: Double?,
        focalLength: Double?,
        latitude: Double?,
        longitude: Double?
    ) {
        self.id = id
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.contentTypeIdentifier = contentTypeIdentifier
        self.importedAt = importedAt
        self.capturedAt = capturedAt
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.sourceAssetIdentifier = sourceAssetIdentifier
        self.note = note
        self.isFavorite = isFavorite
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.isoSpeed = isoSpeed
        self.aperture = aperture
        self.exposureTime = exposureTime
        self.focalLength = focalLength
        self.latitude = latitude
        self.longitude = longitude
    }
}
