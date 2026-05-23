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
    @State private var showSettings = false

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
            VStack(spacing: 0) {
                VaultHeader(
                    selectedItems: $selectedItems,
                    showSettings: $showSettings,
                    isImporting: isImporting
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)

                Group {
                    if photos.isEmpty {
                        VaultEmptyState()
                    } else {
                        GeometryReader { proxy in
                            let spacing: CGFloat = 2
                            let tileSize = floor((proxy.size.width - spacing * 2) / 3)
                            let columns = Array(
                                repeating: GridItem(.fixed(tileSize), spacing: spacing),
                                count: 3
                            )

                            ScrollView {
                                VStack(spacing: 12) {
                                    VaultGalleryControls(
                                        searchText: $searchText,
                                        showFavoritesOnly: $showFavoritesOnly,
                                        photoCount: filteredPhotos.count
                                    )
                                    .padding(.horizontal)

                                    if filteredPhotos.isEmpty {
                                        ContentUnavailableView(
                                            "No Matching Photos",
                                            systemImage: "photo.on.rectangle",
                                            description: Text("Try a different search or switch back to all photos.")
                                        )
                                        .padding(.top, 72)
                                    } else {
                                        LazyVGrid(columns: columns, spacing: spacing) {
                                            ForEach(filteredPhotos) { photo in
                                                NavigationLink {
                                                    VaultPhotoDetailView(photo: photo)
                                                } label: {
                                                    VaultPhotoTile(photo: photo, size: tileSize)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(VaultTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(VaultTheme.accent)
            .sheet(isPresented: $showSettings) {
                VaultSettingsView()
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

struct VaultHeader: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var showSettings: Bool
    let isImporting: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("Vaulty")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(VaultTheme.primaryText)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(VaultTheme.secondaryText)
                    .background(VaultTheme.elevatedBackground, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(VaultTheme.border.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 50,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.white)
                    .background(VaultTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isImporting)
        }
        .frame(height: 44)
    }
}

struct VaultEmptyState: View {
    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(VaultTheme.accentGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: VaultTheme.accent.opacity(0.24), radius: 20, y: 12)

                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("No Photos Yet")
                    .font(.title2.bold())
                    .foregroundStyle(VaultTheme.primaryText)

                Text("Import photos to store them privately in Vaulty.")
                    .font(.body)
                    .foregroundStyle(VaultTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
        .background(VaultTheme.backgroundGradient.ignoresSafeArea())
    }
}

struct VaultGalleryControls: View {
    @Binding var searchText: String
    @Binding var showFavoritesOnly: Bool
    let photoCount: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VaultTheme.secondaryText)

                TextField("Search notes or details", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(VaultTheme.primaryText)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VaultTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(VaultTheme.elevatedBackground.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(VaultTheme.border.opacity(0.72), lineWidth: 1)
            }

            Button {
                showFavoritesOnly.toggle()
            } label: {
                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(showFavoritesOnly ? .yellow : VaultTheme.secondaryText)
                    .background(VaultTheme.elevatedBackground.opacity(0.82), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(VaultTheme.border.opacity(0.72), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }
}

struct VaultPhotoTile: View {
    let photo: VaultPhoto
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VaultLocalImageView(photo: photo, contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()

            if photo.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.yellow)
                    .padding(6)
                    .background(.black.opacity(0.48), in: Circle())
                    .padding(5)
            }
        }
        .frame(width: size, height: size)
        .background(VaultTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
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
                .fill(VaultTheme.secondaryBackground)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(VaultTheme.secondaryText)
            }
        }
        .clipped()
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
