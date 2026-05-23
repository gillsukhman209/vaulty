//
//  VaultHomeView.swift
//  Vaulty
//
//  Created by Sukhman Singh on 5/23/26.
//

import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VaultHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VaultPhoto.importedAt, order: .reverse) private var photos: [VaultPhoto]

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var importErrorMessage: String?
    @State private var deletionErrorMessage: String?
    @State private var recentlyImportedAssetIds: [String] = []
    @State private var showDeleteOriginalsConfirmation = false
    @State private var showFavoritesOnly = false

    private let columns = [
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3),
        GridItem(.flexible(), spacing: 3)
    ]

    private var filteredPhotos: [VaultPhoto] {
        photos.filter { photo in
            let matchesFavorite = !showFavoritesOnly || photo.isFavorite
            let matchesSearch = searchText.isEmpty
                || photo.originalFileName.localizedCaseInsensitiveContains(searchText)
                || photo.note.localizedCaseInsensitiveContains(searchText)
                || (photo.cameraMake?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (photo.cameraModel?.localizedCaseInsensitiveContains(searchText) ?? false)

            return matchesFavorite && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.badge.plus",
                        description: Text("Import photos to store them privately in Vaulty.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            VaultGalleryControls(
                                searchText: $searchText,
                                showFavoritesOnly: $showFavoritesOnly,
                                photoCount: filteredPhotos.count
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            if filteredPhotos.isEmpty {
                                ContentUnavailableView(
                                    "No Matching Photos",
                                    systemImage: "photo.on.rectangle",
                                    description: Text("Try a different search or switch back to all photos.")
                                )
                                .padding(.top, 72)
                            } else {
                                LazyVGrid(columns: columns, spacing: 3) {
                                    ForEach(filteredPhotos) { photo in
                                        NavigationLink {
                                            VaultPhotoDetailView(photo: photo)
                                        } label: {
                                            VaultPhotoTile(photo: photo)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 3)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Vaulty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 50,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Import", systemImage: "plus")
                    }
                    .disabled(isImporting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isImporting {
                    ProgressView("Importing photos")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.bar)
                }
            }
            .confirmationDialog(
                "Delete originals from Photos?",
                isPresented: $showDeleteOriginalsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Originals", role: .destructive) {
                    Task { await deleteRecentlyImportedOriginals() }
                }
                Button("Keep Originals", role: .cancel) {
                    recentlyImportedAssetIds = []
                }
            } message: {
                Text("The imported copies are already stored in Vaulty. iOS will ask you to confirm deletion from Photos.")
            }
            .alert("Import Failed", isPresented: importErrorBinding) {
                Button("OK", role: .cancel) { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .alert("Could Not Delete Originals", isPresented: deletionErrorBinding) {
                Button("OK", role: .cancel) { deletionErrorMessage = nil }
            } message: {
                Text(deletionErrorMessage ?? "")
            }
            .onChange(of: selectedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task { await importPhotos(from: newItems) }
            }
        }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private var deletionErrorBinding: Binding<Bool> {
        Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )
    }

    private func importPhotos(from items: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            selectedItems = []
        }

        var importedAssetIds: [String] = []

        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    continue
                }

                let contentType = item.supportedContentTypes.first { $0.conforms(to: .image) }
                let fileName = try VaultFileStore.store(data, contentType: contentType)
                let metadata = PhotoMetadataExtractor.extract(from: data)
                let sourceIdentifier = item.itemIdentifier

                let photo = VaultPhoto(
                    fileName: fileName,
                    originalFileName: item.itemIdentifier ?? fileName,
                    contentTypeIdentifier: contentType?.identifier ?? UTType.image.identifier,
                    capturedAt: metadata.capturedAt,
                    fileSize: Int64(data.count),
                    width: metadata.width,
                    height: metadata.height,
                    sourceAssetIdentifier: sourceIdentifier,
                    cameraMake: metadata.cameraMake,
                    cameraModel: metadata.cameraModel,
                    lensModel: metadata.lensModel,
                    isoSpeed: metadata.isoSpeed,
                    aperture: metadata.aperture,
                    exposureTime: metadata.exposureTime,
                    focalLength: metadata.focalLength,
                    latitude: metadata.latitude,
                    longitude: metadata.longitude
                )
                modelContext.insert(photo)

                if let sourceIdentifier {
                    importedAssetIds.append(sourceIdentifier)
                }
            }

            try modelContext.save()
            recentlyImportedAssetIds = importedAssetIds
            showDeleteOriginalsConfirmation = !importedAssetIds.isEmpty
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func deleteRecentlyImportedOriginals() async {
        do {
            try await PhotoLibraryDeletionService.deleteAssets(with: recentlyImportedAssetIds)
            recentlyImportedAssetIds = []
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
}

struct VaultGalleryControls: View {
    @Binding var searchText: String
    @Binding var showFavoritesOnly: Bool
    let photoCount: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search notes or details", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack {
                Picker("Filter", selection: $showFavoritesOnly) {
                    Text("All").tag(false)
                    Text("Favorites").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Spacer()

                Text("\(photoCount) \(photoCount == 1 ? "photo" : "photos")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct VaultPhotoTile: View {
    let photo: VaultPhoto

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VaultLocalImageView(photo: photo, contentMode: .fit)
                .padding(4)

            if photo.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .padding(7)
                    .background(.black.opacity(0.55), in: Circle())
                    .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
        }
        .overlay(alignment: .bottomLeading) {
            if let capturedAt = photo.capturedAt {
                Text(capturedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.52), in: Capsule())
                    .padding(6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(photo.originalFileName)
    }
}

struct VaultLocalImageView: View {
    let photo: VaultPhoto
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: photo.fileName) {
            loadImage()
        }
    }

    private func loadImage() {
        guard
            let url = try? VaultFileStore.fileURL(for: photo.fileName),
            let loadedImage = UIImage(contentsOfFile: url.path)
        else {
            image = nil
            return
        }

        image = loadedImage
    }
}

#Preview {
    VaultHomeView()
        .modelContainer(for: VaultPhoto.self, inMemory: true)
}
