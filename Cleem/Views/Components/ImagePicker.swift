import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .photoLibrary
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                // Process the selected image
                let processedImage = processImage(uiImage)
                
                DispatchQueue.main.async {
                    self.parent.selectedImage = processedImage
                    // Dismiss the picker first
                    picker.dismiss(animated: true) {
                        // Then call the callback after dismissal to prevent UI issues
                        self.parent.onImageSelected(processedImage)
                        self.parent.isPresented = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    // Just dismiss if no image was selected
                    picker.dismiss(animated: true) {
                        self.parent.onImageSelected(nil)
                        self.parent.isPresented = false
                    }
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            DispatchQueue.main.async {
                picker.dismiss(animated: true) {
                    self.parent.onImageSelected(nil)
                    self.parent.isPresented = false
                }
            }
        }
        
        // Process the image to ensure it's not too large
        private func processImage(_ image: UIImage) -> UIImage {
            // Calculate new size (max dimension 1200 points)
            let maxDimension: CGFloat = 1200
            let originalSize = image.size
            var newSize = originalSize
            
            if originalSize.width > maxDimension || originalSize.height > maxDimension {
                if originalSize.width > originalSize.height {
                    newSize.width = maxDimension
                    newSize.height = originalSize.height * (maxDimension / originalSize.width)
                } else {
                    newSize.height = maxDimension
                    newSize.width = originalSize.width * (maxDimension / originalSize.height)
                }
            }
            
            // Only resize if needed
            if newSize.width < originalSize.width || newSize.height < originalSize.height {
                UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                return resizedImage
            }
            
            return image
        }
    }
}

// Конструктор с значениями по умолчанию для обратной совместимости
extension ImagePicker {
    init(selectedImage: Binding<UIImage?>) {
        self._selectedImage = selectedImage
        self._isPresented = .constant(true)
        self.onImageSelected = { _ in }
    }
}

struct ImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        Text("ImagePicker не может быть предпросмотрен напрямую")
    }
}

