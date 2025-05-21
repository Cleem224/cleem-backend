import Foundation
import Combine
import UIKit
import CoreData

class FoodDatabaseService: ObservableObject {
    static let shared = FoodDatabaseService()
    
    @Published var recommendations: [RecommendedFoodItem] = []
    @Published var searchResults: [RecommendedFoodItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // API ключи для Edamam
    private let edamamAppId: String
    private let edamamAppKey: String
    
    // Базовый URL для Edamam Food Database API
    private let baseURL = "https://api.edamam.com/api/food-database/v2"
    
    // URL сессия
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Используем актуальные ключи API
        let defaultFoodDbId = "b8fc1835"
        let defaultFoodDbKey = "3e85e1b27b125c78a76a6605d6d526f0"
        
        // Устанавливаем ключи в UserDefaults, если они отсутствуют
        if UserDefaults.standard.string(forKey: "edamam_food_db_id") == nil {
            UserDefaults.standard.set(defaultFoodDbId, forKey: "edamam_food_db_id")
        }
        if UserDefaults.standard.string(forKey: "edamam_food_db_key") == nil {
            UserDefaults.standard.set(defaultFoodDbKey, forKey: "edamam_food_db_key")
        }
        
        // Получаем ключи из UserDefaults
        let appId = UserDefaults.standard.string(forKey: "edamam_food_db_id") ?? defaultFoodDbId
        let appKey = UserDefaults.standard.string(forKey: "edamam_food_db_key") ?? defaultFoodDbKey
        self.edamamAppId = appId
        self.edamamAppKey = appKey
        
        // Логируем для отладки
        print("🔑 FoodDatabaseService инициализирован с ключами:")
        print("   Food DB App ID: \(appId)")
        print("   Food DB App Key: \(appKey.prefix(10))...")
        
        // Настраиваем сессию с расширенным временем ожидания
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        // Завершение инициализации - теперь можно вызывать методы
        setupAfterInit()
    }
    
    // Метод для настройки после инициализации
    private func setupAfterInit() {
        // Настраиваем логгирование для отладки
        #if DEBUG
        CoreDataLogger.setup()
        #endif
        
        // Register for app termination notification to save the context
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveContextOnTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Register for app entering background notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveContextOnBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Проверка модели данных при инициализации - используем weak self
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.verifyDataModel()
        }
        
        // Загружаем рекомендации при инициализации
        loadRecommendations()
    }
    
    // MARK: - Публичные методы API
    
    // Загрузка рекомендаций
    func loadRecommendations() {
        isLoading = true
        errorMessage = nil
        
        // Список популярных продуктов для рекомендаций
        let popularFoods = ["apple", "banana", "chicken", "egg", "yogurt", "salmon", "rice", "avocado", "spinach", "oatmeal"]
        
        // Создаем группу для параллельных запросов
        let group = DispatchGroup()
        var tempRecommendations: [RecommendedFoodItem] = []
        
        // Делаем запросы для каждого популярного продукта
        for food in popularFoods {
            group.enter()
            
            fetchFoodInfo(query: food) { [weak self] result in
                defer { group.leave() }
                
                switch result {
                case .success(let items):
                    if let item = items.first {
                        tempRecommendations.append(item)
                    }
                case .failure(let error):
                    print("Error fetching recommendation for \(food): \(error)")
                }
            }
        }
        
        // После завершения всех запросов
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if tempRecommendations.isEmpty {
                // Если запросы не удались, используем демо-данные
                self.recommendations = RecommendedFoodItem.sampleRecommendations
                self.errorMessage = "Не удалось загрузить рекомендации из API. Используются демо-данные."
            } else {
                self.recommendations = tempRecommendations
            }
            
            self.isLoading = false
        }
    }
    
    // Поиск продуктов по запросу
    func searchFoods(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        fetchFoodInfo(query: query) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self.searchResults = items
                case .failure(let error):
                    print("Error searching foods: \(error)")
                    self.errorMessage = "Ошибка поиска: \(error.localizedDescription)"
                    // Используем локальный фильтр как запасной вариант
                    self.searchResults = RecommendedFoodItem.sampleRecommendations.filter {
                        $0.name.lowercased().contains(query.lowercased())
                    }
                }
                
                self.isLoading = false
            }
        }
    }
    
    // Добавление продукта в Recent Logged
    func addFoodToRecentlyLogged(food: RecommendedFoodItem) {
        print("\n===== ДОБАВЛЕНИЕ ПРОДУКТА В RECENTLY LOGGED =====")
        // Преобразуем в FoodItem
        let foodItem = food.toFoodItem()
        let nutrition = food.toFoodNutrition()
        
        // Сначала проверяем, существует ли продукт с таким именем
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", foodItem.name)
        
        do {
            let existingFoods = try context.fetch(fetchRequest)
            
            if let existingFood = existingFoods.first {
                print("⚠️ Продукт с именем '\(foodItem.name)' уже существует в базе данных. Обновляем существующую запись.")
                
                // Обновляем данные существующего продукта
                existingFood.calories = nutrition.calories
                existingFood.protein = nutrition.protein
                existingFood.carbs = nutrition.carbs
                existingFood.fat = nutrition.fat
                existingFood.servingSize = Double(nutrition.servingSize)
                existingFood.servingUnit = nutrition.servingUnit
                existingFood.createdAt = Date() // Обновляем время для сортировки
                existingFood.isIngredient = false
                
                // Обновляем изображение, если оно есть
                if let image = food.image {
                    existingFood.imageData = image.jpegData(compressionQuality: 0.8)
                }
                
                // Сохраняем изменения
                try context.save()
                print("✅ Обновлен существующий продукт \(foodItem.name) в CoreData")
                
                // Обеспечиваем правильную видимость в Recently Logged
                CoreDataManager.shared.saveFoodItem(food: existingFood)
                
                // Устанавливаем этот продукт как последний отсканированный
                NavigationCoordinator.shared.recentlyScannedFood = existingFood
                
                print("===== ОБНОВЛЕНИЕ ПРОДУКТА ЗАВЕРШЕНО =====\n")
                return
            }
        } catch {
            print("❌ Ошибка при проверке существующих продуктов: \(error)")
        }
        
        // Создаем новый объект CoreData, если продукт не существует
        let newFood = Food(context: context)
        
        // Заполняем данные
        newFood.id = UUID(uuidString: foodItem.id) ?? UUID()
        newFood.name = foodItem.name
        newFood.calories = nutrition.calories
        newFood.protein = nutrition.protein
        newFood.carbs = nutrition.carbs
        newFood.fat = nutrition.fat
        newFood.servingSize = Double(nutrition.servingSize)
        newFood.servingUnit = nutrition.servingUnit
        newFood.createdAt = Date()
        
        // Важно: явно отмечаем, что это не ингредиент
        newFood.isIngredient = false
        
        // Обрабатываем изображение
        if let image = food.image {
            newFood.imageData = image.jpegData(compressionQuality: 0.8)
        }
        
        // Сохраняем в CoreData с использованием улучшенного метода CoreDataManager
        do {
            try context.save()
            print("✅ Сохранен новый продукт \(food.name) в CoreData")
            
            // Используем CoreDataManager для надежного сохранения в UserDefaults
            CoreDataManager.shared.saveFoodItem(food: newFood)
            
            // Устанавливаем этот продукт как последний отсканированный
            NavigationCoordinator.shared.recentlyScannedFood = newFood
        } catch {
            print("❌ Ошибка сохранения продукта в CoreData: \(error)")
        }
        
        // Добавляем анимированное уведомление и вибрацию при добавлении
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        // Отправляем уведомление об обновлении Recently Logged
        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        
        print("===== ДОБАВЛЕНИЕ ПРОДУКТА ЗАВЕРШЕНО =====\n")
    }
    
    // Вспомогательный метод для сохранения продукта в UserDefaults
    // Не используется напрямую - вместо этого используется CoreDataManager.saveFoodItem
    private func saveFoodToUserDefaults(_ food: Food) {
        guard let id = food.id?.uuidString, let name = food.name else { return }
        
        // Этот метод не используется напрямую, но оставлен для совместимости
        CoreDataManager.shared.saveFoodItem(food: food)
    }
    
    // MARK: - Приватные методы
    
    // Получение информации о продукте из Edamam API
    private func fetchFoodInfo(query: String, completion: @escaping (Result<[RecommendedFoodItem], Error>) -> Void) {
        // Формируем запрос к API
        let endpoint = "/parser"
        let queryItems = [
            URLQueryItem(name: "app_id", value: edamamAppId),
            URLQueryItem(name: "app_key", value: edamamAppKey),
            URLQueryItem(name: "ingr", value: query),
            URLQueryItem(name: "nutrition-type", value: "logging")
        ]
        
        var urlComponents = URLComponents(string: baseURL + endpoint)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            completion(.failure(NSError(domain: "FoodDatabaseService", code: 100, userInfo: [NSLocalizedDescriptionKey: "Неверный URL"])))
            return
        }
        
        print("🌐 Отправка запроса к Edamam Food Database API:")
        print("   URL: \(url)")
        print("   App ID: \(edamamAppId)")
        print("   Query: \(query)")
        
        // Выполняем запрос - используем URLSession.shared вместо self.session
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: FoodDatabaseResponse.self, decoder: JSONDecoder())
            .sink(receiveCompletion: { [weak self] completionStatus in
                if case .failure(let error) = completionStatus {
                    print("❌ Ошибка API запроса: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                // Преобразуем результаты в наши модели
                let foodItems = self.convertFoodDatabaseResponseToFoodItems(response)
                print("✅ Получен ответ с \(foodItems.count) продуктами")
                completion(.success(foodItems))
            })
            .store(in: &cancellables)
    }
    
    // Преобразование ответа API в наши модели данных
    private func convertFoodDatabaseResponseToFoodItems(_ response: FoodDatabaseResponse) -> [RecommendedFoodItem] {
        return response.hints.compactMap { hint -> RecommendedFoodItem? in
            guard let food = hint.food,
                  let nutrients = food.nutrients,
                  let calories = nutrients.ENERC_KCAL else {
                return nil
            }
            
            // Базовые данные о питательной ценности
            let protein = nutrients.PROCNT ?? 0
            let carbs = nutrients.CHOCDF ?? 0
            let fat = nutrients.FAT ?? 0
            let sugars = nutrients.SUGAR ?? 0
            let fiber = nutrients.FIBTG ?? 0
            let sodium = nutrients.NA ?? 0
            
            return RecommendedFoodItem(
                id: UUID(),
                name: food.label,
                calories: Int(calories),
                servingSize: 100, // Стандартный размер порции
                servingUnit: "г",
                image: nil,
                category: food.category ?? "Общее",
                protein: protein,
                carbs: carbs,
                fat: fat,
                sugars: sugars,
                fiber: fiber,
                sodium: sodium
            )
        }
    }
    
    // MARK: - Lifecycle Methods
    
    @objc func saveContextOnTerminate() {
        print("FoodDatabaseService: Saving context on app termination")
        CoreDataManager.shared.saveContext()
    }
    
    @objc func saveContextOnBackground() {
        print("FoodDatabaseService: Saving context when app enters background")
        CoreDataManager.shared.saveContext()
    }
    
    func verifyDataModel() {
        print("FoodDatabaseService: Verifying data model integrity")
        
        // Check for any data model inconsistencies
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        do {
            let foods = try context.fetch(fetchRequest)
            print("Data model verification: Found \(foods.count) food items in database")
            
            // Check for any corrupted entries and fix them
            var needsSave = false
            for food in foods {
                // Fix any nil names
                if food.name == nil {
                    food.name = "Unknown Food"
                    needsSave = true
                }
                
                // Ensure creation date exists
                if food.createdAt == nil {
                    food.createdAt = Date()
                    needsSave = true
                }
                
                // Ensure servingUnit exists
                if food.servingUnit == nil {
                    food.servingUnit = "г"
                    needsSave = true
                }
            }
            
            if needsSave {
                print("Data model verification: Fixed corrupted entries")
                try context.save()
            }
        } catch {
            print("Data model verification error: \(error)")
        }
    }
}

// MARK: - API Response Models

// Структуры для декодирования ответа Edamam Food Database API
struct FoodDatabaseResponse: Codable {
    let hints: [FoodDatabaseHint]
    let parsed: [FoodDatabaseParsed]?
}

struct FoodDatabaseHint: Codable {
    let food: FoodDatabaseFood?
}

struct FoodDatabaseParsed: Codable {
    let food: FoodDatabaseFood?
}

struct FoodDatabaseFood: Codable {
    let foodId: String?
    let label: String
    let category: String?
    let nutrients: FoodDatabaseNutrients?
}

struct FoodDatabaseNutrients: Codable {
    let ENERC_KCAL: Double? // Калории
    let PROCNT: Double?     // Белки
    let FAT: Double?        // Жиры
    let CHOCDF: Double?     // Углеводы
    let FIBTG: Double?      // Клетчатка
    let SUGAR: Double?      // Сахар
    let NA: Double?         // Натрий
}

