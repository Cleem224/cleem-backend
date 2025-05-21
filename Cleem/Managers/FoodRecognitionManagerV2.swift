import Foundation
import UIKit
import Combine
import CoreData
import Vision

/// Обновленный менеджер распознавания еды с использованием нового пайплайна:
/// 1. Gemini для визуального распознавания блюда
/// 2. GPT-4 для декомпозиции на ингредиенты
/// 3. Spoonacular для получения данных о нутриентах
/// 4. Суммирование результатов
class FoodRecognitionManagerV2: ObservableObject {
    // MARK: - Properties
    
    // API ключи
    private var geminiApiKey: String
    
    // Состояние
    @Published var isProcessing: Bool = false
    @Published var recognizedFoods: [RecognizedFoodV2] = []
    @Published var errorMessage: String?
    
    // Сервисы
    private let openAIService: OpenAIService
    private let spoonacularService: SpoonacularService
    
    // Ключи Edamam API
    private var edamamAppId: String
    private var edamamAppKey: String
    
    // URL сессия для сетевых запросов
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // Структуры для работы с Gemini API
    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        
        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }
        
        struct Content: Decodable {
            let parts: [Part]?
            let role: String?
        }
        
        struct Part: Decodable {
            let text: String?
        }
    }
    
    // Структуры для работы с Edamam API
    private struct EdamamResponse: Decodable {
        let calories: Double
        let totalWeight: Double
        let dietLabels: [String]
        let healthLabels: [String]
        let cautions: [String]
        let totalNutrients: Nutrients
        let totalDaily: Nutrients
        
        struct Nutrients: Decodable {
            let ENERC_KCAL: NutrientInfo?
            let PROCNT: NutrientInfo?  // Белки
            let FAT: NutrientInfo?     // Жиры
            let CHOCDF: NutrientInfo?  // Углеводы
            let FIBTG: NutrientInfo?   // Клетчатка
            let SUGAR: NutrientInfo?   // Сахар
            let NA: NutrientInfo?      // Натрий
            let CA: NutrientInfo?      // Кальций
            let CHOLE: NutrientInfo?   // Холестерин
        }
        
        struct NutrientInfo: Decodable {
            let label: String
            let quantity: Double
            let unit: String
        }
    }
    
    // Кэш переводов для оптимизации запросов
    private var translationCache: [String: String] = [:]
    
    // MARK: - Initialization
    
    init(geminiApiKey: String, edamamAppId: String, edamamAppKey: String) {
        self.geminiApiKey = geminiApiKey
        self.edamamAppId = edamamAppId
        self.edamamAppKey = edamamAppKey
        
        // Инициализация сервисов
        self.openAIService = OpenAIService.shared
        self.spoonacularService = SpoonacularService.shared
        
        // Конфигурация сессии
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // Удобный инициализатор, который берет ключи из UserDefaults
    convenience init() {
        // Сначала установим ключи API
        FoodRecognitionManagerV2.initializeApiKeys()
        
        // Теперь берем ключи из UserDefaults
        let geminiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let edamamId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let edamamKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        self.init(geminiApiKey: geminiKey, edamamAppId: edamamId, edamamAppKey: edamamKey)
        
        // Логирование для отладки
        print("🔑 FoodRecognitionManagerV2 инициализирован с ключами:")
        print("   Gemini API: \(geminiKey.prefix(10))...")
        print("   Edamam API: ID=\(edamamId), Key=\(edamamKey.prefix(10))...")
    }
    
    // Статический метод для принудительной инициализации API ключей
    static func initializeApiKeys() {
        // Обновленные ключи для работы с API
        let defaultGeminiKey = "YOUR_GEMINI_API_KEY"
        let defaultSpoonacularKey = "YOUR_SPOONACULAR_KEY"
        let defaultOpenAIKey = "YOUR_OPENAI_API_KEY"
        let defaultEdamamAppId = "YOUR_EDAMAM_APP_ID"
        let defaultEdamamAppKey = "YOUR_EDAMAM_APP_KEY"
        let defaultGoogleTranslateKey = "YOUR_GOOGLE_TRANSLATE_KEY"
        
        // Устанавливаем ключи в UserDefaults
        UserDefaults.standard.set(defaultGeminiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(defaultSpoonacularKey, forKey: "spoonacular_api_key")
        UserDefaults.standard.set(defaultOpenAIKey, forKey: "openai_api_key")
        UserDefaults.standard.set(defaultEdamamAppId, forKey: "edamam_app_id")
        UserDefaults.standard.set(defaultEdamamAppKey, forKey: "edamam_app_key")
        UserDefaults.standard.set(defaultGoogleTranslateKey, forKey: "google_translate_api_key")
        
        // Принудительная синхронизация
        UserDefaults.standard.synchronize()
        
        print("🔄 API ключи принудительно инициализированы")
    }
    
    // Метод для установки дефолтных API-ключей
    func setDefaultApiKeys() {
        // Используем статический метод для установки ключей в UserDefaults
        FoodRecognitionManagerV2.initializeApiKeys()
        
        // Получаем обновленные ключи из UserDefaults
        let newGeminiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        let newEdamamAppId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let newEdamamAppKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        // Напрямую обновляем ключи в текущем экземпляре
        self.geminiApiKey = newGeminiKey
        self.edamamAppId = newEdamamAppId
        self.edamamAppKey = newEdamamAppKey
        
        print("✅ API ключи обновлены в экземпляре FoodRecognitionManagerV2")
    }
    
    // MARK: - Main Methods
    
    /// Основной метод для распознавания пищи по изображению (новый пайплайн)
    func recognizeFood(from image: UIImage) -> AnyPublisher<[RecognizedFoodV2], FoodRecognitionError> {
        self.isProcessing = true
        self.errorMessage = nil
        
        print("🍏 Starting food recognition with new pipeline")
        
        // 1. Распознаем блюдо с помощью Gemini
        return detectDishWithGemini(image: image)
            .catch { error -> AnyPublisher<String, FoodRecognitionError> in
                // Check if it's a 503 error (service unavailable)
                if error.localizedDescription.contains("503") || 
                   error.localizedDescription.contains("overloaded") {
                    print("⚠️ Gemini API unavailable (503 error), falling back to Vision framework")
                    self.errorMessage = "Cloud API overloaded. Using on-device recognition instead."
                    // Fallback to on-device Vision framework
                    return self.detectDishWithVision(image: image)
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .flatMap { dishName -> AnyPublisher<(String, [String]), FoodRecognitionError> in
                print("✅ Step 1: Dish recognized as \(dishName)")
                
                // 2. Разбиваем блюдо на ингредиенты с помощью GPT-4
                return self.decomposeWithGPT4(dishName: dishName, image: image)
                    .map { ingredients -> (String, [String]) in
                        // Check if ingredients array is not empty
                        if ingredients.isEmpty {
                            print("⚠️ Warning: Empty ingredients array, using dish name as single ingredient")
                            return (dishName, [dishName])
                        }
                        return (dishName, ingredients)
                    }
                    .mapError { error -> FoodRecognitionError in
                        print("❌ Error decomposing dish: \(error)")
                        // Fall back to using the dish name as a single ingredient
                        return .decompositionFailed(error.localizedDescription)
                    }
                    .catch { error -> AnyPublisher<(String, [String]), FoodRecognitionError> in
                        // Fallback to using the dish name as a single ingredient if decomposition fails
                        print("⚠️ Decomposition failed, using dish name as single ingredient")
                        return Just((dishName, [dishName]))
                            .setFailureType(to: FoodRecognitionError.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { (dishName, ingredients) -> AnyPublisher<[RecognizedFoodV2], FoodRecognitionError> in
                print("✅ Step 2: Dish decomposed into ingredients: \(ingredients.joined(separator: ", "))")
                
                // 3. Получаем информацию о нутриентах из Edamam для каждого ингредиента
                return self.getNutritionDataFromEdamam(dishName: dishName, ingredients: ingredients, image: image)
            }
            .handleEvents(receiveOutput: { [weak self] foods in
                self?.recognizedFoods = foods
                self?.isProcessing = false
                
                // Validate that we have foods with nutrition data
                if foods.isEmpty {
                    print("⚠️ Warning: No recognized foods returned")
                    self?.errorMessage = "No recognized foods returned"
                    return
                }
                
                // Check if nutrition data is valid
                let validFoods = foods.filter { $0.nutritionData?.calories ?? 0 > 0 }
                if validFoods.isEmpty {
                    print("⚠️ Warning: No foods with valid nutrition data")
                    self?.errorMessage = "No foods with valid nutrition data"
                    return
                }
                
                // Сохраняем все распознанные продукты в CoreData
                for food in foods {
                    self?.saveFoodToCoreData(food: food, image: food.originalImage)
                }
            }, receiveCompletion: { [weak self] completion in
                self?.isProcessing = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    print("❌ Food recognition pipeline failed: \(error.localizedDescription)")
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Step 1: Gemini Vision API
    
    /// Распознавание блюда с помощью Gemini API
    private func detectDishWithGemini(image: UIImage) -> AnyPublisher<String, FoodRecognitionError> {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
        let queryItems = [URLQueryItem(name: "key", value: geminiApiKey)]
        
        var urlComponents = URLComponents(string: endpoint)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            return Fail(error: FoodRecognitionError.networkError("Неверный URL")).eraseToAnyPublisher()
        }
        
        // Получаем данные изображения в формате base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: FoodRecognitionError.imageProcessingError("Ошибка преобразования изображения")).eraseToAnyPublisher()
        }
        
        // Изменяем размер изображения, если оно слишком большое
        let resizedImage = resizeImageIfNeeded(image, maxWidth: 768, maxHeight: 768)
        guard let resizedImageData = resizedImage.jpegData(compressionQuality: 0.8) else {
            return Fail(error: FoodRecognitionError.imageProcessingError("Ошибка сжатия изображения")).eraseToAnyPublisher()
        }
        
        let base64Image = resizedImageData.base64EncodedString()
        
        // Создаем запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Формируем тело запроса в соответствии с API Gemini
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Identify the food dish shown in this image. Give only a simple general name of the dish in English, without explanations. For example: 'Beef Pilaf', 'Pasta Carbonara', 'Chicken Caesar Salad'."],
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
                "temperature": 0.2,
                "topK": 32,
                "topP": 0.95,
                "maxOutputTokens": 100,
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: FoodRecognitionError.networkError("Ошибка создания запроса: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        print("🌐 Отправка запроса к Gemini Vision API:")
        print("   URL: \(url)")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw FoodRecognitionError.networkError("Недопустимый ответ")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    if let errorResponseString = String(data: data, encoding: .utf8) {
                        print("Ошибка Gemini API: \(errorResponseString)")
                    }
                    throw FoodRecognitionError.networkError("Ошибка HTTP: \(httpResponse.statusCode)")
                }
                
                return data
            }
            .decode(type: GeminiResponse.self, decoder: JSONDecoder())
            .tryMap { (response: GeminiResponse) -> String in
                // Обработка текстового ответа от Gemini
                guard let candidate = response.candidates?.first,
                      let content = candidate.content,
                      let part = content.parts?.first,
                      let text = part.text else {
                    throw FoodRecognitionError.invalidResponse
                }
                
                // Очищаем ответ от кавычек и лишних пробелов
                let cleanedText = text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                
                // Проверка на отсутствие еды в ответе
                let noFoodPhrases = ["no food", "can't identify", "no dish", "unable to determine", "not a food"]
                for phrase in noFoodPhrases {
                    if cleanedText.lowercased().contains(phrase.lowercased()) {
                        throw FoodRecognitionError.recognitionFailed("No food detected in the image")
                    }
                }
                
                return cleanedText
            }
            .mapError { error -> FoodRecognitionError in
                if let recognitionError = error as? FoodRecognitionError {
                    return recognitionError
                }
                return .recognitionFailed("Ошибка распознавания: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Step 2: GPT-4 Decomposition
    
    /// Декомпозиция блюда на ингредиенты с помощью GPT-4
    private func decomposeWithGPT4(dishName: String, image: UIImage? = nil) -> AnyPublisher<[String], FoodRecognitionError> {
        // Используем сервис OpenAI с поддержкой резервного варианта Gemini
        print("🍽️ Декомпозиция блюда: \(dishName) (через OpenAI/Gemini)")
        return openAIService.decomposeWithFallback(foodName: dishName)
            .mapError { error -> FoodRecognitionError in
                print("❌ Ошибка при декомпозиции блюда: \(error.localizedDescription)")
                return .decompositionFailed("Ошибка при декомпозиции блюда: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Step 3: Edamam Nutrition Data
    
    /// Получение данных о питательной ценности ингредиентов с помощью Edamam API
    private func getNutritionDataFromEdamam(dishName: String, ingredients: [String], image: UIImage?) -> AnyPublisher<[RecognizedFoodV2], FoodRecognitionError> {
        print("🌐 Sending requests to Edamam API for nutrient analysis")
        
        // Create publishers for each ingredient
        let requests = ingredients.map { ingredient -> AnyPublisher<RecognizedFoodV2, Error> in
            return self.getNutritionDataForSingleIngredient(ingredient)
                .map { nutritionData -> RecognizedFoodV2 in
                    // Verify we got valid nutrition data
                    if nutritionData.calories <= 0 && nutritionData.protein <= 0 && nutritionData.carbs <= 0 && nutritionData.fat <= 0 {
                        print("⚠️ Warning: Received zero values for all nutrients for \(ingredient), using fallback values")
                        // Create fallback nutrition data with reasonable values
                        let fallbackNutrition = NutritionDataV2(
                            calories: 100,
                            protein: 5,
                            fat: 5,
                            carbs: 15,
                            sugar: 2,
                            fiber: 1,
                            sodium: 10,
                            source: "edamam_fallback",
                            foodLabel: ingredient,
                            cholesterol: 0,
                            servingSize: 100,
                            servingUnit: "g"
                        )
                        
                        return RecognizedFoodV2(
                            name: ingredient,
                            confidence: 1.0,
                            nutritionData: fallbackNutrition,
                            originalImage: image
                        )
                    }
                    
                    return RecognizedFoodV2(
                        name: ingredient,
                        confidence: 1.0,
                        nutritionData: nutritionData,
                        originalImage: image
                    )
                }
                .catch { error -> AnyPublisher<RecognizedFoodV2, Error> in
                    // Create fallback values on error with a distinct source
                    print("⚠️ Error getting nutrition data for \(ingredient): \(error)")
                    let defaultNutrition = NutritionDataV2(
                        calories: 100,
                        protein: 5,
                        fat: 5,
                        carbs: 15,
                        sugar: 2,
                        fiber: 1,
                        sodium: 10,
                        source: "edamam_error_fallback",
                        foodLabel: ingredient,
                        cholesterol: 0,
                        servingSize: 100,
                        servingUnit: "g"
                    )
                    
                    let foodWithDefaultValues = RecognizedFoodV2(
                        name: ingredient,
                        confidence: 1.0,
                        nutritionData: defaultNutrition,
                        originalImage: image
                    )
                    
                    return Just(foodWithDefaultValues).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
        }
        
        // Объединяем все запросы в один издатель
        return Publishers.MergeMany(requests)
            .collect()
            .map { recognizedFoods -> [RecognizedFoodV2] in
                // Calculate combined dish nutritional data
                let totalCalories = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.calories ?? 0) }
                let totalProtein = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.protein ?? 0) }
                let totalFat = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.fat ?? 0) }
                let totalCarbs = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.carbs ?? 0) }
                let totalSugar = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.sugar ?? 0) }
                let totalFiber = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.fiber ?? 0) }
                let totalSodium = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.sodium ?? 0) }
                let totalCholesterol = recognizedFoods.reduce(0) { $0 + ($1.nutritionData?.cholesterol ?? 0) }
                
                // Create combined nutrition data
                let combinedNutritionData = NutritionDataV2(
                    calories: totalCalories,
                    protein: totalProtein,
                    fat: totalFat,
                    carbs: totalCarbs,
                    sugar: totalSugar,
                    fiber: totalFiber,
                    sodium: totalSodium,
                    source: "edamam_combined",
                    foodLabel: dishName,
                    cholesterol: totalCholesterol,
                    servingSize: 100.0,
                    servingUnit: "g"
                )
                
                // Create combined dish with ingredients
                let combinedFood = RecognizedFoodV2(
                    name: dishName,
                    confidence: 1.0,
                    nutritionData: combinedNutritionData,
                    originalImage: image,
                    ingredients: ingredients
                )
                
                // Return only the combined dish by default
                var result = [combinedFood]
                
                // Add individual ingredients
                result.append(contentsOf: recognizedFoods)
                
                return result
            }
            .mapError { error -> FoodRecognitionError in
                return .nutritionAnalysisFailed("Ошибка анализа питательных веществ: \(error.localizedDescription)")
            }
            .eraseToAnyPublisher()
    }
    
    /// Получение данных о питательной ценности для одного ингредиента через Edamam API
    private func getNutritionDataForSingleIngredient(_ foodName: String) -> AnyPublisher<NutritionDataV2, Error> {
        // Убедитесь, что у нас есть API ключи
        guard !edamamAppId.isEmpty, !edamamAppKey.isEmpty else {
            print("⚠️ ОШИБКА: Отсутствуют API ключи Edamam для анализа нутриентов")
            return Fail(error: FoodRecognitionError.nutritionAnalysisFailed("Отсутствуют API ключи Edamam")).eraseToAnyPublisher()
        }
        
        // Skip translation since ingredients are already in English
        let englishFoodName = foodName
        print("🍽️ Using direct English name: \(englishFoodName)")
        
        // Подготовка URL
        let urlString = "https://api.edamam.com/api/nutrition-data"
        guard var urlComponents = URLComponents(string: urlString) else {
            return Fail(error: FoodRecognitionError.networkError("Недопустимый URL")).eraseToAnyPublisher()
        }
        
        // Добавляем параметры запроса с английским названием
        urlComponents.queryItems = [
            URLQueryItem(name: "app_id", value: edamamAppId),
            URLQueryItem(name: "app_key", value: edamamAppKey),
            URLQueryItem(name: "ingr", value: "100g \(englishFoodName)")
        ]
        
        guard let url = urlComponents.url else {
            return Fail(error: FoodRecognitionError.networkError("Не удалось создать URL")).eraseToAnyPublisher()
        }
        
        print("🌐 Запрос к Edamam: \(url.absoluteString)")
        
        // Выполняем запрос
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: EdamamResponse.self, decoder: JSONDecoder())
            .map { response -> NutritionDataV2 in
                // Преобразуем данные в модель NutritionDataV2
                return NutritionDataV2(
                    calories: response.calories,
                    protein: response.totalNutrients.PROCNT?.quantity ?? 0,
                    fat: response.totalNutrients.FAT?.quantity ?? 0,
                    carbs: response.totalNutrients.CHOCDF?.quantity ?? 0,
                    sugar: response.totalNutrients.SUGAR?.quantity,
                    fiber: response.totalNutrients.FIBTG?.quantity,
                    sodium: response.totalNutrients.NA?.quantity,
                    source: "edamam",
                    foodLabel: foodName,
                    cholesterol: response.totalNutrients.CHOLE?.quantity,
                    servingSize: 100,
                    servingUnit: "g"
                )
            }
            .catch { error -> AnyPublisher<NutritionDataV2, Error> in
                print("⚠️ Ошибка обработки данных от Edamam: \(error)")
                
                // В случае ошибки создаем заглушку с нулевыми данными
                let fallbackData = NutritionDataV2(
                    calories: 0,
                    protein: 0,
                    fat: 0,
                    carbs: 0,
                    sugar: nil,
                    fiber: nil,
                    sodium: nil,
                    source: "edamam_fallback",
                    foodLabel: foodName,
                    cholesterol: nil,
                    servingSize: 100,
                    servingUnit: "g"
                )
                
                return Just(fallbackData)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Метод для перевода названий продуктов с русского на английский
    private func translateFoodNameToEnglish(_ russianName: String) -> String {
        // Проверяем, не пустая ли строка
        guard !russianName.isEmpty else {
            return russianName
        }
        
        // Проверяем кэш, возможно перевод уже есть
        let lowercaseRussianName = russianName.lowercased()
        if let cachedTranslation = translationCache[lowercaseRussianName] {
            print("🔄 Перевод из кэша: '\(russianName)' -> '\(cachedTranslation)'")
            return cachedTranslation
        }
        
        // Базовый URL для Google Translate API
        let urlString = "https://translation.googleapis.com/language/translate/v2"
        guard var urlComponents = URLComponents(string: urlString) else {
            print("⚠️ Неверный URL для API перевода")
            return russianName
        }
        
        // Получаем API ключ из UserDefaults или используем дефолтный
        let apiKey = UserDefaults.standard.string(forKey: "google_translate_api_key") ?? "AIzaSyBKaHxMvfr2PJ4T5_sJNGd9pc9PfOXaURs"
        
        // Добавляем параметры запроса
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: russianName),
            URLQueryItem(name: "source", value: "ru"),
            URLQueryItem(name: "target", value: "en")
        ]
        
        guard let url = urlComponents.url else {
            print("⚠️ Не удалось создать URL с параметрами для перевода")
            return russianName
        }
        
        print("🌐 Запрос на перевод: \(russianName)")
        
        // Создаем запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Создаем семафор для синхронного запроса
        let semaphore = DispatchSemaphore(value: 0)
        
        // Переменные для результата
        var translatedText = russianName
        
        // Выполняем запрос
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data, error == nil else {
                print("⚠️ Ошибка при запросе перевода: \(error?.localizedDescription ?? "неизвестная ошибка")")
                return
            }
            
            // Пытаемся десериализовать JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObject = json["data"] as? [String: Any],
                   let translations = dataObject["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translation = firstTranslation["translatedText"] as? String {
                    translatedText = translation
                    print("🔄 Перевод: '\(russianName)' -> '\(translation)'")
                    
                    // Добавляем перевод в кэш
                    self.translationCache[lowercaseRussianName] = translation
                } else {
                    print("⚠️ Неожиданный формат ответа от API перевода")
                }
            } catch {
                print("⚠️ Ошибка парсинга JSON: \(error)")
            }
        }
        
        // Запускаем задачу
        task.resume()
        
        // Ждем выполнения запроса
        _ = semaphore.wait(timeout: .now() + 5)
        
        return translatedText
    }
    
    // MARK: - CoreData Integration
    
    /// Сохраняет распознанную еду в CoreData
    func saveFoodToCoreData(food: RecognizedFoodV2, image: UIImage?) {
        // Создаем объект Food
        let context = CoreDataManager.shared.context
        
        // Skip translation since food is already in English
        let englishName = food.name
        print("🍽️ Saving food with English name: \(englishName)")
        
        // Создаем экземпляр Food
        let foodEntity = Food(context: context)
        foodEntity.id = UUID()
        foodEntity.name = englishName // Используем английское имя напрямую
        foodEntity.createdAt = Date()
        // Устанавливаем обязательные поля
        foodEntity.isFavorite = false  // Устанавливаем дефолтное значение
        foodEntity.isIngredient = false  // Это не ингредиент
        
        // Устанавливаем питательную ценность, если доступна
        if let nutrition = food.nutritionData {
            foodEntity.calories = nutrition.calories
            foodEntity.protein = nutrition.protein
            foodEntity.fat = nutrition.fat
            foodEntity.carbs = nutrition.carbs
            foodEntity.sugar = nutrition.sugar ?? 0
            foodEntity.fiber = nutrition.fiber ?? 0
            foodEntity.sodium = nutrition.sodium ?? 0
            foodEntity.cholesterol = nutrition.cholesterol ?? 0
        }
        
        // Устанавливаем размер порции
        foodEntity.servingSize = 100
        foodEntity.servingUnit = "g"
        
        // Проверка и обработка изображения
        if let originalImage = image {
            foodEntity.imageData = processImageForStorage(image: originalImage)
            print("📸 Image processed and attached to \(englishName)")
        }
        
        // Добавляем информацию об ингредиентах, если это составное блюдо
        if let ingredients = food.ingredients, !ingredients.isEmpty {
            print("🥗 Adding \(ingredients.count) ingredients to \(englishName)")
            
            for ingredientName in ingredients {
                let ingredient = Ingredient(context: context)
                ingredient.id = UUID()
                ingredient.name = ingredientName
                ingredient.createdAt = Date()
                ingredient.food = foodEntity
                
                // Set default nutritional values, all are required and cannot be nil
                ingredient.calories = 0
                ingredient.protein = 0
                ingredient.fat = 0
                ingredient.carbs = 0
                
                // По умолчанию устанавливаем количество как 1 порцию
                ingredient.amount = 1.0
                ingredient.unit = "g"
            }
            
            // Mark as a composed food
            foodEntity.isComposed = true
        }
        
        // Сохраняем в CoreData
        do {
            try context.save()
            print("✅ Food '\(englishName)' successfully saved to CoreData")
            
            // Сохраняем ID последней распознанной еды для возможности восстановления
            if let foodId = foodEntity.id?.uuidString {
                UserDefaults.standard.set(foodId, forKey: "lastScannedFoodID")
                
                // Также устанавливаем в NavigationCoordinator
                NavigationCoordinator.shared.lastScannedFoodID = foodId
                NavigationCoordinator.shared.recentlyScannedFood = foodEntity
                
                // Отправляем уведомление об обновлении пищи
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
        } catch {
            print("❌ Error saving food to CoreData: \(error)")
        }
    }
    
    /// Создает комбинированное блюдо из нескольких распознанных продуктов
    func createCombinedFoodFromRecognizedFoods(name: String, foods: [RecognizedFoodV2], image: UIImage?) {
        // Получаем контекст CoreData
        let context = CoreDataManager.shared.context
        
        // Skip translation since name is already in English
        let englishName = name
        print("🍽️ Creating combined food with English name: \(englishName)")
        
        // Создаем основное блюдо
        let combinedFood = Food(context: context)
        combinedFood.id = UUID()
        combinedFood.name = englishName // Используем английское имя напрямую
        combinedFood.createdAt = Date()
        combinedFood.isIngredient = false // Это не ингредиент
        combinedFood.isComposed = true // Mark as composed food
        
        // Вычисляем суммарную питательную ценность
        var totalCalories: Double = 0
        var totalProtein: Double = 0
        var totalFat: Double = 0
        var totalCarbs: Double = 0
        var totalSugar: Double = 0
        var totalFiber: Double = 0
        
        // Собираем ингредиенты и суммируем питательную ценность
        for food in foods {
            // Только если есть данные о питательной ценности
            if let nutrition = food.nutritionData {
                totalCalories += nutrition.calories
                totalProtein += nutrition.protein
                totalFat += nutrition.fat
                totalCarbs += nutrition.carbs
                totalSugar += nutrition.sugar ?? 0
                totalFiber += nutrition.fiber ?? 0
                
                // Skip translation since ingredient name is already in English
                let englishIngredientName = food.name
                
                // Создаем ингредиент
                let ingredient = Ingredient(context: context)
                ingredient.id = UUID()
                ingredient.name = englishIngredientName // Используем английское имя напрямую
                ingredient.calories = nutrition.calories
                ingredient.protein = nutrition.protein
                ingredient.fat = nutrition.fat
                ingredient.carbs = nutrition.carbs
                ingredient.amount = 1.0
                ingredient.unit = "g"
                ingredient.createdAt = Date()
                ingredient.food = combinedFood
            }
        }
        
        // Устанавливаем суммарную питательную ценность
        combinedFood.calories = totalCalories
        combinedFood.protein = totalProtein
        combinedFood.fat = totalFat
        combinedFood.carbs = totalCarbs
        combinedFood.sugar = totalSugar
        combinedFood.fiber = totalFiber
        
        // Сохраняем изображение, если оно есть
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            combinedFood.imageData = imageData
        }
        
        // Стандартный размер порции
        combinedFood.servingSize = 100
        combinedFood.servingUnit = "g"
        
        // Сохраняем в CoreData
        do {
            try context.save()
            print("✅ Combined food '\(englishName)' successfully saved to CoreData")
            
            // Сохраняем ID последней распознанной еды для возможности восстановления
            if let foodId = combinedFood.id?.uuidString {
                UserDefaults.standard.set(foodId, forKey: "lastScannedFoodID")
                
                // Также устанавливаем в NavigationCoordinator
                NavigationCoordinator.shared.lastScannedFoodID = foodId
                NavigationCoordinator.shared.recentlyScannedFood = combinedFood
            }
        } catch {
            print("❌ Error saving combined food to CoreData: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Обработка изображения для хранения
    private func processImageForStorage(image: UIImage) -> Data? {
        // Если изображение слишком большое, уменьшаем его
        let maxSize: CGFloat = 1024
        let resizedImage: UIImage
        
        if image.size.width > maxSize || image.size.height > maxSize {
            resizedImage = resizeImageIfNeeded(image, maxWidth: maxSize, maxHeight: maxSize)
        } else {
            resizedImage = image
        }
        
        // Конвертируем в JPEG с умеренным сжатием
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
    
    /// Изменение размера изображения, если необходимо
    private func resizeImageIfNeeded(_ image: UIImage, maxWidth: CGFloat, maxHeight: CGFloat) -> UIImage {
        let originalSize = image.size
        
        // Проверяем, нужно ли изменять размер
        if originalSize.width <= maxWidth && originalSize.height <= maxHeight {
            return image
        }
        
        // Вычисляем соотношение сторон
        let widthRatio = maxWidth / originalSize.width
        let heightRatio = maxHeight / originalSize.height
        
        // Используем наименьшее соотношение для сохранения пропорций
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Вычисляем новый размер
        let newWidth = originalSize.width * scaleFactor
        let newHeight = originalSize.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        // Изменяем размер изображения
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    /// Проверка валидности API ключа путем простого запроса к Gemini
    func checkApiKeyValidity() -> AnyPublisher<Bool, Error> {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
        let queryItems = [URLQueryItem(name: "key", value: geminiApiKey)]
        
        var urlComponents = URLComponents(string: endpoint)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            return Fail(error: FoodRecognitionError.networkError("Неверный URL")).eraseToAnyPublisher()
        }
        
        // Создаем простой запрос для проверки
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Простой текстовый запрос
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Привет"]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: FoodRecognitionError.networkError("Ошибка создания запроса: \(error.localizedDescription)")).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { (data, response) -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw FoodRecognitionError.networkError("Недопустимый ответ")
                }
                
                if 200...299 ~= httpResponse.statusCode {
                    return true // Ключ валиден
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Ошибка API: \(responseString)")
                    }
                    return false // Ключ не валиден
                }
            }
            .mapError { error -> Error in
                if let foodError = error as? FoodRecognitionError {
                    return foodError
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Fallback Recognition with Vision
    
    /// Fallback food recognition using Vision framework when Gemini API is unavailable
    private func detectDishWithVision(image: UIImage) -> AnyPublisher<String, FoodRecognitionError> {
        // Create a Deferred publisher to perform Vision request asynchronously
        return Deferred {
            Future<String, FoodRecognitionError> { promise in
                // Create a Vision request for classifying the image
                guard let cgImage = image.cgImage else {
                    promise(.failure(.imageProcessingError("Failed to get CGImage")))
                    return
                }
                
                // Use the built-in image classifier instead of requiring a specific model
                let request = VNClassifyImageRequest { request, error in
                    if let error = error {
                        promise(.failure(.recognitionFailed("Vision framework error: \(error.localizedDescription)")))
                        return
                    }
                    
                    // Process the results
                    guard let results = request.results as? [VNClassificationObservation],
                          !results.isEmpty else {
                        promise(.failure(.recognitionFailed("No classification results found")))
                        return
                    }
                    
                    // Extract food-related classifications
                    let foodClasses = results.prefix(10).filter { observation in
                        // Look for food-related terms
                        let identifier = observation.identifier.lowercased()
                        return identifier.contains("food") || 
                               identifier.contains("dish") || 
                               identifier.contains("meal") ||
                               identifier.contains("fruit") ||
                               identifier.contains("vegetable") ||
                               identifier.contains("meat") ||
                               identifier.contains("bread") ||
                               identifier.contains("rice") ||
                               identifier.contains("pasta") ||
                               identifier.contains("salad")
                    }
                    
                    if let bestFoodMatch = foodClasses.first {
                        print("📱 Vision identified food: \(bestFoodMatch.identifier) (confidence: \(bestFoodMatch.confidence))")
                        promise(.success(bestFoodMatch.identifier.capitalized))
                    } else if let topResult = results.first {
                        // Generic fallback
                        print("📱 Vision fallback (non-food): \(topResult.identifier) (confidence: \(topResult.confidence))")
                        // Provide a generic "Food" response
                        promise(.success("Food"))
                    } else {
                        // Ultimate fallback
                        promise(.success("Food Item"))
                    }
                }
                
                // Set the request properties
                request.revision = VNClassifyImageRequestRevision1
                
                // Create a handler and perform the request
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    promise(.failure(.recognitionFailed("Vision request failed: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Error Types

// Используется FoodRecognitionError из модели FoodRecognitionError.swift 