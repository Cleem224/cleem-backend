import UIKit
import CoreData
import Combine

class FoodDataService {
    static let shared = FoodDataService()
    
    // Сервисы API из правильных директорий
    private let foodRecognitionManager = FoodRecognitionManagerV2()
    private let openFoodFactsService = OpenFoodFactsService.shared
    private let context = CoreDataManager.shared.context
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Распознавание еды по изображению
    
    func recognizeAndFetchFoodData(from image: UIImage, completion: @escaping (Result<[Food], Error>) -> Void) {
        // Используем FoodRecognitionManagerV2 вместо старого менеджера
        foodRecognitionManager.recognizeFood(from: image)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .finished:
                        break // Успешное завершение, результат уже получен через receiveValue
                    case .failure(let error):
                        print("Ошибка распознавания: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                },
                receiveValue: { [weak self] recognizedFoodsV2 in
                    guard let self = self else { return }
                    
                    if recognizedFoodsV2.isEmpty {
                        print("Продукты не распознаны")
                        completion(.success([]))
                        return
                    }
                    
                    var foods: [Food] = []
                    // Создаем объекты Food из распознанных продуктов
                    for recognizedFood in recognizedFoodsV2 {
                        if let nutrition = recognizedFood.nutritionData {
                            // Создаем Food из RecognizedFoodV2
                            self.createFoodFromRecognitionDataV2(
                                name: recognizedFood.name,
                                nutrition: nutrition,
                                image: image
                            ) { food in
                                foods.append(food)
                                
                                // Если все продукты обработаны, возвращаем результат
                                if foods.count == recognizedFoodsV2.count {
                                    completion(.success(foods))
                                }
                            }
                        } else {
                            // Если нет данных о питательной ценности, создаем базовый объект Food
                            self.createBasicFood(name: recognizedFood.name, image: image) { food in
                                foods.append(food)
                                
                                if foods.count == recognizedFoodsV2.count {
                                    completion(.success(foods))
                                }
                            }
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // Новый метод для создания Food из RecognizedFoodV2
    private func createFoodFromRecognitionDataV2(name: String, nutrition: NutritionDataV2, image: UIImage? = nil, completion: @escaping (Food) -> Void) {
        let context = CoreDataManager.shared.context
        
        // Проверяем, существует ли уже такой продукт в базе
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let existingFoods = try context.fetch(fetchRequest)
            
            if let existingFood = existingFoods.first {
                // Если уже есть в базе, просто возвращаем его
                completion(existingFood)
            } else {
                // Создаем новый продукт
                let food = Food(context: context)
                food.id = UUID()
                food.name = name
                food.calories = nutrition.calories
                food.protein = nutrition.protein
                food.carbs = nutrition.carbs
                food.fat = nutrition.fat
                food.fiber = nutrition.fiber ?? 0
                food.sugar = nutrition.sugar ?? 0
                
                // Сохраняем изображение, если оно есть
                if let imageData = image?.jpegData(compressionQuality: 0.7) {
                    food.imageData = imageData
                }
                
                // Устанавливаем размер порции по умолчанию
                food.servingSize = 100 // Стандартный размер порции
                food.servingUnit = "г"
                
                food.createdAt = Date()
                
                // Сохраняем в Core Data
                CoreDataManager.shared.saveContext()
                
                completion(food)
            }
        } catch {
            print("Error fetching or saving food: \(error)")
            
            // В случае ошибки создаем временный объект, но не сохраняем его в контексте
            let food = Food(context: context)
            food.id = UUID()
            food.name = name
            food.calories = nutrition.calories
            food.protein = nutrition.protein
            food.carbs = nutrition.carbs
            food.fat = nutrition.fat
            food.servingSize = 100
            food.servingUnit = "г"
            
            completion(food)
        }
    }
    
    // MARK: - Поиск по штрих-коду
    
    func searchFoodByBarcodeWithOpenFoodFacts(barcode: String, completion: @escaping (Result<[Food], Error>) -> Void) {
        openFoodFactsService.searchByBarcode(barcode: barcode) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                if let product = response.product {
                    let food = self.convertOpenFoodFactsProductToFood(product)
                    completion(.success([food]))
                } else {
                    // Если не нашли в Open Food Facts, возвращаем пустой массив
                    completion(.success([]))
                }
                
            case .failure(let error):
                // Возвращаем ошибку, так как нет запасного варианта
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Поиск по тексту
    
    func searchFoodByTextWithOpenFoodFacts(query: String, completion: @escaping (Result<[Food], Error>) -> Void) {
        openFoodFactsService.searchByName(query: query) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                if let products = response.products, !products.isEmpty {
                    // Создаем массив Food из массива продуктов
                    var foods: [Food] = []
                    let dispatchGroup = DispatchGroup()
                    
                    for product in products {
                        dispatchGroup.enter()
                        // Улучшенный метод конвертации с правильным сохранением в CoreData
                        self.convertAndSaveOpenFoodFactsProduct(product) { food in
                            foods.append(food)
                            dispatchGroup.leave()
                        }
                    }
                    
                    dispatchGroup.notify(queue: .main) {
                        // Сохраняем и обновляем UI когда все продукты обработаны
                        CoreDataManager.shared.saveContext()
                        
                        // Отправляем уведомление о том, что данные о еде обновились
                        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                        
                        completion(.success(foods))
                    }
                } else {
                    // Если не нашли в Open Food Facts, возвращаем пустой массив
                    completion(.success([]))
                }
                
            case .failure(let error):
                // Возвращаем ошибку, так как нет запасного варианта
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Конвертация данных
    
    // Создание Food объекта из данных распознавания
    private func createFoodFromRecognitionData(name: String, nutrition: NutritionData, image: UIImage? = nil, completion: @escaping (Food) -> Void) {
        let context = CoreDataManager.shared.context
        
        // Проверяем, существует ли уже такой продукт в базе
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let existingFoods = try context.fetch(fetchRequest)
            
            if let existingFood = existingFoods.first {
                // Если уже есть в базе, просто возвращаем его
                completion(existingFood)
            } else {
                // Создаем новый продукт
                let food = Food(context: context)
                food.id = UUID()
                food.name = name
                food.calories = nutrition.calories
                food.protein = nutrition.protein
                food.carbs = nutrition.carbs
                food.fat = nutrition.fat
                food.fiber = nutrition.fiber ?? 0
                food.sugar = nutrition.sugar ?? 0
                
                // Сохраняем изображение, если оно есть
                if let imageData = image?.jpegData(compressionQuality: 0.7) {
                    food.imageData = imageData
                }
                
                // Устанавливаем размер порции по умолчанию
                food.servingSize = 100 // Стандартный размер порции
                food.servingUnit = "г"
                
                food.createdAt = Date()
                
                // Сохраняем в Core Data
                CoreDataManager.shared.saveContext()
                
                completion(food)
            }
        } catch {
            print("Error fetching or saving food: \(error)")
            
            // В случае ошибки создаем временный объект, но не сохраняем его в контексте
            let food = Food(context: context)
            food.id = UUID()
            food.name = name
            food.calories = nutrition.calories
            food.protein = nutrition.protein
            food.carbs = nutrition.carbs
            food.fat = nutrition.fat
            food.servingSize = 100
            food.servingUnit = "г"
            
            completion(food)
        }
    }
    
    // Создание базового объекта Food без данных о питательной ценности
    private func createBasicFood(name: String, image: UIImage? = nil, completion: @escaping (Food) -> Void) {
        let context = CoreDataManager.shared.context
        
        // Проверяем, существует ли уже такой продукт в базе
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        
        do {
            let existingFoods = try context.fetch(fetchRequest)
            
            if let existingFood = existingFoods.first {
                completion(existingFood)
            } else {
                // Создаем новый продукт с базовыми данными
                let food = Food(context: context)
                food.id = UUID()
                food.name = name
                food.calories = 0
                food.protein = 0
                food.carbs = 0
                food.fat = 0
                
                // Сохраняем изображение, если оно есть
                if let imageData = image?.jpegData(compressionQuality: 0.7) {
                    food.imageData = imageData
                }
                
                food.servingSize = 100
                food.servingUnit = "г"
                food.createdAt = Date()
                
                // Сохраняем в Core Data
                CoreDataManager.shared.saveContext()
                
                completion(food)
            }
        } catch {
            print("Error creating basic food: \(error)")
            
            // В случае ошибки создаем временный объект
            let food = Food(context: context)
            food.id = UUID()
            food.name = name
            food.calories = 0
            food.protein = 0
            food.carbs = 0
            food.fat = 0
            food.servingSize = 100
            food.servingUnit = "г"
            
            completion(food)
        }
    }
    
    // Преобразование данных из Open Food Facts в объекты Core Data
    private func convertOpenFoodFactsProductToFood(_ product: OpenFoodFactsProduct) -> Food {
        let context = CoreDataManager.shared.context
        
        // Очищаем кэш контекста перед работой с Food
        context.reset()
        
        // Проверяем, существует ли уже такой продукт в базе по штрих-коду или имени
        var existingFood: Food?
        
        if let barcode = product.code, !barcode.isEmpty {
            let barcodeRequest: NSFetchRequest<Food> = Food.fetchRequest()
            barcodeRequest.predicate = NSPredicate(format: "barcode == %@", barcode)
            
            do {
                let foods = try context.fetch(barcodeRequest)
                if let first = foods.first {
                    existingFood = first
                }
            } catch {
                print("Ошибка поиска по штрих-коду: \(error)")
            }
        }
        
        // Если по штрих-коду не нашли, ищем по имени
        if existingFood == nil, let productName = product.productName, !productName.isEmpty {
            let nameRequest: NSFetchRequest<Food> = Food.fetchRequest()
            nameRequest.predicate = NSPredicate(format: "name == %@", productName)
            
            do {
                let foods = try context.fetch(nameRequest)
                if let first = foods.first {
                    existingFood = first
                }
            } catch {
                print("Ошибка поиска по имени: \(error)")
            }
        }
        
        // Если нашли существующий продукт, возвращаем его
        if let existingFood = existingFood {
            return existingFood
        }
        
        // Создаем новый продукт
        let food = Food(context: context)
        food.id = UUID()
        
        // Устанавливаем имя продукта
        food.name = product.productName ?? "Неизвестный продукт"
        
        // Устанавливаем штрих-код
        food.barcode = product.code
        
        // Обрабатываем бренд, если он доступен
        if let brandsStr = product.brands {
            let brandComponents = brandsStr.components(separatedBy: ",")
            if let firstBrand = brandComponents.first {
                let trimmedBrand = firstBrand.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                food.brand = trimmedBrand
            }
        }
        
        // Извлекаем данные о питательной ценности
        if let nutriments = product.nutriments {
            food.calories = nutriments.energyKcal100g ?? 0.0
            food.protein = nutriments.proteins100g ?? 0.0
            food.carbs = nutriments.carbohydrates100g ?? 0.0
            food.fat = nutriments.fat100g ?? 0.0
            food.sugar = nutriments.sugars100g ?? 0.0
            food.fiber = nutriments.fiber100g ?? 0.0
            food.sodium = nutriments.sodium100g ?? 0.0
        }
        
        // Устанавливаем размер порции по умолчанию (100 г)
        food.servingSize = 100.0
        food.servingUnit = "г"
        
        // Если указано количество продукта, используем его
        if let quantityStr = product.quantity {
            // Попытка извлечь числовое значение и единицу измерения
            let components = quantityStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
            let units = quantityStr.components(separatedBy: CharacterSet.decimalDigits)
            
            if let sizeStr = components.first(where: { !$0.isEmpty }),
               let size = Double(sizeStr) {
                
                food.servingSize = size
                
                if let lastUnit = units.last {
                    let trimmedUnit = lastUnit.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !trimmedUnit.isEmpty {
                        food.servingUnit = trimmedUnit
                    }
                }
            }
        }
        
        // Устанавливаем категорию продукта
        if let categoriesStr = product.categories {
            let categoryList = categoriesStr.components(separatedBy: ",")
            if let firstCategory = categoryList.first {
                let trimmedCategory = firstCategory.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                food.category = trimmedCategory
            }
        }
        
        // Сохраняем изображение, если оно доступно
        if let imageUrlStr = product.imageUrl,
           let url = URL(string: imageUrlStr) {
            do {
                let imageData = try Data(contentsOf: url)
                food.imageData = imageData
            } catch {
                print("Ошибка загрузки изображения: \(error)")
            }
        }
        
        food.createdAt = Date()
        
        // Сохраняем в базу данных
        CoreDataManager.shared.saveContext()
        
        return food
    }
    
    // Новый метод для конвертации и сохранения продукта с гарантией сохранения в CoreData и UserDefaults
    private func convertAndSaveOpenFoodFactsProduct(_ product: OpenFoodFactsProduct, completion: @escaping (Food) -> Void) {
        let context = CoreDataManager.shared.context
        
        // Создаем объект Food из продукта OpenFoodFacts
        let food = Food(context: context)
        
        // Генерируем уникальный ID
        food.id = UUID()
        
        // Название продукта
        food.name = product.productName ?? product.genericName ?? "Неизвестный продукт"
        
        // Данные о питательной ценности
        if let nutriments = product.nutriments {
            food.calories = Double(nutriments.energyKcal100g ?? 0)
            food.protein = Double(nutriments.proteins100g ?? 0)
            food.carbs = Double(nutriments.carbohydrates100g ?? 0)
            food.fat = Double(nutriments.fat100g ?? 0)
            food.fiber = Double(nutriments.fiber100g ?? 0)
            food.sugar = Double(nutriments.sugars100g ?? 0)
        }
        
        // Стандартный размер порции
        food.servingSize = 100 // Стандартный размер - 100г
        food.servingUnit = "г"
        
        // Устанавливаем штрих-код
        food.barcode = product.code
        
        // Время создания
        food.createdAt = Date()
        
        // Отмечаем, что это НЕ ингредиент
        food.isIngredient = false
        
        // Загружаем изображение продукта, если доступно
        if let imageUrl = product.imageUrl, !imageUrl.isEmpty,
           let url = URL(string: imageUrl) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, error == nil {
                    // Сохраняем изображение в CoreData
                    food.imageData = data
                    
                    // Также создаем резервную копию в UserDefaults
                    if let name = food.name, let id = food.id {
                        let backupKey = "imageBackup_\(name)_\(id.uuidString)"
                        UserDefaults.standard.set(data, forKey: backupKey)
                    }
                    
                    // Сохраняем изменения
                    try? context.save()
                }
                
                // Сохраняем в UserDefaults для отображения в RecentlyLoggedView
                self.saveFoodToUserDefaults(food)
                
                completion(food)
            }.resume()
        } else {
            // Сохраняем без изображения
            try? context.save()
            
            // Сохраняем в UserDefaults для отображения в RecentlyLoggedView
            self.saveFoodToUserDefaults(food)
            
            completion(food)
        }
    }
    
    // Вспомогательный метод для сохранения продукта в UserDefaults
    private func saveFoodToUserDefaults(_ food: Food) {
        guard let id = food.id?.uuidString, let name = food.name else { return }
        
        // Получаем текущую историю еды
        var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        
        // Создаем словарь с данными о еде
        var foodDict: [String: Any] = [
            "id": id,
            "name": name,
            "calories": food.calories,
            "protein": food.protein,
            "carbs": food.carbs,
            "fat": food.fat,
            "createdAtTimestamp": food.createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "servingSize": food.servingSize,
            "servingUnit": food.servingUnit ?? "г",
            "isFavorite": food.isFavorite,
            "hasImageData": food.imageData != nil && food.imageData!.count > 0
        ]
        
        // Добавляем в начало истории
        foodHistory.insert(foodDict, at: 0)
        
        // Ограничиваем размер истории
        if foodHistory.count > 30 {
            foodHistory = Array(foodHistory.prefix(30))
        }
        
        // Сохраняем обновленную историю в UserDefaults
        UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Рекомендации продуктов
    
    func getRecommendedFoods(completion: @escaping ([Food]) -> Void) {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        // Ограничиваем выборку 10 случайными продуктами
        fetchRequest.fetchLimit = 10
        
        do {
            var foods = try context.fetch(fetchRequest)
            
            // Если продуктов в базе мало, добавляем базовые продукты
            if foods.count < 5 {
                // Основные продукты для рекомендаций
                let basicFoods = ["Яблоко", "Банан", "Апельсин", "Курица", "Рис"]
                for foodName in basicFoods {
                    searchFoodByTextWithOpenFoodFacts(query: foodName) { _ in }
                }
                
                // Пытаемся получить обновленный список после добавления
                foods = try context.fetch(fetchRequest)
            }
            
            // Сортируем случайным образом для разнообразия рекомендаций
            foods.shuffle()
            completion(foods)
            
        } catch {
            print("Ошибка при получении рекомендованных продуктов: \(error)")
            completion([])
        }
    }
    
    // MARK: - История продуктов
    
    func getRecentFoods(limit: Int = 15, completion: @escaping ([Food]) -> Void) {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        // Сортируем по дате создания (сначала новые)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let foods = try context.fetch(fetchRequest)
            completion(foods)
        } catch {
            print("Ошибка при получении недавних продуктов: \(error)")
            completion([])
        }
    }
    
    // MARK: - Поиск по локальной базе
    
    func searchLocalFoods(query: String, completion: @escaping ([Food]) -> Void) {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        // Поиск по имени, не чувствительный к регистру
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        
        do {
            let foods = try context.fetch(fetchRequest)
            completion(foods)
        } catch {
            print("Ошибка при поиске в локальной базе: \(error)")
            completion([])
        }
    }
    
    // MARK: - Дополнительные методы для совместимости с интерфейсом
    
    // Метод для поиска через OpenFoodFactsService и преобразования результатов в Food
    func searchByName(query: String, completion: @escaping ([Food]) -> Void) {
        // Сначала ищем локально в базе данных
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.fetchLimit = 10
        
        do {
            let localFoods = try context.fetch(fetchRequest)
            
            // Если нашли хотя бы 3 результата локально, возвращаем их
            if localFoods.count >= 3 {
                completion(localFoods)
                return
            }
            
            // Если локальных результатов мало, дополняем из OpenFoodFacts
            Task {
                do {
                    let products = try await openFoodFactsService.searchProducts(query: query)
                    let remoteFoods = products.map { self.convertOpenFoodFactsProductToFood($0) }
                    
                    // Объединяем результаты
                    let combinedFoods = Array(Set(localFoods + remoteFoods))
                    completion(combinedFoods)
                } catch {
                    print("Ошибка поиска в OpenFoodFacts: \(error)")
                    completion(localFoods) // Возвращаем хотя бы локальные результаты
                }
            }
        } catch {
            print("Ошибка при поиске продуктов в локальной базе: \(error)")
            
            // Если локальный поиск не удался, пробуем найти только в OpenFoodFacts
            Task {
                do {
                    let products = try await openFoodFactsService.searchProducts(query: query)
                    let remoteFoods = products.map { self.convertOpenFoodFactsProductToFood($0) }
                    completion(remoteFoods)
                } catch {
                    print("Ошибка поиска в OpenFoodFacts: \(error)")
                    completion([])
                }
            }
        }
    }
    
    // Обертка для совместимости с другими сигнатурами
    func searchFoodByBarcodeWithOpenFoodFacts(barcode: String, completion: @escaping (Result<Food, Error>) -> Void) {
        searchFoodByBarcodeWithOpenFoodFacts(barcode: barcode) { result in
            switch result {
            case .success(let foods):
                if let firstFood = foods.first {
                    completion(.success(firstFood))
                } else {
                    completion(.failure(NSError(domain: "FoodDataService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Продукт не найден"])))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}


