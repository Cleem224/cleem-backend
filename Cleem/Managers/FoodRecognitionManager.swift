import Foundation
import UIKit
import Combine
import CoreData

// MARK: - Data Models

class FoodRecognitionManager: ObservableObject {
    // MARK: - Properties
    
    // API ключи
    private var geminiApiKey: String
    private var edamamAppId: String
    private var edamamAppKey: String
    
    // Состояние
    @Published var isProcessing: Bool = false
    @Published var recognizedFoods: [RecognizedFood] = []
    @Published var errorMessage: String?
    
    // URL сессия для сетевых запросов
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(geminiApiKey: String, edamamAppId: String, edamamAppKey: String) {
        self.geminiApiKey = geminiApiKey
        self.edamamAppId = edamamAppId
        self.edamamAppKey = edamamAppKey
        
        // Конфигурация сессии
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // Удобный инициализатор, который берет ключи из UserDefaults
    convenience init() {
        // Сначала установим ключи API
        FoodRecognitionManager.initializeApiKeys()
        
        // Теперь берем ключи из UserDefaults
        let geminiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let edamamId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let edamamKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        self.init(geminiApiKey: geminiKey, edamamAppId: edamamId, edamamAppKey: edamamKey)
        
        // Логирование для отладки
        print("🔑 FoodRecognitionManager инициализирован с ключами:")
        print("   Gemini API: \(geminiKey.prefix(10))...")
        print("   Edamam App ID: \(edamamId)")
        print("   Edamam App Key: \(edamamKey.prefix(10))...")
    }
    
    // Статический метод для принудительной инициализации API ключей
    static func initializeApiKeys() {
        // Обновленные ключи для работы с API
        let defaultGeminiKey = "AIzaSyBJpqVjBzcKAI7D6GLuTVatp-qZgtEtf9I"
        let defaultEdamamAppId = "866cd6b2"
        let defaultEdamamAppKey = "d731d4ccac5db314f017faa8968784a5"
        let defaultFoodDbId = "b8fc1835"
        let defaultFoodDbKey = "3e85e1b27b125c78a76a6605d6d526f0"
        
        // Устанавливаем ключи в UserDefaults
        UserDefaults.standard.set(defaultGeminiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(defaultEdamamAppId, forKey: "edamam_app_id")
        UserDefaults.standard.set(defaultEdamamAppKey, forKey: "edamam_app_key")
        UserDefaults.standard.set(defaultFoodDbId, forKey: "edamam_food_db_id")
        UserDefaults.standard.set(defaultFoodDbKey, forKey: "edamam_food_db_key")
        
        // Принудительная синхронизация
        UserDefaults.standard.synchronize()
        
        print("🔄 API ключи принудительно инициализированы")
    }
    
    // Метод для установки дефолтных API-ключей
    func setDefaultApiKeys() {
        // Используем статический метод для установки ключей в UserDefaults
        FoodRecognitionManager.initializeApiKeys()
        
        // Получаем обновленные ключи из UserDefaults
        let newGeminiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let newEdamamId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let newEdamamKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        // Напрямую обновляем ключи в текущем экземпляре
        self.geminiApiKey = newGeminiKey
        self.edamamAppId = newEdamamId
        self.edamamAppKey = newEdamamKey
        
        print("✅ API ключи обновлены в экземпляре FoodRecognitionManager")
    }
    
    // MARK: - Main Methods
    
    /// Основной метод для распознавания пищи по изображению
    func recognizeFood(from image: UIImage) -> AnyPublisher<[RecognizedFood], FoodRecognitionError> {
        self.isProcessing = true
        self.errorMessage = nil
        
        // 1. Сначала используем Gemini Vision API для распознавания пищи на изображении
        return detectFoodWithGemini(image: image)
            .flatMap { foodItems -> AnyPublisher<[RecognizedFood], FoodRecognitionError> in
                // 2. Получаем питательную информацию для каждого распознанного продукта
                return self.getNutritionDataForFoods(foods: foodItems, image: image)
            }
            .handleEvents(receiveOutput: { [weak self] foods in
                self?.recognizedFoods = foods
                self?.isProcessing = false
                
                // Сохраняем все распознанные продукты в CoreData
                for food in foods {
                    self?.saveFoodToCoreData(food: food, image: food.originalImage)
                }
                
                // Важно: не отправляем здесь уведомление FoodUpdated,
                // так как оно будет отправлено в ScanCameraView
            }, receiveCompletion: { [weak self] completion in
                self?.isProcessing = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            })
            .eraseToAnyPublisher()
    }
    
    // Метод для сохранения распознанной еды в CoreData
    private func saveFoodToCoreData(food: RecognizedFood, image: UIImage?) {
        print("\n===== SAVING FOOD TO CORE DATA =====")
        print("Saving food '\(food.name)' to CoreData")
        
        // Проверяем, есть ли данные о питательной ценности
        if food.nutritionData == nil {
            print("⚠️ Создаем данные о питательной ценности по умолчанию, так как они отсутствуют")
            var updatedFood = food
            updatedFood.nutritionData = NutritionData(
                calories: 100.0,
                protein: 5.0,
                fat: 2.0,
                carbs: 15.0,
                sugar: 1.0,
                fiber: 1.0,
                sodium: 5.0,
                source: "default",
                foodLabel: food.name
            )
            saveFoodToCoreData(food: updatedFood, image: image)
            return
        }
        
        let nutritionData = food.nutritionData!
        
        // Проверяем, есть ли уже продукт с таким именем
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", food.name)
        
        do {
            let existingFoods = try context.fetch(fetchRequest)
            
            if let existingFood = existingFoods.first {
                print("⚠️ Продукт с именем '\(food.name)' уже существует в базе данных. Обновляем существующую запись.")
                
                // Обновляем данные существующего продукта
                existingFood.calories = nutritionData.calories
                existingFood.protein = nutritionData.protein
                existingFood.carbs = nutritionData.carbs
                existingFood.fat = nutritionData.fat
                existingFood.sugar = nutritionData.sugar ?? 0
                existingFood.fiber = nutritionData.fiber ?? 0
                existingFood.sodium = nutritionData.sodium ?? 0
                existingFood.createdAt = Date() // Обновляем время для сортировки
                
                // Очень важно: явно отмечаем, что это НЕ ингредиент
                existingFood.isIngredient = false
                
                // Сохраняем флаг в UserDefaults
                if let id = existingFood.id?.uuidString {
                    UserDefaults.standard.set(true, forKey: "single_food_\(id)")
                    UserDefaults.standard.set(false, forKey: "food_ingredient_\(id)")
                    
                    // Удаляем из всех списков удаленных продуктов
                    var deletedFoodIds = UserDefaults.standard.array(forKey: "deletedFoodItems") as? [String] ?? []
                    deletedFoodIds.removeAll { $0 == id }
                    UserDefaults.standard.set(deletedFoodIds, forKey: "deletedFoodItems")
                    
                    var permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] ?? [:]
                    permanentlyDeletedIngredients.removeValue(forKey: id)
                    UserDefaults.standard.set(permanentlyDeletedIngredients, forKey: "permanentlyDeletedIngredients")
                }
                
                // Обновляем изображение только при необходимости
                if let newImageData = processImageForStorage(image: food.originalImage ?? image),
                   (existingFood.imageData == nil || existingFood.imageData!.count < newImageData.count) {
                    existingFood.imageData = newImageData
                }
                
                // Сохраняем изменения
                try context.save()
                print("Successfully updated food '\(food.name)' in CoreData")
                
                // Используем CoreDataManager для обновления записи в UserDefaults
                CoreDataManager.shared.saveFoodItem(food: existingFood)
                
                // Делаем этот продукт последним отсканированным
                NavigationCoordinator.shared.recentlyScannedFood = existingFood
                
                // Сохраняем ID последнего отсканированного продукта
                UserDefaults.standard.set(existingFood.id?.uuidString, forKey: "lastScannedFoodID")
                UserDefaults.standard.synchronize()
                
                // Уведомляем UI о необходимости обновления
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                print("===== FOOD UPDATE COMPLETED =====\n")
                return
            }
        } catch {
            print("⚠️ Ошибка при проверке существующих продуктов: \(error)")
        }
        
        // Если продукт не найден, создаем новый
        let newFood = Food(context: context)
        newFood.id = UUID()
        newFood.name = food.name
        
        // Set nutrition data
        newFood.calories = nutritionData.calories
        newFood.protein = nutritionData.protein
        newFood.carbs = nutritionData.carbs
        newFood.fat = nutritionData.fat
        newFood.sugar = nutritionData.sugar ?? 0
        newFood.fiber = nutritionData.fiber ?? 0
        newFood.sodium = nutritionData.sodium ?? 0
        
        newFood.createdAt = Date()
        newFood.servingSize = 100
        newFood.servingUnit = "г"
        
        // Очень важно: явно отмечаем, что это НЕ ингредиент
        newFood.isIngredient = false
        
        // Process and save image if available
        if let originalImage = food.originalImage ?? image {
            newFood.imageData = processImageForStorage(image: originalImage)
        }
        
        // Save to CoreData
        do {
            try context.save()
            print("Successfully saved food '\(food.name)' to CoreData")
            print("Calories: \(newFood.calories), Protein: \(newFood.protein)g, Carbs: \(newFood.carbs)g, Fat: \(newFood.fat)g")
            
            // Явно устанавливаем флаги в UserDefaults
            if let id = newFood.id?.uuidString {
                UserDefaults.standard.set(true, forKey: "single_food_\(id)")
                UserDefaults.standard.set(false, forKey: "food_ingredient_\(id)")
            }
            
            // Используем CoreDataManager вместо прямого сохранения в UserDefaults
            CoreDataManager.shared.saveFoodItem(food: newFood)
            
            // Add the nutrients to today's consumption
            NavigationCoordinator.shared.userProfile.addConsumedFood(
                calories: newFood.calories,
                protein: newFood.protein,
                carbs: newFood.carbs,
                fat: newFood.fat
            )
            
            // Set as recently scanned food in NavigationCoordinator
            NavigationCoordinator.shared.recentlyScannedFood = newFood
            
            // Сохраняем ID последнего отсканированного продукта
            if let id = newFood.id?.uuidString {
                UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
                UserDefaults.standard.synchronize()
            }
            
            // Notify the UI to update
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            print("===== FOOD SAVING COMPLETED =====\n")
        } catch {
            print("Error saving food to CoreData: \(error)")
            print("===== FOOD SAVING FAILED =====\n")
        }
    }
    
    // Вспомогательный метод для обработки изображения перед сохранением
    private func processImageForStorage(image: UIImage?) -> Data? {
        guard let img = image else {
            print("⚠️ ОШИБКА: Исходное изображение отсутствует")
            return nil
        }
        
        // Печатаем информацию об исходном изображении
        print("📸 ОБРАБОТКА ИЗОБРАЖЕНИЯ: Исходный размер \(img.size), scale \(img.scale), orientation \(img.imageOrientation.rawValue)")
        
        // Нормализуем ориентацию изображения
        let normalizedImage = normalizeImageOrientation(img)
        
        // Гарантируем минимальные размеры изображения
        var resizedImage = normalizedImage
        let minDimension: CGFloat = 200 // Минимальная ширина/высота для хранения
        
        // Изменяем размер изображения для оптимального хранения
        let targetSize: CGSize
        if normalizedImage.size.width < minDimension || normalizedImage.size.height < minDimension {
            // Увеличиваем маленькие изображения до минимального размера
            let scale = minDimension / min(normalizedImage.size.width, normalizedImage.size.height)
            targetSize = CGSize(width: normalizedImage.size.width * scale, height: normalizedImage.size.height * scale)
        } else if normalizedImage.size.width > 800 || normalizedImage.size.height > 800 {
            // Уменьшаем большие изображения
            let scale = 800 / max(normalizedImage.size.width, normalizedImage.size.height)
            targetSize = CGSize(width: normalizedImage.size.width * scale, height: normalizedImage.size.height * scale)
        } else {
            // Оставляем размер без изменений для изображений в оптимальном диапазоне
            targetSize = normalizedImage.size
        }
        
        // Только изменяем размер если необходимо
        if targetSize != normalizedImage.size {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                resizedImage = resized
            }
            UIGraphicsEndImageContext()
            
            print("↓ ИЗОБРАЖЕНИЕ \(targetSize.width > normalizedImage.size.width ? "УВЕЛИЧЕНО" : "УМЕНЬШЕНО"): с \(normalizedImage.size) на \(resizedImage.size)")
        }
        
        // Сохраняем в формате JPEG с высоким качеством
        print("💾 СОХРАНЕНИЕ JPEG: Размер \(resizedImage.size), scale \(resizedImage.scale)")
        
        // Попробуем сначала максимальное качество
        var imageData = resizedImage.jpegData(compressionQuality: 0.95)
        
        // Проверяем результат JPEG сжатия
        if let data = imageData, data.count < 100 {
            print("⚠️ ПРЕДУПРЕЖДЕНИЕ: Размер JPEG данных слишком мал (\(data.count) байт), пробуем PNG")
            // Если JPEG данные слишком малы, пробуем PNG
            imageData = resizedImage.pngData()
        }
        
        // Финальная проверка - гарантируем что данные изображения существуют и читаются обратно
        if let finalData = imageData {
            print("✅ ИЗОБРАЖЕНИЕ СОХРАНЕНО: \(finalData.count) байт")
            
            // Проверяем что изображение можно прочитать обратно
            if let reloadedImage = UIImage(data: finalData) {
                print("✅ УСПЕШНАЯ ПРОВЕРКА: Изображение восстановлено, размер \(reloadedImage.size), scale \(reloadedImage.scale)")
                
                // Если это изображение яблока, убедимся что оно имеет достаточный размер
                let isApple = img.accessibilityIdentifier == "apple" || (img.accessibilityLabel?.lowercased().contains("apple") ?? false)
                if isApple && finalData.count < 1000 {
                    print("🍎 СПЕЦИАЛЬНАЯ ОБРАБОТКА: Увеличиваем качество изображения яблока")
                    // Принудительно создаем большее изображение для яблока
                    let size = CGSize(width: 400, height: 400)
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    
                    // Заполняем фон
                    UIColor.systemRed.withAlphaComponent(0.2).setFill()
                    UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
                    
                    // Рисуем яблоко в центре
                    reloadedImage.draw(in: CGRect(
                        x: (size.width - reloadedImage.size.width) / 2,
                        y: (size.height - reloadedImage.size.height) / 2,
                        width: reloadedImage.size.width,
                        height: reloadedImage.size.height
                    ))
                    
                    let enhancedImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    if let enhancedData = enhancedImage?.pngData(), enhancedData.count > 1000 {
                        print("🍎 УЛУЧШЕННОЕ ИЗОБРАЖЕНИЕ ЯБЛОКА: \(enhancedData.count) байт")
                        return enhancedData
                    }
                }
                
                // Дополнительное сохранение отладочного файла
                let tempDir = NSTemporaryDirectory()
                let tempPath = tempDir + "debug_image_\(Date().timeIntervalSince1970).jpg"
                
                do {
                    try finalData.write(to: URL(fileURLWithPath: tempPath))
                    print("📄 СОХРАНЕН ОТЛАДОЧНЫЙ ФАЙЛ: \(tempPath)")
                } catch {
                    print("❌ ОШИБКА ЗАПИСИ ОТЛАДОЧНОГО ФАЙЛА: \(error)")
                }
                
                return finalData
            } else {
                print("❌ КРИТИЧЕСКАЯ ОШИБКА: Изображение не может быть прочитано обратно!")
                return nil
            }
        } else {
            print("❌ ОШИБКА СЖАТИЯ: Не удалось создать данные изображения")
            return nil
        }
    }
    
    // Нормализация ориентации изображения
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
    
    // MARK: - Gemini Vision API
    
    /// Обнаружение пищи с помощью Gemini API
    private func detectFoodWithGemini(image: UIImage) -> AnyPublisher<[RecognizedFood], FoodRecognitionError> {
        guard let resizedImage = resizeImageForGemini(image),
              let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            return Fail(error: .imageError("Ошибка подготовки изображения")).eraseToAnyPublisher()
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Проверяем, установлен ли API ключ Gemini
        guard !geminiApiKey.isEmpty else {
            return Fail(error: .apiKeyMissing("Ключ API Gemini не установлен")).eraseToAnyPublisher()
        }
        
        // Формируем URL запроса к Gemini API
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: .invalidURL).eraseToAnyPublisher()
        }
        
        // Добавление API ключа
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: geminiApiKey)
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: .networkError("Не удалось создать URL")).eraseToAnyPublisher()
        }
        
        // Текст запроса - просим определить, что за еда на изображении
        let prompt = """
        Identify the food items in this image. You are specialized in food recognition.
        Provide a JSON list of objects with properties 'name' and 'confidence'. 
        If you can't identify any specific food items, return an empty array [].
        Important: only respond with valid JSON, no other text.
        Example response: [{"name": "Apple", "confidence": 0.95}, {"name": "Yogurt", "confidence": 0.85}]
        Or if no food is detected: []
        """
        
        // Создание запроса
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Формирование тела запроса (на основе примера из Google AI Studio)
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "topK": 32,
                "topP": 1,
                "maxOutputTokens": 2048
            ]
        ]
        
        // Преобразование тела запроса в JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: .recognitionFailed("Ошибка сериализации запроса: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        // Выполнение запроса
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Ошибка: Ответ не является HTTP ответом")
                    throw FoodRecognitionError.networkError("Неизвестная ошибка сети")
                }
                
                print("Получен ответ от API с кодом: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Нет данных"
                    print("Ошибка API: \(responseString)")
                    throw FoodRecognitionError.networkError("Ошибка сетевого запроса: \(responseString)")
                }
                return data
            }
            .decode(type: FoodRecognitionGeminiResponse.self, decoder: JSONDecoder())
            .tryMap { response -> [RecognizedFood] in
                // Обработка текстового ответа от Gemini и преобразование в распознанные продукты
                guard let content = response.candidates?.first?.content,
                      let text = content.parts?.first?.text else {
                    throw FoodRecognitionError.invalidResponse
                }
                
                // Парсинг текста для извлечения списка продуктов
                let recognizedFoods = try self.parseFoodItemsFromGeminiResponse(text: text, image: image)
                
                // Если пустой список, значит еда не распознана - генерируем ошибку
                if recognizedFoods.isEmpty {
                    throw FoodRecognitionError.recognitionFailed("Еда не обнаружена на изображении")
                }
                
                return recognizedFoods
            }
            .mapError { error -> FoodRecognitionError in
                if let recognitionError = error as? FoodRecognitionError {
                    return recognitionError
                }
                return .recognitionFailed("Ошибка распознавания: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    /// Парсинг списка продуктов из ответа Gemini
    private func parseFoodItemsFromGeminiResponse(text: String, image: UIImage) throws -> [RecognizedFood] {
        print("Полный ответ от Gemini: \(text)")
        
        // Проверяем, содержит ли ответ указание на отсутствие еды
        let noFoodPhrases = ["no food", "empty array", "couldn't identify", "could not identify", "[]", "no specific food", "не найдено"]
        
        for phrase in noFoodPhrases {
            if text.lowercased().contains(phrase.lowercased()) {
                print("Gemini не обнаружил еду на изображении")
                return [] // Возвращаем пустой массив, если текст указывает на отсутствие еды
            }
        }
        
        // Попытка найти JSON в тексте с помощью регулярных выражений
        // 1. Ищем массив JSON [...]
        let jsonArrayRegex = try? NSRegularExpression(pattern: "\\[\\s*\\{[^\\[\\]]*\\}\\s*\\]")
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        
        // Если нашли массив JSON, используем его
        if let arrayMatch = jsonArrayRegex?.firstMatch(in: text, range: fullRange),
           let range = Range(arrayMatch.range, in: text) {
            let jsonText = String(text[range])
            print("Найден JSON массив: \(jsonText)")
            
            do {
                let jsonData = jsonText.data(using: .utf8)!
                let foods = try JSONDecoder().decode([GeminiFoodItem].self, from: jsonData)
                
                // Проверяем, если массив пуст или содержит пустые записи
                if foods.isEmpty || foods.allSatisfy({ $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    print("Gemini вернул пустой массив продуктов")
                    return []
                }
                
                return foods.map { item in
                    // Улучшаем форматирование названия продукта
                    let formattedName = formatFoodName(item.name)
                    return RecognizedFood(
                        name: formattedName,
                        confidence: item.confidence ?? 0.9,
                        originalImage: image
                    )
                }
            } catch {
                print("Ошибка при декодировании JSON массива: \(error)")
                // Продолжаем к другим методам извлечения
            }
        }
        
        // Специальная проверка на пустой массив в тексте ответа
        if text.contains("[]") || text.contains("[ ]") {
            print("Gemini вернул пустой JSON массив")
            return []
        }
        
        // Возвращаем пустой массив вместо создания продукта по умолчанию
        print("Не удалось распознать еду на изображении")
        return []
    }
    
    // Форматирует название продукта, делая его более презентабельным
    private func formatFoodName(_ name: String) -> String {
        // Удаляем лишние пробелы
        var formatted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Обрабатываем некоторые распространенные форматы и приводим к стандартному виду
        formatted = formatted.replacingOccurrences(of: "_", with: " ")
        formatted = formatted.replacingOccurrences(of: "-", with: " ")
        
        // Делаем первую букву каждого слова заглавной
        let words = formatted.components(separatedBy: " ")
        let capitalizedWords = words.map { word in
            if !word.isEmpty {
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            return word
        }
        
        formatted = capitalizedWords.joined(separator: " ")
        
        // Используем более понятные названия для некоторых продуктов
        let replacements: [String: String] = [
            "Coca-cola": "Coca-Cola",
            "Coca Cola": "Coca-Cola",
            "Яблоко": "Apple",
            "Апельсин": "Orange",
            "Банан": "Banana"
        ]
        
        if let replacement = replacements[formatted] {
            return replacement
        }
        
        return formatted
    }
    
    /// Извлекает название продукта из текстовой строки
    private func extractFoodFromText(_ text: String) -> String? {
        // Удаляем этот метод, так как мы используем более совершенные методы
        return nil
    }
    
    // MARK: - Edamam API
    
    /// Получение данных о питательной ценности для списка продуктов
    private func getNutritionDataForFoods(foods: [RecognizedFood], image: UIImage) -> AnyPublisher<[RecognizedFood], FoodRecognitionError> {
        // Если список пуст, возвращаем пустой результат
        guard !foods.isEmpty else {
            return Just([]).setFailureType(to: FoodRecognitionError.self).eraseToAnyPublisher()
        }
        
        print("Получаем данные о питательной ценности для \(foods.count) продуктов")
        
        // Создаем массив запросов для каждого продукта
        let requests = foods.map { food in
            return getNutritionData(for: food.name)
                .map { nutritionData -> RecognizedFood in
                    print("Получены данные о питательной ценности для \(food.name): \(nutritionData.calories) ккал")
                    var updatedFood = food
                    updatedFood.nutritionData = nutritionData
                    
                    // Важно: убедимся, что оригинальное изображение сохраняется
                    if updatedFood.originalImage == nil {
                        updatedFood.originalImage = image
                    }
                    
                    return updatedFood
                }
                .catch { error -> AnyPublisher<RecognizedFood, Never> in
                    // При ошибке API создаем данные по умолчанию, чтобы продукт все равно добавился
                    print("⚠️ Используем данные по умолчанию для \(food.name): \(error.localizedDescription)")
                    
                    // Создаем базовые данные о питательной ценности
                    let defaultNutrition = NutritionData(
                        calories: 100.0,
                        protein: 5.0,
                        fat: 2.0,
                        carbs: 15.0,
                        sugar: 1.0,
                        fiber: 1.0,
                        sodium: 5.0,
                        source: "default",
                        foodLabel: food.name
                    )
                    
                    var foodWithDefaultValues = food
                    foodWithDefaultValues.nutritionData = defaultNutrition
                    
                    // Сохраняем оригинальное изображение
                    if foodWithDefaultValues.originalImage == nil {
                        foodWithDefaultValues.originalImage = image
                    }
                    
                    return Just(foodWithDefaultValues).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        // Объединяем все запросы в один издатель
        return Publishers.MergeMany(requests)
            .collect()
            .setFailureType(to: FoodRecognitionError.self)
            .eraseToAnyPublisher()
    }
    
    /// Получение данных о питательной ценности для одного продукта
    private func getNutritionData(for foodName: String) -> AnyPublisher<NutritionData, Error> {
        // Принудительная установка актуальных ключей
        let edamamId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? "866cd6b2"
        let edamamKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? "d731d4ccac5db314f017faa8968784a5"
        
        // Убедитесь, что у нас есть API ключи
        guard !edamamId.isEmpty, !edamamKey.isEmpty else {
            print("⚠️ ОШИБКА: Отсутствуют API ключи Edamam для анализа нутриентов")
            return Fail(error: FoodRecognitionError.nutritionAnalysisFailed("Отсутствуют API ключи Edamam")).eraseToAnyPublisher()
        }
        
        // Подготовка URL
        let urlString = "https://api.edamam.com/api/nutrition-data"
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: FoodRecognitionError.networkError("Недопустимый URL")).eraseToAnyPublisher()
        }
        
        // Формируем запрос ингредиента - используем имя продукта как ингредиент
        // Пример: "100g apple"
        let ingredient = "100g \(foodName)"
        
        // Добавление параметров API
        urlComponents.queryItems = [
            URLQueryItem(name: "app_id", value: edamamId),
            URLQueryItem(name: "app_key", value: edamamKey),
            URLQueryItem(name: "ingr", value: ingredient)
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: FoodRecognitionError.networkError("Не удалось создать URL")).eraseToAnyPublisher()
        }
        
        print("🌐 Отправка запроса к Edamam API (Nutrition Analysis):")
        print("   URL: \(url)")
        print("   App ID: \(edamamId)")
        print("   Ингредиент: \(ingredient)")
        
        // Создание запроса
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Выполнение запроса
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Ошибка: Ответ не является HTTP ответом")
                    throw FoodRecognitionError.networkError("Неизвестная ошибка сети")
                }
                
                print("📥 Получен ответ от API с кодом: \(httpResponse.statusCode)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let responseString = String(data: data, encoding: .utf8) ?? "Нет данных"
                    print("❌ Ошибка API: \(responseString)")
                    throw FoodRecognitionError.networkError("Ошибка сетевого запроса: \(responseString)")
                }
                return data
            }
            .decode(type: EdamamResponse.self, decoder: JSONDecoder())
            .tryMap { response -> NutritionData in
                // Преобразование ответа Edamam в нашу модель NutritionData
                let calories = response.calories
                let protein = response.totalNutrients.PROCNT?.quantity ?? 0
                let fat = response.totalNutrients.FAT?.quantity ?? 0
                let carbs = response.totalNutrients.CHOCDF?.quantity ?? 0
                let sugar = response.totalNutrients.SUGAR?.quantity
                let fiber = response.totalNutrients.FIBTG?.quantity
                let sodium = response.totalNutrients.NA?.quantity
                
                print("✅ Получены данные для \(foodName): калории=\(calories), белки=\(protein), жиры=\(fat), углеводы=\(carbs)")
                
                return NutritionData(
                    calories: calories,
                    protein: protein,
                    fat: fat,
                    carbs: carbs,
                    sugar: sugar,
                    fiber: fiber,
                    sodium: sodium,
                    source: "edamam",
                    foodLabel: foodName
                )
            }
            .mapError { error -> Error in
                if let nutritionError = error as? FoodRecognitionError {
                    return nutritionError
                }
                print("❌ Ошибка анализа питательных веществ: \(error.localizedDescription)")
                return FoodRecognitionError.nutritionAnalysisFailed("Ошибка анализа питательных веществ: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    /// Сохранить API ключи
    func saveApiKeys(geminiKey: String, edamamAppId: String, edamamAppKey: String, foodDbId: String = "", foodDbKey: String = "") {
        UserDefaults.standard.set(geminiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(edamamAppId, forKey: "edamam_app_id")
        UserDefaults.standard.set(edamamAppKey, forKey: "edamam_app_key")
        
        // Сохраняем ключи для Food Database API, если они предоставлены
        if !foodDbId.isEmpty {
            UserDefaults.standard.set(foodDbId, forKey: "edamam_food_db_id")
        }
        
        if !foodDbKey.isEmpty {
            UserDefaults.standard.set(foodDbKey, forKey: "edamam_food_db_key")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// Resize image for Gemini API
    private func resizeImageForGemini(_ image: UIImage) -> UIImage? {
        // Gemini API has image size limits, so we resize the image to be under these limits
        let maxDimension: CGFloat = 1024
        
        let originalSize = image.size
        var newSize = originalSize
        
        // Calculate the new size, maintaining aspect ratio
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            if originalSize.width > originalSize.height {
                newSize.height = originalSize.height / originalSize.width * maxDimension
                newSize.width = maxDimension
            } else {
                newSize.width = originalSize.width / originalSize.height * maxDimension
                newSize.height = maxDimension
            }
        } else {
            // Image is already small enough
            return image
        }
        
        // Create a new image with the calculated size
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("Resized image from \(originalSize) to \(newSize) for Gemini API")
        return resizedImage
    }
    
    // Метод для интеллектуального определения названия продукта по изображению
    private func determineRealFoodName(image: UIImage) -> String {
        // Теперь этот метод просто возвращает пустую строку, чтобы
        // пользователь мог сам ввести название еды, если Gemini не смог распознать
        return ""
    }
    
    // Выбирает системную иконку на основе названия продукта
    private func getFoodIconName(_ foodName: String) -> String {
        // Вместо локальных определений используем динамический подход
        // Все иконки будут запрашиваться из Edamam API
        // А при отсутствии данных используем универсальную иконку
        return "circle.grid.2x2.fill" // Универсальная иконка для всех продуктов
    }
    
    // Выбирает цвет для иконки на основе названия продукта
    private func getFoodIconColor(_ foodName: String) -> UIColor {
        // Вместо локальных определений используем один универсальный цвет
        // для всех продуктов, полученных через API
        return .systemBlue // Универсальный цвет для всех продуктов
    }
    
    // MARK: - Handling Multiple Foods
    func createCombinedFoodFromRecognizedFoods(name: String, foods: [RecognizedFood], image: UIImage?) {
        print("\n===== HANDLING MULTIPLE DETECTED FOODS =====")
        print("Creating combined dish '\(name)' with \(foods.count) ingredients")
        
        // Фильтруем продукты, оставляя только те, которые имеют данные от Edamam
        let foodsWithEdamamData = foods.filter { $0.nutritionData?.source == "edamam" }
        
        guard !foodsWithEdamamData.isEmpty else {
            print("⚠️ Не найдено подходящих продуктов с данными от Edamam API")
            print("===== MULTIPLE FOOD HANDLING FAILED =====\n")
            return
        }
        
        // 1. Сначала создаем основное блюдо
        let context = CoreDataManager.shared.context
        let mainDish = Food(context: context)
        mainDish.id = UUID()
        mainDish.name = name
        mainDish.createdAt = Date()
        mainDish.servingSize = 100
        mainDish.servingUnit = "г"
        
        // Важно: это явно НЕ ингредиент
        mainDish.isIngredient = false
        
        // 2. Рассчитываем общее пищевую ценность на основе ингредиентов
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var totalSugar: Double = 0
        var totalFiber: Double = 0
        var totalSodium: Double = 0
        
        // Массив для хранения созданных ингредиентов
        var createdIngredients: [Food] = []
        
        // 3. Создаем ингредиенты и добавляем их к блюду
        for foodItem in foodsWithEdamamData {
            guard let nutritionData = foodItem.nutritionData else { continue }
            
            // 3.1 Добавляем питательные вещества к общей сумме
            totalCalories += nutritionData.calories
            totalProtein += nutritionData.protein
            totalCarbs += nutritionData.carbs
            totalFat += nutritionData.fat
            if let sugar = nutritionData.sugar { totalSugar += sugar }
            if let fiber = nutritionData.fiber { totalFiber += fiber }
            if let sodium = nutritionData.sodium { totalSodium += sodium }
            
            // 3.2 Создаем ингредиент
            let ingredient = Food(context: context)
            ingredient.id = UUID()
            ingredient.name = foodItem.name
            ingredient.calories = nutritionData.calories
            ingredient.protein = nutritionData.protein
            ingredient.carbs = nutritionData.carbs
            ingredient.fat = nutritionData.fat
            ingredient.sugar = nutritionData.sugar ?? 0
            ingredient.fiber = nutritionData.fiber ?? 0
            ingredient.sodium = nutritionData.sodium ?? 0
            ingredient.createdAt = Date()
            ingredient.servingSize = 100
            ingredient.servingUnit = "г"
            
            // Важно: это явно ингредиент
            ingredient.isIngredient = true
            
            // Если у ингредиента есть изображение, сохраняем его
            if let originalImage = foodItem.originalImage {
                ingredient.imageData = processImageForStorage(image: originalImage)
            }
            
            // 3.3 Создаем связь между блюдом и ингредиентом
            let ingredientEntity = Ingredient(context: context)
            ingredientEntity.id = UUID()
            ingredientEntity.name = foodItem.name
            ingredientEntity.calories = nutritionData.calories
            ingredientEntity.protein = nutritionData.protein
            ingredientEntity.carbs = nutritionData.carbs
            ingredientEntity.fat = nutritionData.fat
            ingredientEntity.amount = 1.0
            ingredientEntity.unit = "порция"
            ingredientEntity.food = ingredient
            
            // 3.4 Добавляем ингредиент к основному блюду
            mainDish.addToIngredients(ingredientEntity)
            
            // Добавляем в список созданных ингредиентов
            createdIngredients.append(ingredient)
            
            // 3.5 Сохраняем информацию в UserDefaults для правильного отслеживания
            if let id = ingredient.id?.uuidString {
                UserDefaults.standard.set(true, forKey: "food_ingredient_\(id)")
                UserDefaults.standard.set(false, forKey: "single_food_\(id)")
            }
        }
        
        // 4. Устанавливаем итоговую пищевую ценность для основного блюда
        mainDish.calories = totalCalories
        mainDish.protein = totalProtein
        mainDish.carbs = totalCarbs
        mainDish.fat = totalFat
        mainDish.sugar = totalSugar
        mainDish.fiber = totalFiber
        mainDish.sodium = totalSodium
        
        // 5. Сохраняем изображение блюда
        if let originalImage = image ?? foodsWithEdamamData.first?.originalImage {
            mainDish.imageData = processImageForStorage(image: originalImage)
        }
        
        // 6. Сохраняем в CoreData
        do {
            try context.save()
            print("✅ Successfully saved combined dish '\(name)' with \(createdIngredients.count) ingredients")
            
            // 7. Отмечаем блюдо как НЕ ингредиент в UserDefaults
            if let id = mainDish.id?.uuidString {
                UserDefaults.standard.set(false, forKey: "food_ingredient_\(id)")
                UserDefaults.standard.set(true, forKey: "single_food_\(id)")
                UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
            }
            
            // 8. Добавляем в Recently Logged
            CoreDataManager.shared.saveFoodItem(food: mainDish)
            
            // 9. Устанавливаем как последний отсканированный продукт
            NavigationCoordinator.shared.recentlyScannedFood = mainDish
            
            // 10. Удаляем отдельные ингредиенты из истории
            ensureIngredientsRemovedFromHistory(ingredients: createdIngredients)
            
            // 11. Уведомляем UI о необходимости обновления
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            
            print("===== MULTIPLE FOOD HANDLING COMPLETED =====\n")
        } catch {
            print("❌ Error saving combined dish to CoreData: \(error)")
            print("===== MULTIPLE FOOD HANDLING FAILED =====\n")
        }
    }
    
    // Метод для удаления ингредиентов из истории еды
    private func clearIngredientsFromHistory(ingredientNames: [String]) {
        guard var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] else {
            return
        }
        
        let initialCount = foodHistory.count
        print("FoodRecognitionManager: Очистка ингредиентов из истории еды (до: \(initialCount) записей)")
        
        // Удаляем все записи, имя которых совпадает с именами ингредиентов
        foodHistory.removeAll { item in
            if let name = item["name"] as? String {
                let found = ingredientNames.contains { $0.lowercased() == name.lowercased() }
                if found {
                    print("FoodRecognitionManager: Удаляем ингредиент '\(name)' из истории еды")
                }
                return found
            }
            return false
        }
        
        if initialCount != foodHistory.count {
            UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
            UserDefaults.standard.synchronize()
            print("FoodRecognitionManager: История еды обновлена (после: \(foodHistory.count) записей)")
        }
    }
    
    // Метод для гарантированного удаления ингредиентов из истории после создания комбинированного блюда
    private func ensureIngredientsRemovedFromHistory(ingredients: [Food]) {
        guard var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] else {
            return
        }
        
        let initialCount = foodHistory.count
        print("FoodRecognitionManager: Проверка на удаление ингредиентов из истории (до: \(initialCount) записей)")
        
        var historyChanged = false
        
        // Удаляем ингредиенты по ID и имени
        for ingredient in ingredients {
            if let id = ingredient.id?.uuidString {
                let countBefore = foodHistory.count
                foodHistory.removeAll { item in
                    if let itemId = item["id"] as? String, itemId == id {
                        print("FoodRecognitionManager: Удаляем ингредиент по ID '\(id)' из истории еды")
                        return true
                    }
                    return false
                }
                if countBefore != foodHistory.count {
                    historyChanged = true
                }
            }
            
            if let name = ingredient.name {
                let countBefore = foodHistory.count
                foodHistory.removeAll { item in
                    if let itemName = item["name"] as? String, itemName.lowercased() == name.lowercased() {
                        print("FoodRecognitionManager: Удаляем ингредиент по имени '\(name)' из истории еды")
                        return true
                    }
                    return false
                }
                if countBefore != foodHistory.count {
                    historyChanged = true
                }
            }
        }
        
        if historyChanged {
            UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
            UserDefaults.standard.synchronize()
            print("FoodRecognitionManager: История еды обновлена после проверки (после: \(foodHistory.count) записей)")
            
            // Уведомляем UI об обновлении
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
        }
    }
    
    // Method to create an individual food item from a recognized food
    func createIndividualFoodItem(recognizedFood: RecognizedFood, image: UIImage?) {
        saveFoodToCoreData(food: recognizedFood, image: image)
    }
}

// MARK: - Response Models

// Модели для ответа Gemini
struct FoodRecognitionGeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Codable {
    let text: String?
}

// Модель для элемента продукта в ответе Gemini
struct GeminiFoodItem: Codable {
    let name: String
    let confidence: Double?
}

// Модели для ответа Edamam
struct EdamamResponse: Codable {
    let calories: Double
    let totalNutrients: EdamamNutrients
}

struct EdamamNutrients: Codable {
    let PROCNT: EdamamNutrient? // Protein
    let FAT: EdamamNutrient? // Fat
    let CHOCDF: EdamamNutrient? // Carbohydrates
    let SUGAR: EdamamNutrient? // Sugar
    let FIBTG: EdamamNutrient? // Fiber
    let NA: EdamamNutrient? // Sodium
}

struct EdamamNutrient: Codable {
    let quantity: Double
    let unit: String
}






