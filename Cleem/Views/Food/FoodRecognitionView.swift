import SwiftUI
import PhotosUI
import CoreData

struct FoodRecognitionView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @StateObject private var foodRecognitionManager = FoodRecognitionManagerV2()
    
    @State private var selectedImage: UIImage?
    @State private var photoPickerPresented = false
    @State private var showCamera = false
    @State private var isShowingApiSettings = false
    @State private var isSavingFood = false
    @State private var showCombineDishAlert = false
    @State private var combinedDishName = ""
    
    @State private var selectedFoods: [RecognizedFoodV2] = []
    
    var body: some View {
        NavigationView {
            ZStack {
                // Фон
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Основной контент
                ScrollView {
                    VStack(spacing: 20) {
                        // Секция выбора изображения
                        imageSelectionSection
                        
                        // Секция распознанной еды
                        if !foodRecognitionManager.recognizedFoods.isEmpty {
                            recognizedFoodSection
                        }
                        
                        // Пустое состояние или ошибка
                        if selectedImage == nil && !foodRecognitionManager.isProcessing {
                            emptyState
                        }
                        
                        // Сообщение об ошибке
                        if let errorMessage = foodRecognitionManager.errorMessage {
                            errorView(message: errorMessage)
                        }
                        
                        // Пространство внизу для ботомбара
                        Spacer().frame(height: 100)
                    }
                    .padding()
                }
                
                // BottomBar с кнопками
                VStack {
                    Spacer()
                    
                    if !foodRecognitionManager.recognizedFoods.isEmpty {
                        bottomActionBar
                    }
                }
            }
            .navigationTitle("Food Recognition")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    isShowingApiSettings = true
                }) {
                    Image(systemName: "gear")
                }
            )
            .sheet(isPresented: $photoPickerPresented) {
                PhotoPicker(selectedImage: $selectedImage, onImageSelected: recognizeFood)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(onImageCaptured: { image in
                    selectedImage = image
                    recognizeFood()
                })
            }
            .sheet(isPresented: $isShowingApiSettings) {
                APIKeysSettingsViewV2()
            }
            .overlay(
                Group {
                    if foodRecognitionManager.isProcessing {
                        loadingView
                    }
                }
            )
            .onAppear(perform: checkApiKeys)
        }
    }
    
    // MARK: - Компоненты интерфейса
    
    // Секция выбора изображения
    private var imageSelectionSection: some View {
        VStack(spacing: 15) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Button(action: {
                            selectedImage = nil
                            foodRecognitionManager.recognizedFoods = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.7)))
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            }
            
            // Если нет изображения или идет обработка, показываем кнопки выбора
            if selectedImage == nil || foodRecognitionManager.recognizedFoods.isEmpty {
                HStack(spacing: 20) {
                    // Кнопка камеры
                    Button(action: {
                        showCamera = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(red: 0.89, green: 0.19, blue: 0.18))
                                .clipShape(Circle())
                            
                            Text("Camera")
                                .foregroundColor(.black)
                        }
                    }
                    
                    // Кнопка галереи
                    Button(action: {
                        photoPickerPresented = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(red: 0.89, green: 0.19, blue: 0.18))
                                .clipShape(Circle())
                            
                            Text("Gallery")
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
    }
    
    // Секция распознанной еды
    private var recognizedFoodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized Food")
                .font(.headline)
                .padding(.horizontal)
            
            // Add Combined Dish button if multiple food items are recognized
            if foodRecognitionManager.recognizedFoods.count > 1 {
                // Always prioritize showing the combined dish (usually at index 0)
                let combinedFoods = foodRecognitionManager.recognizedFoods.filter { $0.ingredients != nil && !($0.ingredients ?? []).isEmpty }
                
                if let combinedDish = combinedFoods.first {
                    // Display as combined dish panel
                    ZStack {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                Text(combinedDish.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if let nutrition = combinedDish.nutritionData {
                                    Text("\(Int(nutrition.calories)) kcal")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            
                            // Ingredients preview
                            VStack(alignment: .leading, spacing: 8) {
                                if let ingredients = combinedDish.ingredients, !ingredients.isEmpty {
                                    HStack {
                                        Text("Contains \(ingredients.count) ingredients")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                    }
                                    
                                    // Ingredient list preview (up to 3)
                                    let displayIngredients = ingredients.prefix(3)
                                    ForEach(Array(displayIngredients.enumerated()), id: \.element) { index, ingredient in
                                        HStack {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 6))
                                                .foregroundColor(.gray)
                                            
                                            Text(ingredient)
                                                .font(.system(size: 14))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                    }
                                    
                                    // Show "and more" if there are more ingredients
                                    if ingredients.count > 3 {
                                        Text("and \(ingredients.count - 3) more...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 15)
                                    }
                                }
                            }
                            .padding(15)
                            .background(Color(.systemBackground))
                        }
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        
                        // Add select button at the bottom of the card
                        Button(action: {
                            // Add this dish to selected foods
                            if !selectedFoods.contains(where: { $0.id == combinedDish.id }) {
                                selectedFoods.append(combinedDish)
                            } else {
                                // Remove if already selected
                                selectedFoods.removeAll(where: { $0.id == combinedDish.id })
                            }
                        }) {
                            HStack {
                                Text(selectedFoods.contains(where: { $0.id == combinedDish.id }) ? "Selected" : "Select Dish")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                
                                if selectedFoods.contains(where: { $0.id == combinedDish.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedFoods.contains(where: { $0.id == combinedDish.id }) ? Color.green : Color.blue)
                            .cornerRadius(8)
                            .padding(.horizontal, 15)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                Text("Or select individual ingredients")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // Grid of recognized foods
            ForEach(foodRecognitionManager.recognizedFoods) { food in
                FoodItemCard(food: food, isSelected: selectedFoods.contains { $0.id == food.id }) { isSelected in
                    toggleFoodSelection(food: food, isSelected: isSelected)
                }
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // Пустое состояние
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("Take a photo of your food or select from gallery")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text("We'll recognize the food and calculate its nutritional value")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
    }
    
    // Представление для отображения ошибки
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                
                Text(message.contains("503") || message.contains("overloaded") ? 
                     "Cloud API service is busy. Using on-device recognition instead." : 
                     message)
                    .font(.subheadline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button("Retry") {
                    if selectedImage != nil {
                        recognizeFood()
                    }
                }
                .foregroundColor(.blue)
            }
            
            // If the error message contains 503 or overloaded, show fallback options
            if message.contains("503") || message.contains("overloaded") || message.contains("server busy") {
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("While on-device recognition is not as accurate, you can:")
                        .font(.subheadline)
                    
                    // Option 1: Wait and retry cloud service
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        Text("Wait a few minutes and retry the cloud service")
                            .font(.subheadline)
                    }
                    
                    // Option 2: Search food database
                    Button(action: {
                        navigationCoordinator.showFoodDatabase(onFoodSelected: { selectedFood in
                            // Handle the selected food by adding it to the log
                            if let food = selectedFood as? Food {
                                // Add to consumed nutrients
                                navigationCoordinator.userProfile.addConsumedNutrients(
                                    calories: food.calories,
                                    protein: food.protein,
                                    carbs: food.carbs,
                                    fat: food.fat
                                )
                                
                                // Close the current view
                                presentationMode.wrappedValue.dismiss()
                            }
                        })
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.green)
                            Text("Search food database manually")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
    
    // Нижняя панель с кнопками действий
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                
                // Отмена
                Button(action: {
                    selectedImage = nil
                    foodRecognitionManager.recognizedFoods = []
                    selectedFoods = []
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                Spacer()
                
                // Добавить
                Button(action: addSelectedFoodsToLog) {
                    HStack {
                        Text("Add \(selectedFoods.isEmpty ? "All" : "\(selectedFoods.count)") to Log")
                            .fontWeight(.bold)
                        
                        if isSavingFood {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.leading, 5)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color(red: 0.89, green: 0.19, blue: 0.18))
                    .cornerRadius(8)
                }
                .disabled(foodRecognitionManager.recognizedFoods.isEmpty || isSavingFood)
                
                Spacer()
            }
            
            // Add Combined Dish button if multiple food items are recognized
            if foodRecognitionManager.recognizedFoods.count > 1 {
                Button(action: {
                    showCombineDishAlert = true
                }) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.blue)
                        Text("Create Combined Dish")
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                }
                .alert("Create Combined Dish", isPresented: $showCombineDishAlert) {
                    TextField("Dish Name", text: $combinedDishName)
                    
                    Button("Cancel", role: .cancel) {}
                    
                    Button("Create") {
                        // Create combined dish with selected foods
                        let foodsToUse = selectedFoods.isEmpty ? foodRecognitionManager.recognizedFoods : selectedFoods
                        
                        // Create the combined dish
                        foodRecognitionManager.createCombinedFoodFromRecognizedFoods(
                            name: combinedDishName,
                            foods: foodsToUse,
                            image: selectedImage
                        )
                        
                        // Close the view
                        presentationMode.wrappedValue.dismiss()
                    }
                } message: {
                    Text("Create a combined dish from the recognized food items.")
                }
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -3)
        )
    }
    
    // Индикатор загрузки
    private var loadingView: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Recognizing food...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color.black.opacity(0.7))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Логика
    
    // Проверка наличия API ключей
    private func checkApiKeys() {
        let geminiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let edamamId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let edamamKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        if geminiKey.isEmpty || edamamId.isEmpty || edamamKey.isEmpty {
            // Если ключей нет, показываем экран настроек API
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isShowingApiSettings = true
            }
        }
    }
    
    // Распознавание пищи на изображении
    private func recognizeFood() {
        guard let image = selectedImage else { return }
        
        // Compress the image to reduce payload size
        let maxDimension: CGFloat = 1024  // Maximum dimension (width or height)
        let compressionQuality: CGFloat = 0.7  // JPEG compression quality
        
        // Resize the image if needed
        var processedImage = image
        let imageSize = image.size
        
        if imageSize.width > maxDimension || imageSize.height > maxDimension {
            let scaleFactor = min(maxDimension / imageSize.width, maxDimension / imageSize.height)
            let newWidth = imageSize.width * scaleFactor
            let newHeight = imageSize.height * scaleFactor
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), false, 0.0)
            image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resizedImage
            }
            UIGraphicsEndImageContext()
            
            // Apply JPEG compression
            if let compressedData = processedImage.jpegData(compressionQuality: compressionQuality),
               let compressedImage = UIImage(data: compressedData) {
                processedImage = compressedImage
                print("Image compressed with quality: \(compressionQuality)")
            }
            
            print("Image resized from \(Int(imageSize.width))x\(Int(imageSize.height)) to \(Int(newWidth))x\(Int(newHeight))")
        }
        
        // Add retry counter and max attempts
        func attemptRecognition(retryCount: Int = 0, maxRetries: Int = 2) {
            // Show appropriate message
            if retryCount > 0 {
                foodRecognitionManager.errorMessage = "API server busy. Retrying... (\(retryCount)/\(maxRetries))"
            }
            
            // Выполняем распознавание
            _ = foodRecognitionManager.recognizeFood(from: processedImage)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            // Success - clear any error message if we have results
                            if !self.foodRecognitionManager.recognizedFoods.isEmpty {
                                self.foodRecognitionManager.errorMessage = nil
                            }
                            break
                        case .failure(let error):
                            let errorMsg = error.localizedDescription
                            // If it mentions falling back to on-device recognition, don't retry again
                            if errorMsg.contains("on-device recognition") {
                                // This is already the fallback, so no need to retry
                                self.foodRecognitionManager.errorMessage = "Using on-device recognition. Results may be less accurate."
                                return
                            }
                            
                            // If error contains "503" or "overloaded" and we haven't exceeded max retries
                            if (errorMsg.contains("503") || 
                                errorMsg.contains("overloaded")) && 
                                retryCount < maxRetries {
                                // Wait 2 seconds before retrying
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    attemptRecognition(retryCount: retryCount + 1, maxRetries: maxRetries)
                                }
                            } else {
                                // Set error message for other cases or when we've exceeded retries
                                self.foodRecognitionManager.errorMessage = errorMsg
                            }
                        }
                    },
                    receiveValue: { recognizedFoods in
                        // Результаты распознавания уже сохранены в foodRecognitionManager.recognizedFoods
                    }
                )
        }
        
        // Start the first attempt
        attemptRecognition()
    }
    
    // Добавление или удаление еды из выбранных
    private func toggleFoodSelection(food: RecognizedFoodV2, isSelected: Bool) {
        if isSelected {
            if !selectedFoods.contains(where: { $0.id == food.id }) {
                selectedFoods.append(food)
            }
        } else {
            selectedFoods.removeAll { $0.id == food.id }
        }
    }
    
    // Добавление выбранной еды в журнал питания
    private func addSelectedFoodsToLog() {
        isSavingFood = true
        
        // Если ничего не выбрано, добавляем все распознанные продукты
        let foodsToAdd = selectedFoods.isEmpty ? foodRecognitionManager.recognizedFoods : selectedFoods
        
        // Для каждого продукта добавляем данные о питательных веществах в профиль пользователя
        for food in foodsToAdd {
            if let nutrition = food.nutritionData {
                // Обновляем профиль пользователя
                navigationCoordinator.userProfile.addConsumedNutrients(
                    calories: nutrition.calories,
                    protein: nutrition.protein,
                    carbs: nutrition.carbs,
                    fat: nutrition.fat
                )
                
                // Сохраняем в историю питания (если нужно реализовать позже)
            }
        }
        
        // Добавляем небольшую задержку для отображения индикатора загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSavingFood = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Вспомогательные компоненты

// Карточка продукта
struct FoodItemCard: View {
    let food: RecognizedFoodV2
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
    @State private var localIsSelected: Bool = false
    
    init(food: RecognizedFoodV2, isSelected: Bool, onSelectionChanged: @escaping (Bool) -> Void) {
        self.food = food
        self.isSelected = isSelected
        self.onSelectionChanged = onSelectionChanged
        self._localIsSelected = State(initialValue: isSelected)
    }
    
    var body: some View {
        Button(action: {
            localIsSelected.toggle()
            onSelectionChanged(localIsSelected)
        }) {
            HStack(spacing: 15) {
                // Изображение продукта (маленькая миниатюра исходного изображения)
                ZStack {
                    if let image = food.originalImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Название продукта
                    Text(food.name)
                        .font(.headline)
                    
                    if let nutrition = food.nutritionData {
                        // Калории
                        Text("\(Int(nutrition.calories)) calories")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // БЖУ
                        HStack(spacing: 10) {
                            NutrientTag(label: "P", value: Int(nutrition.protein))
                            NutrientTag(label: "C", value: Int(nutrition.carbs))
                            NutrientTag(label: "F", value: Int(nutrition.fat))
                        }
                    } else {
                        Text("Nutrition data unavailable")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Чекбокс для выбора
                ZStack {
                    Circle()
                        .stroke(localIsSelected ? Color(red: 0.89, green: 0.19, blue: 0.18) : Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if localIsSelected {
                        Circle()
                            .fill(Color(red: 0.89, green: 0.19, blue: 0.18))
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: localIsSelected ? Color(red: 0.89, green: 0.19, blue: 0.18).opacity(0.3) : Color.clear, radius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(localIsSelected ? Color(red: 0.89, green: 0.19, blue: 0.18) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

// Тег для отображения питательных веществ (белки, жиры, углеводы)
struct NutrientTag: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(nutrientColor)
                .cornerRadius(4)
            
            Text("\(value)g")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
    
    private var nutrientColor: Color {
        switch label {
        case "P": return Color.red.opacity(0.8)
        case "C": return Color.blue.opacity(0.7)
        case "F": return Color.orange.opacity(0.7)
        default: return Color.gray
        }
    }
}

// Компонент выбора фото из галереи
struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImageSelected: () -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
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
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            self.parent.selectedImage = image
                            self.parent.onImageSelected()
                        }
                    }
                }
            }
        }
    }
}

// Экран камеры для съемки фото
struct CameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct FoodRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        FoodRecognitionView()
            .environmentObject(NavigationCoordinator.shared)
    }
}



