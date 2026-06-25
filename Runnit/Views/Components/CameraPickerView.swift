import SwiftUI
import PhotosUI
import UIKit

// MARK: - CameraPickerView

/// Displays the picked image with a retake button, or two source buttons (Camera / Library).
/// Manages its own sheet presentation state — callers only need to bind `selectedImage`.
struct CameraPickerView: View {
    @Binding var selectedImage: UIImage?

    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        Group {
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()

                    Button { selectedImage = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(12)
                    }
                }
            } else {
                HStack(spacing: 16) {
                    SourceButton(title: "Camera", icon: "camera") { showCamera = true }
                    SourceButton(title: "Library", icon: "photo.on.rectangle") { showLibrary = true }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color(.systemGray6))
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePickerController(sourceType: .camera, selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker(selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
    }
}

// MARK: - SourceButton

private struct SourceButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 28))
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
    }
}

// MARK: - UIImagePickerController (camera)

struct ImagePickerController: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerController
        init(_ parent: ImagePickerController) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - PHPickerViewController (photo library)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let result = results.first else { return }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                if let image = object as? UIImage {
                    DispatchQueue.main.async { self?.parent.selectedImage = image }
                }
            }
        }
    }
}
