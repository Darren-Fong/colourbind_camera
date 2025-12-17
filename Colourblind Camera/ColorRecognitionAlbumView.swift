//
//  ColorRecognitionAlbumView.swift
//  Colourblind Camera
//
//  Photo album with automatic color analysis and tagging
//

import SwiftUI
import PhotosUI
import CoreImage
import Vision

struct ColorRecognitionAlbumView: View {
    @ObservedObject private var albumManager = ColorAlbumManager.shared
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: ColorAnalyzedImage?
    @State private var searchText = ""
    @State private var selectedCategory: PhotoCategory = .all
    
    enum PhotoCategory: String, CaseIterable, Codable {
        case all = "All"
        case clothing = "Clothing"
        case nature = "Nature"
        case food = "Food"
        case design = "Design"
        case misc = "Other"
        
        var icon: String {
            switch self {
            case .all: return "photo.on.rectangle"
            case .clothing: return "tshirt.fill"
            case .nature: return "leaf.fill"
            case .food: return "fork.knife"
            case .design: return "paintpalette.fill"
            case .misc: return "folder.fill"
            }
        }
    }
    
    var filteredImages: [ColorAnalyzedImage] {
        var images = albumManager.analyzedImages
        
        // Filter by category
        if selectedCategory != .all {
            images = images.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            images = images.filter { image in
                image.dominantColors.contains { color in
                    color.name.localizedCaseInsensitiveContains(searchText)
                } || image.tags.contains { tag in
                    tag.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        return images.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 10) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search colors or tags...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Category filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(PhotoCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    category: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Photos Grid
                if filteredImages.isEmpty {
                    EmptyStateView(
                        hasImages: !albumManager.analyzedImages.isEmpty,
                        searchText: searchText,
                        onAddPhoto: { showingImagePicker = true },
                        onTakePhoto: { showingCamera = true }
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 2), spacing: 2) {
                            ForEach(filteredImages, id: \.id) { image in
                                PhotoCard(
                                    image: image,
                                    onTap: { selectedImage = image }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Color Album")
            .navigationBarItems(
                trailing: HStack {
                    Button(action: { showingCamera = true }) {
                        Image(systemName: "camera.fill")
                    }
                    
                    Button(action: { showingImagePicker = true }) {
                        Image(systemName: "plus")
                    }
                }
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(onImageSelected: { image in
                albumManager.addImage(image)
            })
        }
        .sheet(isPresented: $showingCamera) {
            CameraPickerView(onImageCaptured: { image in
                albumManager.addImage(image)
            })
        }
        .sheet(item: $selectedImage) { image in
            ImageDetailView(image: image, albumManager: albumManager)
        }
        .onAppear {
            albumManager.loadImages()
        }
    }
}

struct CategoryButton: View {
    let category: ColorRecognitionAlbumView.PhotoCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .cornerRadius(15)
        }
    }
}

struct PhotoCard: View {
    let image: ColorAnalyzedImage
    let onTap: () -> Void
    @State private var loadedImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Image
                Group {
                    if let uiImage = loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                ProgressView()
                            )
                    }
                }
                .onAppear {
                    loadImageFromDisk()
                }
                
                // Color palette
                HStack(spacing: 1) {
                    ForEach(image.dominantColors.prefix(5), id: \.name) { colorInfo in
                        Rectangle()
                            .fill(colorInfo.color)
                            .frame(height: 25)
                    }
                }
                
                // Tags
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(image.dominantColors.count) colors")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: image.category.icon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !image.tags.isEmpty {
                        Text(image.tags.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
    }
    
    private func loadImageFromDisk() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(image.imageURL)
        loadedImage = UIImage(contentsOfFile: url.path)
    }
}

struct EmptyStateView: View {
    let hasImages: Bool
    let searchText: String
    let onAddPhoto: () -> Void
    let onTakePhoto: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            if hasImages && !searchText.isEmpty {
                // No search results
                VStack(spacing: 15) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Results Found")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Try searching for different colors or tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                // No photos at all
                VStack(spacing: 15) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Photos Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Add photos to start building your color-analyzed album")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        Button(action: onTakePhoto) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Take Photo")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: onAddPhoto) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Add from Library")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ImageDetailView: View {
    let image: ColorAnalyzedImage
    let albumManager: ColorAlbumManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    @State private var editingTags = false
    @State private var newTag = ""
    @State private var loadedImage: UIImage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image
                    if let uiImage = loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(15)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                            .cornerRadius(15)
                            .overlay(ProgressView())
                    }
                    
                    // Color Analysis
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Color Analysis")
                            .font(.headline)
                        
                        // Dominant colors
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                            ForEach(image.dominantColors, id: \.name) { colorInfo in
                                ColorInfoCard(colorInfo: colorInfo)
                            }
                        }
                    }
                    
                    // Color Palette
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color Palette")
                            .font(.headline)
                        
                        HStack(spacing: 2) {
                            ForEach(image.dominantColors, id: \.name) { colorInfo in
                                VStack {
                                    Rectangle()
                                        .fill(colorInfo.color)
                                        .frame(height: 50)
                                    
                                    Text(colorInfo.hexValue)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .cornerRadius(8)
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tags")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(editingTags ? "Done" : "Edit") {
                                editingTags.toggle()
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        TagsView(
                            tags: image.tags,
                            isEditing: editingTags,
                            onTagAdded: { tag in
                                albumManager.addTag(tag, to: image.id)
                            },
                            onTagRemoved: { tag in
                                albumManager.removeTag(tag, from: image.id)
                            }
                        )
                    }
                    
                    // Usage Suggestions
                    if !image.usageSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Usage Suggestions")
                                .font(.headline)
                            
                            ForEach(image.usageSuggestions, id: \.self) { suggestion in
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Details")
                            .font(.headline)
                        
                        HStack {
                            Text("Added:")
                            Spacer()
                            Text(image.dateAdded, style: .date)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                        
                        HStack {
                            Text("Category:")
                            Spacer()
                            Text(image.category.rawValue)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadImageFromDisk()
            }
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    
                    Menu {
                        Button("Delete Photo", role: .destructive) {
                            albumManager.deleteImage(image.id)
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = loadedImage {
                ShareSheet(items: [image, createShareableContent()])
            }
        }
    }
    
    private func loadImageFromDisk() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(image.imageURL)
        loadedImage = UIImage(contentsOfFile: url.path)
    }
    
    private func createShareableContent() -> String {
        let colorNames = image.dominantColors.map { $0.name }.joined(separator: ", ")
        return "Color Analysis: \(colorNames)\n\nGenerated by Colourblind Camera"
    }
}

struct ColorInfoCard: View {
    let colorInfo: ColorInfo
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorInfo.color)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                VStack(spacing: 2) {
                    Text(colorInfo.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(Int(colorInfo.percentage * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showingDetails) {
            ColorDetailSheet(colorInfo: colorInfo)
        }
    }
}

struct ColorDetailSheet: View {
    let colorInfo: ColorInfo
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Large color swatch
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorInfo.color)
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray, lineWidth: 2)
                    )
                
                // Color details
                VStack(spacing: 15) {
                    DetailRow(title: "Name", value: colorInfo.name)
                    DetailRow(title: "HEX", value: colorInfo.hexValue)
                    DetailRow(title: "RGB", value: colorInfo.rgbValue)
                    DetailRow(title: "Coverage", value: "\(Int(colorInfo.percentage * 100))%")
                    
                    if let hue = colorInfo.hue {
                        DetailRow(title: "Hue", value: "\(Int(hue))°")
                    }
                    
                    if let saturation = colorInfo.saturation {
                        DetailRow(title: "Saturation", value: "\(Int(saturation * 100))%")
                    }
                    
                    if let brightness = colorInfo.brightness {
                        DetailRow(title: "Brightness", value: "\(Int(brightness * 100))%")
                    }
                }
                
                Spacer()
                
                Button("Copy Color Values") {
                    let colorData = """
                    Name: \(colorInfo.name)
                    HEX: \(colorInfo.hexValue)
                    RGB: \(colorInfo.rgbValue)
                    """
                    UIPasteboard.general.string = colorData
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding()
            .navigationTitle("Color Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct TagsView: View {
    let tags: [String]
    let isEditing: Bool
    let onTagAdded: (String) -> Void
    let onTagRemoved: (String) -> Void
    
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Existing tags
            if !tags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            isEditing: isEditing,
                            onRemove: { onTagRemoved(tag) }
                        )
                    }
                }
            }
            
            // Add new tag
            if isEditing {
                HStack {
                    TextField("Add tag...", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        if !newTag.isEmpty {
                            onTagAdded(newTag)
                            newTag = ""
                        }
                    }
                    .disabled(newTag.isEmpty)
                }
            }
        }
    }
}

struct TagChip: View {
    let tag: String
    let isEditing: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
            
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

// Image picker implementations
struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let image = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onImageSelected(image)
                        }
                    }
                }
            }
        }
    }
}

struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Supporting Models
struct ColorAnalyzedImage: Identifiable {
    let id = UUID()
    let imageURL: String
    let dominantColors: [ColorInfo]
    var tags: [String]
    let category: ColorRecognitionAlbumView.PhotoCategory
    let dateAdded: Date
    let usageSuggestions: [String]
}

struct ColorInfo: Codable {
    let name: String
    let color: Color
    let hexValue: String
    let rgbValue: String
    let percentage: Double
    let hue: Double?
    let saturation: Double?
    let brightness: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, hexValue, rgbValue, percentage, hue, saturation, brightness
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(hexValue, forKey: .hexValue)
        try container.encode(rgbValue, forKey: .rgbValue)
        try container.encode(percentage, forKey: .percentage)
        try container.encode(hue, forKey: .hue)
        try container.encode(saturation, forKey: .saturation)
        try container.encode(brightness, forKey: .brightness)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        hexValue = try container.decode(String.self, forKey: .hexValue)
        rgbValue = try container.decode(String.self, forKey: .rgbValue)
        percentage = try container.decode(Double.self, forKey: .percentage)
        hue = try container.decodeIfPresent(Double.self, forKey: .hue)
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation)
        brightness = try container.decodeIfPresent(Double.self, forKey: .brightness)
        
        // Reconstruct color from hex
        color = Color(hex: hexValue) ?? .gray
    }
    
    init(name: String, color: Color, hexValue: String, rgbValue: String, percentage: Double, hue: Double?, saturation: Double?, brightness: Double?) {
        self.name = name
        self.color = color
        self.hexValue = hexValue
        self.rgbValue = rgbValue
        self.percentage = percentage
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}

class ColorAlbumManager: ObservableObject {
    static let shared = ColorAlbumManager()
    
    @Published var analyzedImages: [ColorAnalyzedImage] = []
    private let colorAnalyzer = ColorAnalyzer()
    private let defaults = UserDefaults.standard
    private let imagesKey = "SavedAnalyzedImages"
    
    private init() {
        loadImages()
    }
    
    func loadImages() {
        // Load saved images from UserDefaults
        if let data = defaults.data(forKey: imagesKey),
           let decoded = try? JSONDecoder().decode([SavedImageData].self, from: data) {
            
            analyzedImages = decoded.compactMap { savedData in
                guard let image = loadImageFromDisk(filename: savedData.filename) else { return nil }
                
                return ColorAnalyzedImage(
                    imageURL: savedData.filename,
                    dominantColors: savedData.dominantColors,
                    tags: savedData.tags,
                    category: savedData.category,
                    dateAdded: savedData.dateAdded,
                    usageSuggestions: savedData.usageSuggestions
                )
            }
        }
    }
    
    func addImage(_ image: UIImage) {
        // Analyze the image
        let analysis = colorAnalyzer.analyzeImage(image)
        
        // Save image to disk
        let filename = saveImageToDisk(image)
        
        let analyzedImage = ColorAnalyzedImage(
            imageURL: filename,
            dominantColors: analysis.colors,
            tags: analysis.suggestedTags,
            category: analysis.category,
            dateAdded: Date(),
            usageSuggestions: analysis.usageSuggestions
        )
        
        analyzedImages.insert(analyzedImage, at: 0)
        saveToUserDefaults()
    }
    
    func deleteImage(_ id: UUID) {
        if let image = analyzedImages.first(where: { $0.id == id }) {
            deleteImageFromDisk(filename: image.imageURL)
            analyzedImages.removeAll { $0.id == id }
            saveToUserDefaults()
        }
    }
    
    func addTag(_ tag: String, to imageId: UUID) {
        if let index = analyzedImages.firstIndex(where: { $0.id == imageId }) {
            analyzedImages[index].tags.append(tag)
            saveToUserDefaults()
        }
    }
    
    func removeTag(_ tag: String, from imageId: UUID) {
        if let index = analyzedImages.firstIndex(where: { $0.id == imageId }) {
            analyzedImages[index].tags.removeAll { $0 == tag }
            saveToUserDefaults()
        }
    }
    
    func clearAllImages() {
        // Delete all images from disk
        for image in analyzedImages {
            deleteImageFromDisk(filename: image.imageURL)
        }
        
        // Clear the array and UserDefaults
        analyzedImages.removeAll()
        defaults.removeObject(forKey: imagesKey)
    }
    
    private func saveImageToDisk(_ image: UIImage) -> String {
        let filename = "\(UUID().uuidString).jpg"
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
        }
        
        return filename
    }
    
    private func loadImageFromDisk(filename: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
    
    private func deleteImageFromDisk(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveToUserDefaults() {
        let savedData = analyzedImages.map { image in
            SavedImageData(
                filename: image.imageURL,
                dominantColors: image.dominantColors,
                tags: image.tags,
                category: image.category,
                dateAdded: image.dateAdded,
                usageSuggestions: image.usageSuggestions
            )
        }
        
        if let encoded = try? JSONEncoder().encode(savedData) {
            defaults.set(encoded, forKey: imagesKey)
        }
    }
}

struct SavedImageData: Codable {
    let filename: String
    let dominantColors: [ColorInfo]
    let tags: [String]
    let category: ColorRecognitionAlbumView.PhotoCategory
    let dateAdded: Date
    let usageSuggestions: [String]
}

struct ImageAnalysisResult {
    let colors: [ColorInfo]
    let suggestedTags: [String]
    let category: ColorRecognitionAlbumView.PhotoCategory
    let usageSuggestions: [String]
}

class ColorAnalyzer {
    func analyzeImage(_ image: UIImage) -> ImageAnalysisResult {
        guard let ciImage = CIImage(image: image) else {
            return createDefaultResult()
        }
        
        // Extract dominant colors
        let colors = extractDominantColors(from: ciImage, image: image)
        
        // Generate tags based on colors
        let tags = generateTags(from: colors)
        
        // Determine category
        let category = determineCategory(from: colors)
        
        // Generate usage suggestions
        let suggestions = generateUsageSuggestions(colors: colors, category: category)
        
        return ImageAnalysisResult(
            colors: colors,
            suggestedTags: tags,
            category: category,
            usageSuggestions: suggestions
        )
    }
    
    private func extractDominantColors(from ciImage: CIImage, image: UIImage) -> [ColorInfo] {
        var colorInfos: [ColorInfo] = []
        
        // Sample multiple points from the image to find dominant colors
        let samplePoints = 100
        var colorCounts: [UIColor: Int] = [:]
        
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            return createDefaultColors()
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return createDefaultColors()
        }
        
        // Sample colors from grid
        for i in 0..<samplePoints {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            
            let pixelInfo = ((width * y) + x) * 4
            let r = CGFloat(data[pixelInfo]) / 255.0
            let g = CGFloat(data[pixelInfo + 1]) / 255.0
            let b = CGFloat(data[pixelInfo + 2]) / 255.0
            
            let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            let quantizedColor = quantizeColor(color)
            colorCounts[quantizedColor, default: 0] += 1
        }
        
        // Get top colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }.prefix(5)
        let totalSamples = samplePoints
        
        for (color, count) in sortedColors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
            
            let colorInfo = ColorInfo(
                name: getColorName(r: r, g: g, b: b),
                color: Color(color),
                hexValue: String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255)),
                rgbValue: "RGB(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))",
                percentage: Double(count) / Double(totalSamples),
                hue: Double(h * 360),
                saturation: Double(s),
                brightness: Double(br)
            )
            
            colorInfos.append(colorInfo)
        }
        
        return colorInfos.isEmpty ? createDefaultColors() : colorInfos
    }
    
    private func quantizeColor(_ color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Quantize to reduce similar colors
        let step: CGFloat = 0.2
        let qr = round(r / step) * step
        let qg = round(g / step) * step
        let qb = round(b / step) * step
        
        return UIColor(red: qr, green: qg, blue: qb, alpha: 1.0)
    }
    
    private func getColorName(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        // Use the same advanced color recognizer as the live camera
        return ColorRecognizer.shared.recognizeColor(r: Double(r), g: Double(g), b: Double(b))
        
        // Old implementation below (kept for reference but not used)
        /*
        // Apply lighting compensation - normalize based on gray world assumption
        let (normR, normG, normB) = normalizeForLighting(r: r, g: g, b: b)
        
        // Convert to HSL for better color perception
        let (hue, saturation, lightness) = rgbToHSL(r: normR, g: normG, b: normB)
        
        let hueAngle = hue * 360
        let sat = saturation * 100
        let light = lightness * 100
        
        // Calculate chroma to detect true grayscale
        let chroma = max(normR, normG, normB) - min(normR, normG, normB)
        let isGrayscale = chroma < 0.08 || sat < 8
        
        // Handle grayscale/neutral colors
        if isGrayscale {
            if light > 85 { return "White" }
            if light > 65 { return "Light Gray" }
            if light > 35 { return "Gray" }
            if light > 15 { return "Dark Gray" }
            return "Black"
        }
        
        // Handle very dark colors
        if light < 12 && sat < 20 {
            return "Black"
        }
        
        // Classify by lightness and saturation
        let isVeryLight = light > 75
        let isLight = light > 55
        let isDark = light < 30
        let isVeryDark = light < 18
        let isPale = sat < 30
        let isVivid = sat > 70
        
        var colorName: String
        
        // Red range
        if hueAngle < 12 || hueAngle >= 350 {
            if isVeryLight && isPale { colorName = "Pink" }
            else if isVeryDark { colorName = "Dark Red" }
            else if isDark && sat < 50 { colorName = "Maroon" }
            else if isPale && isLight { colorName = "Salmon" }
            else { colorName = "Red" }
        }
        // Orange range
        else if hueAngle < 40 {
            if isVeryDark || (isDark && sat < 50) { colorName = "Brown" }
            else if isVeryLight && isPale { colorName = "Peach" }
            else if isPale { colorName = "Tan" }
            else { colorName = "Orange" }
        }
        // Yellow range
        else if hueAngle < 70 {
            if isVeryDark { colorName = "Olive" }
            else if isDark { colorName = "Brown" }
            else if isPale && isLight { colorName = "Cream" }
            else if isPale { colorName = "Beige" }
            else { colorName = "Yellow" }
        }
        // Green range
        else if hueAngle < 150 {
            if isVeryLight && isPale { colorName = "Mint" }
            else if isVeryLight { colorName = "Light Green" }
            else if isVeryDark { colorName = "Dark Green" }
            else if isDark { colorName = "Forest Green" }
            else if isPale { colorName = "Sage" }
            else if isVivid { colorName = "Bright Green" }
            else { colorName = "Green" }
        }
        // Cyan range
        else if hueAngle < 195 {
            if isLight { colorName = "Aqua" }
            else if isDark { colorName = "Teal" }
            else { colorName = "Cyan" }
        }
        // Blue range
        else if hueAngle < 255 {
            if isVeryLight && isPale { colorName = "Powder Blue" }
            else if isVeryLight { colorName = "Sky Blue" }
            else if isVeryDark { colorName = "Navy" }
            else if isDark { colorName = "Dark Blue" }
            else if isVivid { colorName = "Bright Blue" }
            else { colorName = "Blue" }
        }
        // Purple range
        else if hueAngle < 310 {
            if isVeryLight && isPale { colorName = "Lavender" }
            else if isVeryLight { colorName = "Light Purple" }
            else if isVeryDark { colorName = "Dark Purple" }
            else if isPale { colorName = "Mauve" }
            else { colorName = "Purple" }
        }
        // Magenta/Pink range
        else {
            if isVeryLight { colorName = "Pink" }
            else if isDark { colorName = "Magenta" }
            else if isPale { colorName = "Rose" }
            else { colorName = "Hot Pink" }
        }
        
        return colorName
        */
    }
    
    private func generateTags(from colors: [ColorInfo]) -> [String] {
        var tags: [String] = []
        
        for color in colors.prefix(3) {
            tags.append(color.name.lowercased())
        }
        
        // Add brightness tags
        if let avgBrightness = colors.first?.brightness {
            if avgBrightness > 0.7 {
                tags.append("bright")
            } else if avgBrightness < 0.3 {
                tags.append("dark")
            }
        }
        
        // Add saturation tags
        if let avgSaturation = colors.first?.saturation {
            if avgSaturation > 0.6 {
                tags.append("vibrant")
            } else if avgSaturation < 0.2 {
                tags.append("muted")
            }
        }
        
        return Array(Set(tags)).prefix(5).map { $0 }
    }
    
    private func determineCategory(from colors: [ColorInfo]) -> ColorRecognitionAlbumView.PhotoCategory {
        // Simple heuristic based on dominant colors
        let dominantNames = colors.prefix(2).map { $0.name }
        
        if dominantNames.contains("Green") || dominantNames.contains("Brown") {
            return .nature
        } else if dominantNames.contains("Red") || dominantNames.contains("Orange") || dominantNames.contains("Yellow") {
            return .food
        } else {
            return .misc
        }
    }
    
    private func generateUsageSuggestions(colors: [ColorInfo], category: ColorRecognitionAlbumView.PhotoCategory) -> [String] {
        var suggestions: [String] = []
        
        switch category {
        case .nature:
            suggestions.append("Great for outdoor and nature themes")
            suggestions.append("Consider for eco-friendly branding")
        case .food:
            suggestions.append("Suitable for food and restaurant designs")
            suggestions.append("Warm colors attract appetite")
        case .clothing:
            suggestions.append("Good for fashion and apparel")
        case .design:
            suggestions.append("Versatile for graphic design")
        case .misc, .all:
            suggestions.append("General purpose color palette")
        }
        
        // Add color-specific suggestions
        if let dominant = colors.first {
            if dominant.brightness ?? 0 > 0.7 {
                suggestions.append("High brightness - good visibility")
            }
            if dominant.saturation ?? 0 > 0.7 {
                suggestions.append("High saturation - eye-catching")
            }
        }
        
        return suggestions
    }
    
    private func createDefaultColors() -> [ColorInfo] {
        [ColorInfo(
            name: "Gray",
            color: .gray,
            hexValue: "#808080",
            rgbValue: "RGB(128, 128, 128)",
            percentage: 1.0,
            hue: 0,
            saturation: 0,
            brightness: 0.5
        )]
    }
    
    private func createDefaultResult() -> ImageAnalysisResult {
        ImageAnalysisResult(
            colors: createDefaultColors(),
            suggestedTags: ["unanalyzed"],
            category: .misc,
            usageSuggestions: ["Unable to analyze image"]
        )
    }
}