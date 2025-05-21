import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import Vision
import Foundation
import CoreData
import Combine

// Define our namespaced version of CameraMode to avoid conflicts
enum ScanCameraMode {
    case food
    case barcode
    case label
    case gallery
}

// Глобальная переменная для хранения ссылки на текущий контроллер камеры
var currentCameraController: UIImagePickerController?

// Глобальная функция для запуска захвата фото
func triggerCameraCapture() {
    guard let controller = currentCameraController else { return }
    
    // Проверяем, что контроллер настроен на использование камеры
    if controller.sourceType == .camera {
        // Сбрасываем состояние сканирования перед новым захватом изображения
        NotificationCenter.default.post(name: NSNotification.Name("ScannerResetCompleted"), object: nil)
        
        controller.takePicture()
    } else {
        // В симуляторе показываем всплывающее окно выбора изображения, если оно еще не показано
        if !controller.isBeingPresented && !controller.isBeingDismissed {
            // Сбрасываем состояние сканирования перед новым захватом изображения
            NotificationCenter.default.post(name: NSNotification.Name("ScannerResetCompleted"), object: nil)
            
            // Современный способ получения ключевого окна в iOS 15+
            let scene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first as? UIWindowScene
            
            let rootViewController = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            rootViewController?.present(controller, animated: true, completion: nil)
        }
    }
}

struct ScanCameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = ScanCameraViewModel()
    @State private var scanMode: ScanCameraMode = .food
    @State private var showImagePicker = false
    
    var body: some View {
        ZStack {
            // Фон камеры
            ScanCameraPreview(session: viewModel.session)
                .edgesIgnoringSafeArea(.all)
            
            // Оверлей с направляющими
            VStack {
                // Верхняя навигационная панель
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
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
                    
                    Spacer()
                    
                    Button(action: {
                        // Действие для помощи
                        viewModel.showHelpSheet = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 40, height: 40)
                            Image(systemName: "questionmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer()
                
                // Направляющие для кадрирования - белые уголки
                ZStack {
                    // Верхний левый угол
                    VStack {
                        HStack {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 30))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 30, y: 0))
                            }
                            .stroke(Color.white, lineWidth: 3)
                            
                            Spacer()
                            
                            // Верхний правый угол
                            Path { path in
                                path.move(to: CGPoint(x: 30, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 30))
                            }
                            .stroke(Color.white, lineWidth: 3)
                            .rotation3DEffect(.degrees(90), axis: (x: 0, y: 0, z: 1))
                        }
                        
                        Spacer()
                        
                        HStack {
                            // Нижний левый угол
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 30))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 30, y: 0))
                            }
                            .stroke(Color.white, lineWidth: 3)
                            .rotation3DEffect(.degrees(270), axis: (x: 0, y: 0, z: 1))
                            
                            Spacer()
                            
                            // Нижний правый угол
                            Path { path in
                                path.move(to: CGPoint(x: 30, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 0, y: 30))
                            }
                            .stroke(Color.white, lineWidth: 3)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 0, z: 1))
                        }
                    }
                }
                .frame(width: 300, height: 300)
                
                Spacer()
                
                // Нижняя панель с кнопками и режимами сканирования
                VStack(spacing: 20) {
                    // Режимы сканирования
                    HStack(spacing: 25) {
                        ScanModeButton(
                            iconName: "camera.viewfinder",
                            text: "Scan Food",
                            isActive: scanMode == .food,
                            action: { scanMode = .food }
                        )
                        
                        ScanModeButton(
                            iconName: "barcode.viewfinder",
                            text: "Barcode",
                            isActive: scanMode == .barcode,
                            action: { scanMode = .barcode }
                        )
                        
                        ScanModeButton(
                            iconName: "tag",
                            text: "Food label",
                            isActive: scanMode == .label,
                            action: { scanMode = .label }
                        )
                        
                        ScanModeButton(
                            iconName: "photo",
                            text: "Gallery",
                            isActive: scanMode == .gallery,
                            action: {
                                showImagePicker = true
                            }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Кнопка фотовспышки и спуска затвора
                    HStack {
                    Button(action: {
                            viewModel.toggleFlash()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 50, height: 50)
                                Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                            .foregroundColor(.white)
                                    .font(.system(size: 18))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            switch scanMode {
                            case .food:
                                viewModel.capturePhoto()
                            case .barcode:
                                viewModel.startBarcodeScanning()
                            case .label:
                                viewModel.capturePhotoForLabel()
                            case .gallery:
                                showImagePicker = true
                            }
                        }) {
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 5)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.white).frame(width: 60, height: 60))
                        }
                        
                        Spacer()
                        
                        // Пустой placeholder для баланса in HStack
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 50, height: 50)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
                .background(Color.black.opacity(0.5))
            }
        }
        .onAppear {
            viewModel.checkCameraPermission()
            viewModel.scanMode = scanMode
        }
        .onChange(of: scanMode) { oldValue, newValue in
            viewModel.scanMode = newValue
        }
        .onChange(of: viewModel.capturedImage) { oldValue, newValue in
            if newValue != nil {
                // Обработка захваченного изображения в зависимости от режима
                switch scanMode {
                case .food:
                    viewModel.analyzeImage()
                case .label:
                    viewModel.analyzeFoodLabel()
                default:
                    break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScannerResetCompleted"))) { _ in
            // Сбрасываем предыдущий результат сканирования
            self.viewModel.capturedImage = nil
            self.viewModel.recognizedFoods = []
        }
        .fullScreenCover(item: $viewModel.analyzedFood) { food in
            FoodDetailView(food: food, onAdd: {
                // При добавлении еды закрываем весь экран сканирования
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $viewModel.showRecognizedFoodDetail) {
            if let recognizedFood = viewModel.selectedRecognizedFood {
                FoodDetailView(food: recognizedFood, onAdd: {
                    // Add to food log and close scanner
                    viewModel.saveRecognizedFood(recognizedFood)
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBarcodeScanner) {
            BarcodeScannerView(
                isPresented: $viewModel.showBarcodeScanner,
                onBarcodeScan: { code in
                    viewModel.processBarcode(code)
                },
                onClose: {
                    viewModel.showBarcodeScanner = false
                }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ScanCameraImagePicker(image: $viewModel.galleryImage, onPick: { image in
                viewModel.analyzeGalleryImage(image)
            })
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.showHelpSheet) {
            ScanHelpView()
        }
    }
}

// Компонент кнопки режима сканирования
struct ScanModeButton: View {
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

class ScanCameraViewModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn: Bool = false
    @Published var capturedImage: UIImage?
    @Published var galleryImage: UIImage?
    @Published var analyzedFood: Food?
    @Published var showBarcodeScanner: Bool = false
    @Published var showAlert: Bool = false
    @Published var showHelpSheet: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var recognizedFoods: [RecognizedFood] = []
    @Published var combinedDishName: String = ""
    @Published var showRecognizedFoodDetail: Bool = false
    @Published var selectedRecognizedFood: RecognizedFood?
    
    var scanMode: ScanCameraMode = .food
    
    private let output = AVCapturePhotoOutput()
    private var isConfigured: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        print("ScanCameraViewModel initialized")
    }
    
    func checkCameraPermission() {
        print("checkCameraPermission called")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            showAlert(title: "Camera Access", message: "Please enable camera access in Settings to use scanning features.")
        }
    }
    
    func setupCamera() {
        guard !self.isConfigured else { return }
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) && session.canAddOutput(output) {
                session.addInput(input)
                session.addOutput(output)
                self.isConfigured = true
                
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.session.startRunning()
                }
            }
        } catch {
            print("Ошибка настройки камеры: \(error.localizedDescription)")
            showAlert(title: "Camera Error", message: "Could not set up the camera. Please try again.")
        }
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch {
            try? device.lockForConfiguration()
            
            if self.isFlashOn {
                device.torchMode = .off
            } else {
                try? device.setTorchModeOn(level: 1.0)
            }
            
            device.unlockForConfiguration()
            self.isFlashOn.toggle()
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        // Update scanning state in NavigationCoordinator
        DispatchQueue.main.async {
            NavigationCoordinator.shared.isFoodScanning = true
        }
        
        // Enable flash if it's on
        if self.isFlashOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            settings.flashMode = .on
        }
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func capturePhotoForLabel() {
        capturePhoto()
    }
    
    func startBarcodeScanning() {
        showBarcodeScanner = true
    }
    
    func processBarcode(_ code: String) {
        print("Scanning barcode: \(code)")
        
        // Поиск продукта по штрих-коду в базе данных
        let context = CoreDataManager.shared.context
        let request = NSFetchRequest<Food>(entityName: "Food")
        request.predicate = NSPredicate(format: "barcode == %@", code)
        
        do {
            let results = try context.fetch(request)
            
            if let existingFood = results.first {
                // Нашли существующий продукт
                analyzedFood = existingFood
            } else {
                // Для настоящего приложения здесь был бы запрос к API базы данных продуктов
                // Сейчас просто направляем на стандартное распознавание по изображению
                self.showAlert(title: "Barcode Not Found", message: "This barcode is not in our database. Please try scanning the food directly.")
            }
        } catch {
            print("Ошибка при поиске продукта по штрих-коду: \(error)")
            self.showAlert(title: "Database Error", message: "Could not search the database. Please try scanning the food directly.")
        }
    }
    
    func analyzeGalleryImage(_ image: UIImage) {
        // Устанавливаем флаг анализа в NavigationCoordinator
        DispatchQueue.main.async {
            NavigationCoordinator.shared.isFoodScanning = false
            NavigationCoordinator.shared.isFoodAnalyzing = true
        }
        
        // Выбираем подходящий менеджер распознавания еды
        if NavigationCoordinator.shared.shouldUseNewScanCameraView {
            // Используем новый FoodRecognitionManagerV2
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
                    foodRecognitionManager.recognizeFood(from: image)
                        .sink(receiveCompletion: { [weak self] completion in
                            // Обработка завершения аналогично оригинальному коду
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                print("Ошибка распознавания еды: \(error)")
                                DispatchQueue.main.async {
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = true
                                    NavigationCoordinator.shared.showScanCamera = false
                                }
                            }
                        }, receiveValue: { [weak self] recognizedFoods in
                            DispatchQueue.main.async {
                                // Конвертируем RecognizedFoodV2 в RecognizedFood для совместимости
                                let convertedFoods: [RecognizedFood] = recognizedFoods.map { food in
                                    // Используем новый конструктор для конвертации
                                    return RecognizedFood(from: food)
                                }
                                
                                // Store the recognized foods
                                self?.recognizedFoods = convertedFoods
                                
                                // Обработка результатов
                                if convertedFoods.isEmpty {
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = true
                                    NavigationCoordinator.shared.showScanCamera = false
                                } else {
                                    // Food item(s) detected
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = false
                                    
                                    // Save the image for reference
                                    self?.capturedImage = image
                                    
                                    // Show detail view for first item
                                    if let firstFood = convertedFoods.first {
                                        self?.selectedRecognizedFood = firstFood
                                        self?.showRecognizedFoodDetail = true
                                    }
                                }
                            }
                        })
                        .store(in: &self.cancellables)
                })
                .store(in: &cancellables)
        } else {
            // Используем старый FoodRecognitionManager
            let foodRecognitionManager = FoodRecognitionManager()
            
            foodRecognitionManager.recognizeFood(from: image)
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
                        // Store the recognized foods
                        self?.recognizedFoods = recognizedFoods
                        
                        // Проверяем, распознал ли Gemini что-то как еду
                        if recognizedFoods.isEmpty {
                            // Если список пуст, значит на изображении нет еды
                            NavigationCoordinator.shared.isFoodAnalyzing = false
                            NavigationCoordinator.shared.notFoodDetected = true
                            NavigationCoordinator.shared.showScanCamera = false
                        } else {
                            // Food item(s) detected - show detail view for first item
                            NavigationCoordinator.shared.isFoodAnalyzing = false
                            NavigationCoordinator.shared.notFoodDetected = false
                            
                            // Save the image for reference
                            self?.capturedImage = image
                            
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
    }
    
    func analyzeFoodLabel() {
        guard let capturedImage = self.capturedImage else { return }
        
        // Используем общий метод распознавания пищи
        analyzeImage()
    }
    
    func analyzeImage() {
        // Устанавливаем флаг анализа в NavigationCoordinator
        DispatchQueue.main.async {
            NavigationCoordinator.shared.isFoodScanning = false
            NavigationCoordinator.shared.isFoodAnalyzing = true
        }
        
        guard let image = self.capturedImage else {
            DispatchQueue.main.async {
                NavigationCoordinator.shared.isFoodAnalyzing = false
                NavigationCoordinator.shared.notFoodDetected = true
                NavigationCoordinator.shared.showScanCamera = false
            }
            return
        }
        
        // Выбираем подходящий менеджер распознавания еды
        if NavigationCoordinator.shared.shouldUseNewScanCameraView {
            // Используем новый FoodRecognitionManagerV2
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
                    foodRecognitionManager.recognizeFood(from: image)
                        .sink(receiveCompletion: { [weak self] completion in
                            // Обработка завершения аналогично оригинальному коду
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                print("Ошибка распознавания еды: \(error)")
                                DispatchQueue.main.async {
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = true
                                    NavigationCoordinator.shared.showScanCamera = false
                                }
                            }
                        }, receiveValue: { [weak self] recognizedFoods in
                            DispatchQueue.main.async {
                                // Конвертируем RecognizedFoodV2 в RecognizedFood для совместимости
                                let convertedFoods: [RecognizedFood] = recognizedFoods.map { food in
                                    // Используем новый конструктор для конвертации
                                    return RecognizedFood(from: food)
                                }
                                
                                // Store the recognized foods
                                self?.recognizedFoods = convertedFoods
                                
                                // Обработка результатов
                                if convertedFoods.isEmpty {
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = true
                                    NavigationCoordinator.shared.showScanCamera = false
                                } else {
                                    // Food item(s) detected
                                    NavigationCoordinator.shared.isFoodAnalyzing = false
                                    NavigationCoordinator.shared.notFoodDetected = false
                                    
                                    // Show detail view for first item
                                    if let firstFood = convertedFoods.first {
                                        self?.selectedRecognizedFood = firstFood
                                        self?.showRecognizedFoodDetail = true
                                    }
                                }
                            }
                        })
                        .store(in: &self.cancellables)
                })
                .store(in: &cancellables)
        } else {
            // Используем старый FoodRecognitionManager для распознавания еды через Edamam API
            let foodRecognitionManager = FoodRecognitionManager()
            
            foodRecognitionManager.recognizeFood(from: image)
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
                        // Store the recognized foods
                        self?.recognizedFoods = recognizedFoods
                        
                        // Проверяем, распознал ли Gemini что-то как еду
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
    }
    
    func saveRecognizedFood(_ food: RecognizedFood) {
        // Create a FoodRecognitionManager to save the food
        let recognitionManager = FoodRecognitionManager()
        
        // Save the recognized food to CoreData with real nutrition data from Edamam
        recognitionManager.createIndividualFoodItem(recognizedFood: food, image: food.originalImage)
        
        // Reset the view model state
        self.showRecognizedFoodDetail = false
        self.selectedRecognizedFood = nil
        
        // Show success banner
        let banner = BannerData(title: "Added to Food Log", detail: food.name, type: .success)
        NotificationCenter.default.post(name: Notification.Name("ShowBanner"), object: banner)
        
        // Close the camera view
        NavigationCoordinator.shared.showScanCamera = false
    }
    
    // Метод для предложения создания комбинированного блюда
    func suggestCombinedDish(recognizedFoods: [RecognizedFood], image: UIImage) {
        // Используем FoodRecognitionManager для создания комбинированного блюда
        let foodRecognitionManager = FoodRecognitionManager()
        
        // Создаем имя для комбинированного блюда на основе распознанных продуктов
        let dishName = "Combined: " + recognizedFoods.map { $0.name }.joined(separator: ", ")
        
        // Создаем комбинированное блюдо с использованием первого продукта с данными Edamam
        foodRecognitionManager.createCombinedFoodFromRecognizedFoods(name: dishName, foods: recognizedFoods, image: image)
        
        // Закрываем камеру и обновляем UI
        NavigationCoordinator.shared.isFoodAnalyzing = false
        NavigationCoordinator.shared.notFoodDetected = false
        NavigationCoordinator.shared.showScanCamera = false
    }
    
    // Функция для анимации прогресса (имитация)
    func startProgressAnimation() {
        // В реальном приложении здесь была бы анимация прогресса анализа
        // Для демонстрации просто логируем вызов функции
        print("Starting progress animation")
    }
    
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
    }
    
    // Моделируем распознавание еды
    func analyzeFoodWithGemini(image: UIImage) {
        print("Анализируем еду с помощью Gemini API...")
        
        // Показываем индикатор процесса распознавания
        NavigationCoordinator.shared.isFoodAnalyzing = true
        NavigationCoordinator.shared.notFoodDetected = false
        
        // Используем FoodRecognitionManager для распознавания
        let foodRecognitionManager = FoodRecognitionManager()
        
        foodRecognitionManager.recognizeFood(from: image)
            .sink(receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    NavigationCoordinator.shared.isFoodAnalyzing = false
                    
                    if case .failure(let error) = completion {
                        print("Ошибка при распознавании: \(error)")
                        NavigationCoordinator.shared.notFoodDetected = true
                        NavigationCoordinator.shared.showScanCamera = false
                    }
                }
            }, receiveValue: { [weak self] recognizedFoods in
                DispatchQueue.main.async {
                    // Store the recognized foods
                    self?.recognizedFoods = recognizedFoods
                    
                    // Проверяем, распознал ли Gemini что-то как еду
                    if recognizedFoods.isEmpty {
                        // Если список пуст, значит на изображении нет еды
                        NavigationCoordinator.shared.isFoodAnalyzing = false
                        NavigationCoordinator.shared.notFoodDetected = true
                        NavigationCoordinator.shared.showScanCamera = false
                    } else {
                        // Check if multiple food items were detected
                        if recognizedFoods.count > 1 {
                            // Save the image to use for combined dish
                            self?.capturedImage = image
                            
                            // Suggest creating a combined dish
                            self?.suggestCombinedDish(recognizedFoods: recognizedFoods, image: image)
                        } else {
                            // Single food item - proceed as normal
                            NavigationCoordinator.shared.isFoodAnalyzing = false
                            NavigationCoordinator.shared.notFoodDetected = false
                            NavigationCoordinator.shared.showScanCamera = false
                            
                            // Проверяем, действительно ли был установлен recentlyScannedFood
                            if let scannedFood = NavigationCoordinator.shared.recentlyScannedFood {
                                print("ScanCameraView: Успешно установлен recentlyScannedFood: \(scannedFood.name ?? "Unknown"), ID: \(scannedFood.id?.uuidString ?? "nil")")
                                
                                // Проверяем, сохранен ли ID в UserDefaults
                                let savedID = UserDefaults.standard.string(forKey: "lastScannedFoodID") ?? "не сохранено"
                                print("ScanCameraView: ID в UserDefaults: \(savedID)")
                                
                                // Проверяем историю еды в UserDefaults
                                if let foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] {
                                    print("ScanCameraView: В UserDefaults сохранено \(foodHistory.count) позиций еды")
                                } else {
                                    print("ScanCameraView: В UserDefaults нет истории еды")
                                }
                            } else {
                                print("ScanCameraView: ОШИБКА - recentlyScannedFood не был установлен!")
                            }
                        }
                    }
                }
            })
            .store(in: &cancellables)
    }
}

extension ScanCameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Ошибка захвата фото: \(error.localizedDescription)")
            self.showAlert(title: "Photo Error", message: "Could not capture photo. Please try again.")
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            self.showAlert(title: "Photo Error", message: "Could not process captured image.")
            return
        }
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

struct ScanCameraPreview: UIViewRepresentable {
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

// Выбор изображения из галереи
struct ScanCameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onPick: ((UIImage) -> Void)?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ScanCameraImagePicker
        
        init(_ parent: ScanCameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                if let onPick = parent.onPick {
                    onPick(image)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Справка по сканированию
struct ScanHelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Как сканировать продукты")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 15) {
                helpItem(
                    icon: "camera.viewfinder",
                    title: "Scan Food",
                    description: "Наведите камеру на продукт и нажмите кнопку спуска затвора для анализа."
                )
                
                helpItem(
                    icon: "barcode.viewfinder",
                    title: "Barcode",
                    description: "Сканируйте штрих-код на упаковке продукта для получения информации."
                )
                
                helpItem(
                    icon: "tag",
                    title: "Food Label",
                    description: "Сделайте фото этикетки с пищевой ценностью для анализа."
                )
                
                helpItem(
                    icon: "photo",
                    title: "Gallery",
                    description: "Выберите фотографию продукта из галереи для анализа."
                )
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func helpItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 5)
    }
}

struct ScanCameraView_Previews: PreviewProvider {
    static var previews: some View {
        ScanCameraView()
    }
}





