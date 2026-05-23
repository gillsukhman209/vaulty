//
//  VaultPhotoDetailView.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import SwiftData
import SwiftUI

struct VaultPhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var photo: VaultPhoto

    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                VaultLocalImageView(photo: photo, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("Private Note") {
                TextEditor(text: $photo.note)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if photo.note.isEmpty {
                            Text("Add a private note")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Photo") {
                LabeledContent("Imported", value: photo.importedAt.formatted(date: .abbreviated, time: .shortened))
                if let capturedAt = photo.capturedAt {
                    LabeledContent("Taken", value: capturedAt.formatted(date: .abbreviated, time: .standard))
                }
                LabeledContent("Dimensions", value: "\(photo.width) x \(photo.height)")
                LabeledContent("File size", value: ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                LabeledContent("Type", value: photo.contentTypeIdentifier)
            }

            Section("Camera") {
                DetailRow(title: "Make", value: photo.cameraMake)
                DetailRow(title: "Model", value: photo.cameraModel)
                DetailRow(title: "Lens", value: photo.lensModel)
                DetailRow(title: "ISO", value: photo.isoSpeed.map(String.init))
                DetailRow(title: "Aperture", value: formattedAperture)
                DetailRow(title: "Exposure", value: formattedExposure)
                DetailRow(title: "Focal length", value: photo.focalLength.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) mm" })
            }

            Section("Location") {
                DetailRow(title: "Latitude", value: photo.latitude.map { $0.formatted(.number.precision(.fractionLength(0...6))) })
                DetailRow(title: "Longitude", value: photo.longitude.map { $0.formatted(.number.precision(.fractionLength(0...6))) })
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete From Vault", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    photo.isFavorite.toggle()
                } label: {
                    Label("Favorite", systemImage: photo.isFavorite ? "star.fill" : "star")
                }
                .tint(photo.isFavorite ? .yellow : nil)
            }
        }
        .confirmationDialog(
            "Delete this photo from Vaulty?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Photo", role: .destructive) {
                deleteFromVault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes Vaulty's private copy. It does not delete anything from Photos.")
        }
    }

    private var formattedAperture: String? {
        photo.aperture.map { "f/\($0.formatted(.number.precision(.fractionLength(0...1))))" }
    }

    private var formattedExposure: String? {
        guard let exposureTime = photo.exposureTime else { return nil }

        if exposureTime > 0, exposureTime < 1 {
            let denominator = Int((1 / exposureTime).rounded())
            return "1/\(denominator) sec"
        }

        return "\(exposureTime.formatted(.number.precision(.fractionLength(0...2)))) sec"
    }

    private func deleteFromVault() {
        VaultFileStore.delete(fileName: photo.fileName)
        modelContext.delete(photo)
        try? modelContext.save()
        dismiss()
    }
}

struct DetailRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value, !value.isEmpty {
            LabeledContent(title, value: value)
        }
    }
}
