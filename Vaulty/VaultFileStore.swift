//
//  VaultFileStore.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import Foundation
import UniformTypeIdentifiers

enum VaultFileStore {
    static let folderName = "VaultPhotos"

    static var vaultDirectory: URL {
        get throws {
            let supportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = supportDirectory.appendingPathComponent(folderName, isDirectory: true)

            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.complete]
                )
            }

            return directory
        }
    }

    static func fileURL(for fileName: String) throws -> URL {
        try vaultDirectory.appendingPathComponent(fileName)
    }

    static func store(_ data: Data, contentType: UTType?) throws -> String {
        let fileExtension = preferredFileExtension(for: contentType)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let url = try fileURL(for: fileName)

        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )

        return fileName
    }

    static func delete(fileName: String) {
        guard let url = try? fileURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func fileSize(for fileName: String) -> Int64 {
        guard
            let url = try? fileURL(for: fileName),
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return 0
        }

        return size.int64Value
    }

    private static func preferredFileExtension(for contentType: UTType?) -> String {
        guard let contentType else { return "jpg" }

        if contentType.conforms(to: .heic) {
            return "heic"
        }
        if contentType.conforms(to: .png) {
            return "png"
        }
        if contentType.conforms(to: .jpeg) {
            return "jpg"
        }

        return contentType.preferredFilenameExtension ?? "jpg"
    }
}
