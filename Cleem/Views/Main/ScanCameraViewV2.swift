import SwiftUI
import AVFoundation
import Photos
import Combine

// Импортируем компоненты
import Cleem

struct ScanCameraViewV2: View {
    @ObservedObject var viewModel = ScanCameraViewModelV2()
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var hasAppeared = false
    @State private var selectedMode: ScanMode = .scanFood
    
    enum ScanMode {
        case scanFood, barcode, foodLabel, gallery
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Camera preview
            if !navigationCoordinator.isFoodAnalyzing {
                CameraPreview(session: viewModel.session)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(navigationCoordinator.isFoodAnalyzing ? 0.3 : 1.0)
            }
            
            // Captured image if available
            if let image = viewModel.capturedImage, !navigationCoordinator.isFoodAnalyzing {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // UI overlay
            VStack(spacing: 0) {
                // Top section with close button
                HStack {
                    Button(action: { 
                        navigationCoordinator.showScanCamera = false 
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                
                // Mode buttons
                HStack(spacing: 20) {
                    ScanModeButtonV2(
                        iconName: "camera",
                        text: "Scan Food",
                        isActive: selectedMode == .scanFood,
                        action: { 
                            selectedMode = .scanFood
                        }
                    )
                    
                    ScanModeButtonV2(
                        iconName: "barcode.viewfinder",
                        text: "Barcode",
                        isActive: selectedMode == .barcode,
                        action: { 
                            selectedMode = .barcode 
                            navigationCoordinator.showBarcodeScannerView = true
                        }
                    )
                    
                    ScanModeButtonV2(
                        iconName: "tag",
                        text: "Food label",
                        isActive: selectedMode == .foodLabel,
                        action: { 
                            selectedMode = .foodLabel
                        }
                    )
                    
                    ScanModeButtonV2(
                        iconName: "photo",
                        text: "Gallery",
                        isActive: selectedMode == .gallery,
                        action: { 
                            selectedMode = .gallery
                            viewModel.openGallery()
                        }
                    )
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Loading indicator
                if navigationCoordinator.isFoodAnalyzing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Анализ изображения...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(width: 200, height: 100)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(15)
                }
                
                Spacer()
                
                // Bottom section with capture buttons
                HStack {
                    // Flash toggle
                    Button(action: { viewModel.toggleFlash() }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 50, height: 50)
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                    
                    // Capture button
                    Button(action: { viewModel.capturePhoto() }) {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 5)
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(Color.white).frame(width: 60, height: 60))
                    }
                    
                    Spacer()
                    
                    // Empty space for symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 50, height: 50)
                        .padding(.trailing, 30)
                }
                .padding(.bottom, 30)
                
                // Progress bar at bottom
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 4)
                    .padding(.horizontal)
            }
            
            // Recognized food detail view
            if viewModel.showRecognizedFoodDetail, let food = viewModel.selectedRecognizedFood {
                RecognizedFoodDetailView(
                    food: food,
                    onAdd: {
                        viewModel.saveRecognizedFood(food)
                    },
                    onClose: {
                        viewModel.showRecognizedFoodDetail = false
                        navigationCoordinator.showScanCamera = false
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .sheet(isPresented: $viewModel.showGalleryPicker) {
            ImagePicker(selectedImage: $viewModel.galleryImage, isPresented: $viewModel.showGalleryPicker, onImageSelected: { image in
                if let selectedImage = image {
                    viewModel.analyzeGalleryImage(selectedImage)
                }
            })
        }
        .sheet(isPresented: $viewModel.showHelpSheet) {
            // Help sheet content
            VStack {
                Text("Как использовать сканер")
                    .font(.title)
                    .padding()
                
                Text("1. Наведите камеру на еду\n2. Нажмите кнопку для фото\n3. Дождитесь результата")
                    .multilineTextAlignment(.leading)
                    .padding()
                
                Button("Закрыть") {
                    viewModel.showHelpSheet = false
                }
                .padding()
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            print("📱 ScanCameraViewV2 appeared on screen")
            
            // Reset state if this is a new camera opening
            if !navigationCoordinator.isFoodAnalyzing {
                viewModel.capturedImage = nil
                viewModel.recognizedFoods = []
                viewModel.showRecognizedFoodDetail = false
            }
            
            // Always force camera permission check and setup when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.checkCameraPermission()
            }
            
            // For debugging only
            if !hasAppeared {
                hasAppeared = true
            } else {
                print("📱 View has re-appeared without being fully dismissed")
            }
        }
        .onDisappear {
            print("📱 ScanCameraViewV2 disappeared from screen")
            // Stop session when view is closed
            viewModel.stopCameraSession()
        }
    }
}

// Helper component for the scan mode buttons
struct ScanModeButtonV2: View {
    let iconName: String
    let text: String
    var isActive: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? Color.blue.opacity(0.2) : Color.white)
                        .frame(width: 60, height: 50)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? .blue : .black)
                }
                
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }
}

class ScanCameraViewModelV2: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn: Bool = false
    @Published var capturedImage: UIImage?
    @Published var galleryImage: UIImage?
    @Published var showGalleryPicker: Bool = false
    @Published var showAlert: Bool = false
    @Published var showHelpSheet: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var recognizedFoods: [RecognizedFoodV2] = []
    @Published var showRecognizedFoodDetail: Bool = false
    @Published var selectedRecognizedFood: RecognizedFoodV2?
    
    private let output = AVCapturePhotoOutput()
    private var isConfigured: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        print("ScanCameraViewModelV2 initialized")
    }
    
    func checkCameraPermission() {
        print("📷 Checking camera permission")
        
        // Ensure we're on the main thread for UI updates
        DispatchQueue.main.async {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                print("📷 Camera permission already authorized")
                self.setupCamera()
                
            case .notDetermined:
                print("📷 Camera permission not determined, requesting...")
                // Request permission
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        print("📷 Camera permission granted")
                        DispatchQueue.main.async {
                            self?.setupCamera()
                        }
                    } else {
                        print("📷 Camera permission denied by user")
                        DispatchQueue.main.async {
                            self?.showAlert(title: "Доступ запрещен", message: "Вы отклонили доступ к камере. Пожалуйста, включите его в настройках устройства для использования сканера.")
                        }
                    }
                }
                
            case .denied, .restricted:
                print("📷 Camera permission denied or restricted")
                self.showAlert(title: "Доступ к камере", message: "Доступ к камере запрещен. Пожалуйста, разрешите доступ к камере в настройках устройства для использования сканера.")
                
            @unknown default:
                print("📷 Unknown camera permission status")
                self.showAlert(title: "Ошибка камеры", message: "Неизвестная ошибка при доступе к камере. Пожалуйста, проверьте разрешения и попробуйте снова.")
            }
        }
    }
    
    private func setupCamera() {
        print("📷 Starting camera setup")
        
        // Force reset configuration flag if camera wasn't working
        isConfigured = false
        
        // Stop session if it's running
        if session.isRunning {
            print("📷 Stopping current session first")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
        
        // Add very slight delay to ensure session stop completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            print("📷 Preparing camera configuration")
            DispatchQueue.global(qos: .userInitiated).async {
                print("📷 Starting camera configuration on background thread")
                
                self.session.beginConfiguration()
                
                // Remove existing inputs/outputs first
                for input in self.session.inputs {
                    self.session.removeInput(input)
                }
                for output in self.session.outputs {
                    self.session.removeOutput(output)
                }
                
                // Add input device
                guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    DispatchQueue.main.async {
                        print("📷 Error: Camera device not found")
                        self.showAlert(title: "Ошибка камеры", message: "Не удалось найти камеру.")
                    }
                    return
                }
                
                // Configure camera settings for optimal quality
                do {
                    try videoDevice.lockForConfiguration()
                    
                    // Set auto-focus to continuous
                    if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                        videoDevice.focusMode = .continuousAutoFocus
                        print("📷 Set continuous auto-focus")
                    }
                    
                    // Set auto-exposure to continuous
                    if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                        videoDevice.exposureMode = .continuousAutoExposure
                        print("📷 Set continuous auto-exposure")
                    }
                    
                    // Set white balance to continuous auto
                    if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                        videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
                        print("📷 Set continuous auto-white balance")
                    }
                    
                    // Set low light boost if available
                    if videoDevice.isLowLightBoostSupported {
                        videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
                        print("📷 Enabled low light boost when available")
                    }
                    
                    videoDevice.unlockForConfiguration()
                } catch {
                    print("📷 Error configuring camera device: \(error.localizedDescription)")
                }
                
                do {
                    let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                    if self.session.canAddInput(videoInput) {
                        self.session.addInput(videoInput)
                        print("📷 Added video input")
                    } else {
                        DispatchQueue.main.async {
                            print("📷 Error: Cannot add video input")
                            self.showAlert(title: "Ошибка камеры", message: "Не удалось настроить входной поток камеры.")
                        }
                        return
                    }
                    
                    // Configure photo output
                    if self.session.canAddOutput(self.output) {
                        self.session.addOutput(self.output)
                        
                        // Configure for highest quality photo
                        self.output.isHighResolutionCaptureEnabled = true
                        self.output.isLivePhotoCaptureEnabled = false
                        
                        print("📷 Added photo output with high resolution")
                    } else {
                        DispatchQueue.main.async {
                            print("📷 Error: Cannot add photo output")
                            self.showAlert(title: "Ошибка камеры", message: "Не удалось настроить выходной поток камеры.")
                        }
                        return
                    }
                    
                    // Commit configuration
                    self.session.commitConfiguration()
                    self.isConfigured = true
                    print("📷 Camera configured successfully")
                    
                    // Start session immediately on background thread
                    self.session.startRunning()
                    print("📷 Camera session started")
                    
                    // Ensure UI updates on main thread
                    DispatchQueue.main.async {
                        // Force refresh UI
                        self.objectWillChange.send()
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        print("📷 Error initializing camera: \(error.localizedDescription)")
                        self.showAlert(title: "Ошибка камеры", message: "Ошибка инициализации камеры: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.alertTitle = title
            self?.alertMessage = message
            self?.showAlert = true
        }
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                isFlashOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isFlashOn = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Ошибка настройки вспышки: \(error)")
        }
    }
    
    func capturePhoto() {
        print("📷 Attempting to capture photo")
        
        // First verify camera is configured
        if !isConfigured {
            print("📷 Camera not configured, setting up...")
            setupCamera()
            
            // Show message and return - camera will be set up for next attempt
            showAlert(title: "Камера инициализируется", message: "Пожалуйста, подождите несколько секунд и попробуйте снова.")
            return
        }
        
        // Check if session is running
        if !session.isRunning {
            print("📷 Camera session not running, starting...")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
                
                // Show message to try again
                DispatchQueue.main.async {
                    self?.showAlert(title: "Камера запускается", message: "Пожалуйста, подождите несколько секунд и попробуйте снова.")
                }
            }
            return
        }
        
        // Настройки фото
        let settings = AVCapturePhotoSettings()
        
        // Настраиваем вспышку, если нужно
        if isFlashOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            settings.flashMode = .on
        }
        
        // Делаем снимок
        print("📷 Taking photo")
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func openGallery() {
        self.showGalleryPicker = true
    }
    
    func analyzeGalleryImage(_ image: UIImage) {
        // Устанавливаем флаг анализа в NavigationCoordinator
        DispatchQueue.main.async {
            NavigationCoordinator.shared.isFoodScanning = false
            NavigationCoordinator.shared.isFoodAnalyzing = true
        }
        
        // Сохраняем изображение для отображения
        self.capturedImage = image
        
        // Используем новый FoodRecognitionManagerV2 для распознавания еды
        let foodRecognitionManager = FoodRecognitionManagerV2()
        
        // Сначала проверим валидность API ключа
        foodRecognitionManager.checkApiKeyValidity()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Ошибка проверки API ключа: \(error)")
                }
            }, receiveValue: { isValid in
                if !isValid {
                    print("API ключ недействителен, сбрасываем на значения по умолчанию")
                    // Сбрасываем API ключи и обновляем менеджер
                    FoodRecognitionManagerV2.initializeApiKeys()
                    foodRecognitionManager.setDefaultApiKeys()
                }
                
                // Продолжаем с распознаванием
                self.performFoodRecognition(with: foodRecognitionManager, image: image)
            })
            .store(in: &cancellables)
    }
    
    private func performFoodRecognition(with manager: FoodRecognitionManagerV2, image: UIImage) {
        manager.recognizeFood(from: image)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print("Ошибка распознавания еды: \(error)")
                    // При ошибке показываем сообщение, что еда не распознана
                    DispatchQueue.main.async {
                        NavigationCoordinator.shared.isFoodAnalyzing = false
                        NavigationCoordinator.shared.notFoodDetected = true
                        NavigationCoordinator.shared.showScanCamera = false
                    }
                }
            }, receiveValue: { [weak self] recognizedFoods in
                DispatchQueue.main.async {
                    // Сохраняем распознанные продукты
                    self?.recognizedFoods = recognizedFoods
                    
                    // Проверяем, распознал ли что-то
                    if recognizedFoods.isEmpty {
                        // Если список пуст, значит на изображении нет еды
                        NavigationCoordinator.shared.isFoodAnalyzing = false
                        NavigationCoordinator.shared.notFoodDetected = true
                        NavigationCoordinator.shared.showScanCamera = false
                    } else {
                        // Food item(s) detected - show detail view for first item
                        NavigationCoordinator.shared.isFoodAnalyzing = false
                        NavigationCoordinator.shared.notFoodDetected = false
                        
                        // Set the selected recognized food and show the detail view
                        if let firstFood = recognizedFoods.first {
                            self?.selectedRecognizedFood = firstFood
                            self?.showRecognizedFoodDetail = true
                        }
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    func saveRecognizedFood(_ food: RecognizedFoodV2) {
        // Create a FoodRecognitionManager to save the food
        let recognitionManager = FoodRecognitionManagerV2()
        
        // Сохраняем распознанную еду в CoreData
        recognitionManager.saveFoodToCoreData(food: food, image: food.originalImage)
        
        // Reset the view model state
        self.showRecognizedFoodDetail = false
        self.selectedRecognizedFood = nil
        
        // Show success banner
        let banner = BannerData(title: "Добавлено в журнал питания", detail: food.name, type: .success)
        NotificationCenter.default.post(name: Notification.Name("ShowBanner"), object: banner)
        
        // Close the camera view
        NavigationCoordinator.shared.showScanCamera = false
    }
    
    func stopCameraSession() {
        print("📷 Stopping camera session")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                print("📷 Camera session stopped")
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ScanCameraViewModelV2: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📷 Photo output callback received")
        
        // Обработка ошибок
        if let error = error {
            print("📷 Error capturing photo: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(title: "Ошибка фото", message: "Не удалось сделать снимок: \(error.localizedDescription)")
            }
            return
        }
        
        // Получаем данные изображения
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("📷 Error converting photo data to UIImage")
            DispatchQueue.main.async { [weak self] in
                self?.showAlert(title: "Ошибка фото", message: "Не удалось обработать снимок")
            }
            return
        }
        
        print("📷 Photo captured successfully - \(Int(image.size.width))x\(Int(image.size.height))")
        
        // Сохраняем изображение и начинаем анализ
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            self?.analyzeGalleryImage(image) // Используем тот же метод, что и для галереи
        }
    }
}

// MARK: - Supporting Views

struct RecognizedFoodDetailView: View {
    let food: RecognizedFoodV2
    let onAdd: () -> Void
    let onClose: () -> Void
    
    @State private var selectedIngredients: Set<String> = []
    @State private var portions: Int = 1
    @State private var selectedSize: String = "Medium"
    @State private var isModifyingIngredients: Bool = false
    @State private var currentNutrition: NutritionDataV2?
    
    private let sizes = ["Small", "Medium", "Large"]
    private let sizeMultipliers: [String: Double] = [
        "Small": 0.7,
        "Medium": 1.0,
        "Large": 1.4
    ]
    
    // Calculate adjusted nutrition values based on selected ingredients, portion and size
    private var adjustedNutrition: NutritionDataV2? {
        guard let baseNutrition = food.nutritionData else { return nil }
        
        if selectedIngredients.isEmpty && !isModifyingIngredients {
            // If not modifying ingredients and none selected, use original
            let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
            let portionMultiplier = Double(portions)
            let totalMultiplier = sizeMultiplier * portionMultiplier
            
            return NutritionDataV2(
                calories: baseNutrition.calories * totalMultiplier,
                protein: baseNutrition.protein * totalMultiplier,
                fat: baseNutrition.fat * totalMultiplier,
                carbs: baseNutrition.carbs * totalMultiplier,
                sugar: baseNutrition.sugar.map { $0 * totalMultiplier },
                fiber: baseNutrition.fiber.map { $0 * totalMultiplier },
                sodium: baseNutrition.sodium.map { $0 * totalMultiplier },
                source: baseNutrition.source,
                foodLabel: baseNutrition.foodLabel,
                cholesterol: baseNutrition.cholesterol.map { $0 * totalMultiplier },
                servingSize: baseNutrition.servingSize,
                servingUnit: baseNutrition.servingUnit
            )
        } else if isModifyingIngredients {
            return currentNutrition
        } else {
            // No ingredients left or invalid state
            return baseNutrition
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // Dish header with image
                HStack {
                    if let image = food.originalImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        if let nutrition = adjustedNutrition {
                            Text("\(Int(nutrition.calories)) calories")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Portion and size selection
                HStack(spacing: 15) {
                    // Portion stepper
                    HStack {
                        Button(action: {
                            if portions > 1 {
                                portions -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                        
                        Text("\(portions)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30)
                        
                        Button(action: {
                            portions += 1
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    // Size selector
                    HStack {
                        ForEach(sizes, id: \.self) { size in
                            Button(action: {
                                selectedSize = size
                            }) {
                                Text(size)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(selectedSize == size ? Color.white : Color.clear)
                                    .foregroundColor(selectedSize == size ? .black : .white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Nutrition info
                if let nutrition = adjustedNutrition {
                    HStack(spacing: 20) {
                        // Protein
                        NutrientCircle(
                            value: Int(nutrition.protein),
                            label: "P",
                            unit: "g",
                            color: .red
                        )
                        
                        // Carbs
                        NutrientCircle(
                            value: Int(nutrition.carbs),
                            label: "C",
                            unit: "g",
                            color: .blue
                        )
                        
                        // Fat
                        NutrientCircle(
                            value: Int(nutrition.fat),
                            label: "F",
                            unit: "g",
                            color: .orange
                        )
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Ingredients section
                if let ingredients = food.ingredients, !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Ingredients")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if isModifyingIngredients {
                                Button(action: {
                                    // Exit ingredient editing mode
                                    isModifyingIngredients = false
                                }) {
                                    Text("Done")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Button(action: {
                                    // Enter ingredient editing mode
                                    isModifyingIngredients = true
                                    // Initialize with all ingredients selected
                                    selectedIngredients = Set(ingredients)
                                }) {
                                    Text("Modify")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(ingredients, id: \.self) { ingredient in
                                    HStack {
                                        if isModifyingIngredients {
                                            // Checkbox when modifying
                                            Button(action: {
                                                if selectedIngredients.contains(ingredient) {
                                                    selectedIngredients.remove(ingredient)
                                                } else {
                                                    selectedIngredients.insert(ingredient)
                                                }
                                                // Update nutrition based on selected ingredients
                                                updateNutrition()
                                            }) {
                                                Image(systemName: selectedIngredients.contains(ingredient) ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(selectedIngredients.contains(ingredient) ? .green : .gray)
                                            }
                                        } else {
                                            // Bullet point when not modifying
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 6))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text(ingredient)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal)
                                    .background(Color.gray.opacity(isModifyingIngredients && selectedIngredients.contains(ingredient) ? 0.3 : 0.0))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 150)
                    }
                }
                
                Spacer()
                
                // Buttons
                HStack(spacing: 20) {
                    Button(action: onClose) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.5))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onAdd) {
                        Text("Add")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.9))
            .cornerRadius(20)
            .padding(20)
        }
        .onAppear {
            // Initialize with base nutrition
            self.currentNutrition = food.nutritionData
        }
    }
    
    private func updateNutrition() {
        guard let baseNutrition = food.nutritionData,
              let ingredients = food.ingredients,
              !ingredients.isEmpty else { return }
        
        // Calculate the ratio of each ingredient's contribution to the total
        let totalIngredients = Double(ingredients.count)
        let ingredientRatio = 1.0 / totalIngredients
        
        // Start with zero values
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalCarbs: Double = 0
        var totalSugar: Double = 0
        var totalFiber: Double = 0
        var totalSodium: Double = 0
        var totalCholesterol: Double = 0
        
        // Sum values for selected ingredients
        for ingredient in selectedIngredients {
            totalCalories += baseNutrition.calories * ingredientRatio
            totalProtein += baseNutrition.protein * ingredientRatio
            totalFat += baseNutrition.fat * ingredientRatio
            totalCarbs += baseNutrition.carbs * ingredientRatio
            totalSugar += (baseNutrition.sugar ?? 0) * ingredientRatio
            totalFiber += (baseNutrition.fiber ?? 0) * ingredientRatio
            totalSodium += (baseNutrition.sodium ?? 0) * ingredientRatio
            totalCholesterol += (baseNutrition.cholesterol ?? 0) * ingredientRatio
        }
        
        // Apply size and portion multipliers
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        let totalMultiplier = sizeMultiplier * portionMultiplier
        
        // Create updated nutrition data
        currentNutrition = NutritionDataV2(
            calories: totalCalories * totalMultiplier,
            protein: totalProtein * totalMultiplier,
            fat: totalFat * totalMultiplier,
            carbs: totalCarbs * totalMultiplier,
            sugar: totalSugar * totalMultiplier,
            fiber: totalFiber * totalMultiplier,
            sodium: totalSodium * totalMultiplier,
            source: baseNutrition.source,
            foodLabel: baseNutrition.foodLabel,
            cholesterol: totalCholesterol * totalMultiplier,
            servingSize: baseNutrition.servingSize,
            servingUnit: baseNutrition.servingUnit
        )
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.frame
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            // Update layer frame 
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
        
        // If session is not running, start it on a background thread
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }
}

struct ScanCameraViewV2_Previews: PreviewProvider {
    static var previews: some View {
        ScanCameraViewV2()
            .environmentObject(NavigationCoordinator.shared)
    }
} 