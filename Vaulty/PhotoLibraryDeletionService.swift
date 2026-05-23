//
//  PhotoLibraryDeletionService.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import Foundation
import Photos

enum PhotoLibraryDeletionError: LocalizedError {
    case permissionDenied
    case noAssetsFound
    case deletionFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Vaulty needs Photos permission to delete originals."
        case .noAssetsFound:
            return "The selected originals were not found in Photos."
        case .deletionFailed:
            return "Photos could not delete the selected originals."
        }
    }
}

enum PhotoLibraryDeletionService {
    static func deleteAssets(with identifiers: [String]) async throws {
        let uniqueIdentifiers = Array(Set(identifiers))
        guard !uniqueIdentifiers.isEmpty else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryDeletionError.permissionDenied
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: uniqueIdentifiers, options: nil)
        guard assets.count > 0 else {
            throw PhotoLibraryDeletionError.noAssetsFound
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoLibraryDeletionError.deletionFailed)
                }
            }
        }
    }
}
