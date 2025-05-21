import SwiftUI
import AVFoundation
import Vision

struct FoodLabelScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = FoodLabelScannerViewModel()
    
    var body: some View {
        ZStack {
            // Camera preview
            FoodLabelCameraPreview(session: viewModel.session)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay and UI elements
            VStack {
                // Header with buttons
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 40, height: 40)
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // Guide rectangle for positioning label
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 300, height: 200)
                        .overlay(
                            Text("Position Nutrition Facts label here")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .offset(y: -100)
                        )
                }
                
                Spacer()
                
                // Help text and capture button
                VStack(spacing: 20) {
                    Text("Take a clear photo of the nutrition facts label")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    
                    // Capture button
                    Button(action: {
                        viewModel.capturePhoto()
                    }) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 3)
                                .frame(width: 70, height: 70)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.bottom, 20)
            }
            
            // Processing overlay
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Analyzing nutrition label...")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if viewModel.processingProgress > 0 {
                            Text("\(Int(viewModel.processingProgress * 100))%")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.checkCameraPermission()
        }
        .fullScreenCover(item: $viewModel.nutritionInfo) { nutrition in
            // Show nutrition details after successful scan
            NutritionResultView(nutrition: nutrition) {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

class FoodLabelScannerViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0
    @Published var nutritionInfo: FoodNutrition?
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    private let photoOutput = AVCapturePhotoOutput()
    private var isSessionConfigured = false
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCaptureSession()
                    }
                }
            }
        default:
            showAlert(title: "Camera Access Denied", message: "Please enable camera access in Settings to scan food labels.")
        }
    }
    
    func setupCaptureSession() {
        guard !isSessionConfigured else { return }
        
        session.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            showAlert(title: "Camera Error", message: "Could not access camera for scanning.")
            return
        }
        
        guard session.canAddInput(videoInput) else {
            showAlert(title: "Camera Error", message: "Could not add video input.")
            return
        }
        
        session.addInput(videoInput)
        
        // Add photo output
        guard session.canAddOutput(photoOutput) else {
            showAlert(title: "Camera Error", message: "Could not add photo output.")
            return
        }
        
        session.addOutput(photoOutput)
        session.commitConfiguration()
        
        isSessionConfigured = true
        
        // Start running the capture session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if isFlashOn {
                    device.torchMode = .off
                } else {
                    try device.setTorchModeOn(level: 1.0)
                }
                
                device.unlockForConfiguration()
                isFlashOn.toggle()
            } catch {
                print("Could not toggle flash: \(error.localizedDescription)")
            }
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        // Enable flash if it's on
        if isFlashOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            settings.flashMode = .on
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func processLabelImage(_ image: UIImage) {
        isProcessing = true
        processingProgress = 0
        
        // Simulate processing with progress updates
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.processingProgress += 0.05
            if self.processingProgress >= 1.0 {
                timer.invalidate()
                self.simulateNutritionExtraction(from: image)
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
    
    func simulateNutritionExtraction(from image: UIImage) {
        // In a real app, we would use Vision and ML to extract nutrition info
        // For this demo, we'll create mock data
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Create a mock nutrition object based on the scanned label
            let nutrition = FoodNutrition(
                calories: Double.random(in: 100...350),
                protein: Double.random(in: 5...30),
                carbs: Double.random(in: 10...50),
                fat: Double.random(in: 1...20),
                sugars: Double.random(in: 0...15),
                fiber: Double.random(in: 0...7),
                sodium: Double.random(in: 10...500),
                servingSize: 100,
                servingUnit: "г",
                foodName: "Scanned Food Item",
                source: "scanned"
            )
            
            self?.isProcessing = false
            self?.nutritionInfo = nutrition
        }
    }
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.alertTitle = title
            self?.alertMessage = message
            self?.showAlert = true
        }
    }
}

extension FoodLabelScannerViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            showAlert(title: "Photo Error", message: "Could not capture photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            showAlert(title: "Image Error", message: "Could not process captured image.")
            return
        }
        
        processLabelImage(image)
    }
}

struct FoodLabelCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct NutritionResultView: View {
    let nutrition: FoodNutrition
    let onDismiss: () -> Void
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Scanned Nutrition Facts")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top)
                
                // Nutrition summary card
                VStack(spacing: 15) {
                    Text(nutrition.foodName)
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    // Calories
                    HStack {
                        Text("Calories")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(nutrition.calories)) kcal")
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 8)
                    .overlay(Divider(), alignment: .bottom)
                    
                    // Macros
                    Group {
                        nutrientRow(name: "Protein", value: "\(Int(nutrition.protein))g")
                        nutrientRow(name: "Carbohydrates", value: "\(Int(nutrition.carbs))g")
                        nutrientRow(name: "Fat", value: "\(Int(nutrition.fat))g")
                        nutrientRow(name: "Fiber", value: "\(Int(nutrition.fiber ?? 0))g")
                        nutrientRow(name: "Sugar", value: "\(Int(nutrition.sugars ?? 0))g")
                    }
                    
                    Divider()
                    
                    // Vitamins and minerals
                    Text("Scanned from food label")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Action buttons
                VStack(spacing: 15) {
                    Button(action: {
                        // Create a temporary FoodItem to display details
                        let foodItem = FoodItem(
                            name: nutrition.foodName,
                            category: "Scanned Foods",
                            servingSize: 100,
                            servingUnit: "g",
                            description: "Scanned from nutrition label",
                            image: nil
                        )
                        
                        // Set up the navigation
                        navigationCoordinator.foodNutrition = nutrition
                        navigationCoordinator.activeScreen = .nutritionDetails(foodItem: foodItem)
                        
                        // Dismiss this view
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }) {
                        Text("View Details")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Integrate with food logging when implemented
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }) {
                        Text("Add to Food Log")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.top)
            }
            .padding()
        }
    }
    
    private func nutrientRow(name: String, value: String) -> some View {
        HStack {
            Text(name)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct FoodLabelScannerView_Previews: PreviewProvider {
    static var previews: some View {
        FoodLabelScannerView()
    }
}


