import SwiftUI
import UIKit
import PhotosUI

struct ImagePickerView: View {
    @Binding var isPresented: Bool
    var onImagePicked: (UIImage) -> Void
    
    @State private var selectedImage: UIImage?
    @State private var isShowingLibrary = false
    @State private var isProcessing = false
    @State private var processingProgress = 0.0
    
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                if let image = selectedImage {
                    // Show selected image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .padding()
                } else {
                    // Show placeholder
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("Select a photo from your library")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Choose a clear image of your food for best results")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 15) {
                    if selectedImage != nil {
                        Button(action: {
                            analyzeImage()
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Analyze Food")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    Button(action: {
                        isShowingLibrary = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(selectedImage == nil ? "Choose Photo" : "Choose Another Photo")
                        }
                        .font(.headline)
                        .foregroundColor(selectedImage == nil ? .white : .primary)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(selectedImage == nil ? Color.green : Color(.systemGray5))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("Photo Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                isPresented = false
            }) {
                Text("Cancel")
            })
            .sheet(isPresented: $isShowingLibrary) {
                PHPickerRepresentable(image: $selectedImage)
            }
            .overlay(
                ZStack {
                    if isProcessing {
                        Color.black.opacity(0.7)
                            .edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text("Analyzing food...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("\(Int(processingProgress * 100))%")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
            )
        }
    }
    
    private func analyzeImage() {
        guard let image = selectedImage else { return }
        
        isProcessing = true
        processingProgress = 0
        
        // Simulate analysis progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            processingProgress += 0.03
            if processingProgress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isProcessing = false
                    onImagePicked(image)
                    isPresented = false
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}

struct PHPickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerRepresentable
        
        init(_ parent: PHPickerRepresentable) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self?.parent.image = image
                    }
                }
            }
        }
    }
}

struct UIImagePickerRepresentable: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: UIImagePickerRepresentable
        
        init(_ parent: UIImagePickerRepresentable) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ImagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        ImagePickerView(isPresented: .constant(true), onImagePicked: { _ in })
    }
}

