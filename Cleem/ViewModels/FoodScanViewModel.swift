import Foundation
import UIKit
import Combine
import CoreData
import SwiftUI
import Vision

class FoodScanViewModel: ObservableObject {
    @Published var recognizedFood: Food?
    @Published var loadedProduct: OpenFoodFactsProduct?
    @Published var scanningState: ScanningState = .ready
    @Published var errorMessage: String?
    @Published var scanMode: FoodScanMode = .normal
    @Published var showProgress: Bool = false
    @Published var isScanning: Bool = false
    @Published var isAnalyzing: Bool = false
    @Published var scanningProgress: CGFloat = 0.0
    @Published var scanAnimationAmount: CGFloat = 1.0
    @Published var progress: Float = 0.0
    @Published var showResult = false
    @Published var recognizedFoods: [Food] = []
    @Published var lastAddedMeal: Meal?
    @Published var caloriesConsumed: Double = 0
    @Published var proteinConsumed: Double = 0
    @Published var carbsConsumed: Double = 0
    @Published var fatConsumed: Double = 0
    @Published var analyzedFood: Food?
    @Published var shouldShowError: Bool = false
    @Published var recognizedBarcode: String? = nil
    @Published var processingProgress: Double = 0.0
    @Published var showError: Bool = false
    @Published var capturedImage: UIImage?
    @Published var isAnalyzingFood: Bool = false
    @Published var lastImageScanned: UIImage?
    @Published var errorState: String?
    
    private var loadingTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var analysisTimeoutTimer: Timer?
    private var context: NSManagedObjectContext
    private var foodRecognitionManager: FoodRecognitionManagerV2
    private var openFoodFactsService: OpenFoodFactsService
    private var foodDataService: FoodDataService
    private var cancellables = Set<AnyCancellable>()
    
    var scanTimer: Timer?
    var analysisStartTime: Date?
    let maxAnalysisTime: TimeInterval = 10.0 // максимальное время анализа
    
    // Возможные продукты, которые система может распознать
    private struct FoodInfo {
        let name: String
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let icon: String
        let color: Color
    }
    
    // База данных продуктов, которые мы умеем распознавать
    private let knownFoods: [FoodInfo] = [
        FoodInfo(name: "Apple", calories: 52, protein: 0.3, fat: 0.2, carbs: 14, icon: "apple", color: .red),
        FoodInfo(name: "Banana", calories: 89, protein: 1.1, fat: 0.3, carbs: 23, icon: "fork.knife", color: .yellow),
        FoodInfo(name: "Orange", calories: 47, protein: 0.9, fat: 0.1, carbs: 12, icon: "fork.knife", color: .orange),
        FoodInfo(name: "Strawberry", calories: 33, protein: 0.7, fat: 0.3, carbs: 8, icon: "fork.knife", color: .pink),
        FoodInfo(name: "Broccoli", calories: 34, protein: 2.8, fat: 0.4, carbs: 7, icon: "leaf", color: .green),
        FoodInfo(name: "Carrot", calories: 41, protein: 0.9, fat: 0.2, carbs: 10, icon: "leaf", color: .orange),
        FoodInfo(name: "Chicken", calories: 165, protein: 31, fat: 3.6, carbs: 0, icon: "fork.knife", color: .brown),
        FoodInfo(name: "Salmon", calories: 206, protein: 22, fat: 13, carbs: 0, icon: "fish", color: .pink),
        FoodInfo(name: "Rice", calories: 130, protein: 2.7, fat: 0.3, carbs: 28, icon: "fork.knife", color: .white),
        FoodInfo(name: "Pasta", calories: 158, protein: 5.8, fat: 0.9, carbs: 31, icon: "fork.knife", color: .yellow),
        FoodInfo(name: "Chocolate", calories: 546, protein: 4.9, fat: 31, carbs: 61, icon: "fork.knife", color: .brown),
        FoodInfo(name: "Pizza", calories: 266, protein: 11, fat: 10, carbs: 33, icon: "fork.knife", color: .red)
    ]
    
    init(context: NSManagedObjectContext) {
        self.context = context
        // Инициализируем сервисы
        self.foodRecognitionManager = FoodRecognitionManagerV2()
        self.openFoodFactsService = OpenFoodFactsService.shared
        self.foodDataService = FoodDataService.shared
        
        // Загружаем начальные данные при создании
        fetchTodayConsumption()
    }
    
    enum ScanningState {
        case ready
        case scanning
        case analyzing
        case success
        case error
    }
    
    // Типы приемов пищи
    enum FoodScanMealType: String {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
    }
    
    // MARK: - Food Scanning Functions
    
    func scanFood(from image: UIImage, scanMode: FoodScanMode) {
        // Сбрасываем предыдущие ошибки
        errorMessage = nil
        
        // Устанавливаем состояние сканирования
        isScanning = true
        isAnalyzing = true
        scanningState = .scanning
        
        // Сохраняем захваченное изображение
        capturedImage = image
        lastImageScanned = image
        
        // Начинаем анимацию прогресса
        startProgressAnimation()
        
        // В режиме симуляции, выбираем случайный продукт из knownFoods
        let randomIndex = Int.random(in: 0..<knownFoods.count)
        let randomFood = knownFoods[randomIndex]
        
        // Симулируем задержку при анализе изображения (1-2 секунды)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.0)) { [weak self] in
            guard let self = self else { return }
            
            // Создаем объект Food из выбранного продукта
            let food = self.createOrFetchFood(
                name: randomFood.name,
                calories: randomFood.calories,
                protein: randomFood.protein,
                fat: randomFood.fat,
                carbs: randomFood.carbs
            )
            
            // Сохраняем изображение, если оно есть
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                food.imageData = imageData
                do {
                    try self.context.save()
                } catch {
                    print("Error saving image data: \(error)")
                }
            }
            
            // Устанавливаем распознанный продукт
            self.recognizedFood = food
            self.analyzedFood = food
            
            // Завершаем анимацию прогресса
            self.stopProgressAnimation()
            
            // Устанавливаем состояние успеха
            self.scanningState = .success
            
            // Обрабатываем успешное сканирование и переход на главный экран
            self.handleSuccessfulScan(food: food)
        }
    }
    
    private func createOrFetchFood(name: String, calories: Double, protein: Double, fat: Double, carbs: Double) -> Food {
        // Проверяем, существует ли уже такой продукт
        if let existingFood = getFoodByName(name: name) {
            return existingFood
        }
        
        // Создаем новый продукт
        let food = Food(context: context)
        food.id = UUID()
        food.foodId = UUID().uuidString
        food.name = name
        food.calories = calories
        food.protein = protein
        food.fat = fat
        food.carbs = carbs
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = 100
        food.servingUnit = "г"
        
        // Сохраняем в базу данных
        do {
            try context.save()
        } catch {
            print("Ошибка при сохранении продукта: \(error)")
        }
        
        return food
    }
    
    func cancelAnalysis() {
        // Отменяем текущую задачу загрузки, если она есть
        loadingTask?.cancel()
        loadingTask = nil
        
        // Останавливаем таймер прогресса
        stopProgressTimer()
        
        // Сбрасываем состояния
        isScanning = false
        isAnalyzing = false
        showProgress = false
        scanningState = .ready
        errorMessage = nil
        
        // Публикуем уведомление о прерывании анализа
        NotificationCenter.default.post(name: Notification.Name.didCancelFoodAnalysis, object: nil)
    }
    
    private func startProgressTimer() {
        // Останавливаем существующий таймер, если он есть
        stopProgressTimer()
        
        // Запускаем новый таймер, который будет увеличивать прогресс
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let weakSelf = self else { return }
            
            // Увеличиваем прогресс максимум до 95% (чтобы оставить 100% для завершения)
            if weakSelf.scanningProgress < 0.95 {
                // Делаем прогресс нелинейным, чтобы он замедлялся к концу
                let increment = 0.01 * (1.0 - weakSelf.scanningProgress/1.0)
                weakSelf.scanningProgress += increment
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    // MARK: - Barcode Scanning Functions
    
    func scanBarcode(barcode: String) {
        self.errorMessage = nil
        self.loadedProduct = nil
        self.scanningState = .scanning
        self.isScanning = true
        self.isAnalyzing = true
        
        // Начинаем анимацию прогресса
        startProgressAnimation()
        
        // В режиме симуляции, выбираем случайный продукт из knownFoods
        let randomIndex = Int.random(in: 0..<knownFoods.count)
        let randomFood = knownFoods[randomIndex]
        
        // Симулируем задержку при анализе штрих-кода (1-2 секунды)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.0)) { [weak self] in
            guard let self = self else { return }
            
            // Создаем объект Food из выбранного продукта
            let food = self.createOrFetchFood(
                name: "Barcode \(barcode): \(randomFood.name)",
                calories: randomFood.calories,
                protein: randomFood.protein,
                fat: randomFood.fat,
                carbs: randomFood.carbs
            )
            
            // Добавляем штрих-код к продукту
            food.barcode = barcode
            
            // Сохраняем объект
            do {
                try self.context.save()
            } catch {
                print("Error saving barcode food: \(error)")
            }
            
            // Устанавливаем результат
            self.recognizedFood = food
            self.analyzedFood = food
            
            // Завершаем анимацию прогресса
            self.stopProgressAnimation()
            
            // Устанавливаем состояние успеха
            self.scanningState = .success
            self.isScanning = false
            
            // Обрабатываем успешное сканирование и переход на главный экран
            self.handleSuccessfulScan(food: food)
            
            // Отправляем уведомления
            NotificationCenter.default.post(name: Notification.Name.didFinishBarcodeScanning, object: nil)
            NotificationCenter.default.post(name: Notification.Name.didRecognizeBarcode, object: nil)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getFoodByName(name: String) -> Food? {
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request)
            return result.first
        } catch {
            print("Error fetching food by name: \(error)")
            return nil
        }
    }
    
    private func getFoodByBarcode(barcode: String) -> Food? {
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "barcode == %@", barcode)
        request.fetchLimit = 1
        
        do {
            let result = try context.fetch(request)
            return result.first
        } catch {
            print("Error fetching food by barcode: \(error)")
            return nil
        }
    }
    
    private func addFoodToMeal(food: Food) {
        // Создаем приём пищи, если его нет
        let fetchRequest: NSFetchRequest<Meal> = Meal.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@ AND type == %@", Calendar.current.startOfDay(for: Date()) as NSDate, FoodScanMealType.lunch.rawValue)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            let meal: Meal
            
            if let existingMeal = results.first {
                meal = existingMeal
            } else {
                // Создаем новый прием пищи
                meal = Meal(context: context)
                meal.id = UUID()
                meal.date = Calendar.current.startOfDay(for: Date())
                meal.type = FoodScanMealType.lunch.rawValue
            }
            
            // Создаем связь между продуктом и приемом пищи
            let mealFood = MealFood(context: context)
            mealFood.id = UUID()
            mealFood.food = food
            mealFood.meal = meal
            mealFood.amount = 100 // Пример количества в граммах
            
            // Рассчитываем питательную ценность
            if #available(iOS 15.0, *) {
                meal.calculateTotals()
            } else {
                // В старых версиях iOS устанавливаем значения напрямую
                meal.totalCalories = food.calories
                meal.totalProtein = food.protein
                meal.totalCarbs = food.carbs
                meal.totalFat = food.fat
            }
            
            // Сохраняем изменения
            try context.save()
        } catch {
            print("Ошибка при добавлении продукта в прием пищи: \(error)")
        }
    }
    
    // Метод для поиска продуктов по тексту
    func searchFood(query: String) {
        isScanning = true
        isAnalyzing = true
        errorMessage = nil
        
        foodDataService.searchFoodByTextWithOpenFoodFacts(query: query) { [weak self] (result: Result<[Food], Error>) in
                guard let self = self else { return }
            
            // Обрабатываем результат сразу в замыкании completion
                self.isScanning = false
                    self.isAnalyzing = false
                    
                    switch result {
                    case .success(let foods):
                        if foods.isEmpty {
                    self.errorMessage = "Не найдено продуктов по запросу"
                            self.analyzedFood = nil
                        } else {
                            self.recognizedFoods = foods
                            if let firstFood = foods.first {
                                self.analyzedFood = firstFood
                        
                        // Добавляем продукт в прием пищи и обновляем данные
                        self.addFoodToCurrentMeal(food: firstFood)
                        
                        // Обновляем данные о потреблении
                        self.fetchTodayConsumption()
                    }
                }
                
            case .failure(let error):
                self.errorMessage = "Ошибка при поиске: \(error.localizedDescription)"
                self.analyzedFood = nil
            }
        }
    }
    
    // Метод для добавления продукта в прием пищи
    func addFoodToCurrentMeal(food: Food) {
        // Создаем или получаем прием пищи на текущий день
        let meal = getMealForNow()
        
        // Force set to now with a significant offset to ensure it's the most recent
        // Adding 3600 seconds (1 hour) to the current time ensures this food is newest
        food.createdAt = Date().addingTimeInterval(3600) // Гарантированно новее всех других продуктов
        
        // Mark as single food and set as last scanned food ID
        if let id = food.id?.uuidString {
            UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
            UserDefaults.standard.set(true, forKey: "single_food_\(id)")
            UserDefaults.standard.set(false, forKey: "food_ingredient_\(id)")
            print("FoodScanViewModel: Marked food \(food.name ?? "Unknown") as single food and last scanned with future timestamp")
        }
        
        // Создаем связь между приемом пищи и продуктом
        let mealFood = MealFood(context: context)
        mealFood.id = UUID()
        mealFood.food = food
        mealFood.meal = meal
        mealFood.amount = 1.0  // По умолчанию одна порция
        mealFood.unit = food.servingUnit ?? "г"
        
        // Копируем значения питательных веществ
        mealFood.calories = food.calories
        mealFood.protein = food.protein
        mealFood.carbs = food.carbs
        mealFood.fat = food.fat
        
        // Explicitly mark as NOT an ingredient and as a single food
        food.isIngredient = false
        if let id = food.id?.uuidString {
            UserDefaults.standard.set(false, forKey: "food_ingredient_\(id)")
            UserDefaults.standard.set(true, forKey: "single_food_\(id)")
        }
        
        // Сохраняем изменения в CoreData
        CoreDataManager.shared.saveContext()
        
        // Сохраняем продукт в UserDefaults для восстановления при перезапуске
        saveFoodToUserDefaults(food)
        
        // Обновляем данные о потреблении для пользователя
        NavigationCoordinator.shared.userProfile.addConsumedFood(
            calories: food.calories,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat
        )
        
        // Сохраняем ссылку на последний отсканированный продукт
        NavigationCoordinator.shared.recentlyScannedFood = food
        
        // Force immediate refresh of Recently Logged view
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            
            // Send a second notification after a short delay to ensure UI updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
        }
    }
    
    // Helper method to update food timestamp in UserDefaults
    private func updateFoodTimestampInUserDefaults(food: Food) {
        guard let id = food.id?.uuidString, let name = food.name else { return }
        
        // Get current food history
        guard var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] else { return }
        
        // Remove any existing entry for this food
        foodHistory.removeAll { ($0["id"] as? String) == id }
        
        // Create a new entry with current timestamp
        let currentTimestamp = Date().timeIntervalSince1970
        var foodDict: [String: Any] = [
            "id": id,
            "name": name,
            "calories": food.calories,
            "protein": food.protein,
            "carbs": food.carbs,
            "fat": food.fat,
            "createdAtTimestamp": currentTimestamp,
            "servingSize": food.servingSize,
            "servingUnit": food.servingUnit ?? "г",
            "isFavorite": food.isFavorite,
            "hasImageData": food.imageData != nil && food.imageData!.count >= 50,
            "isIngredient": false
        ]
        
        // Add to the beginning of the array
        foodHistory.insert(foodDict, at: 0)
        
        // Save updated history
        UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        UserDefaults.standard.synchronize()
        
        print("UpdateFoodTimestampInUserDefaults: Updated timestamp for \(name) to current time")
    }
    
    // Метод для получения или создания приема пищи на текущее время
    private func getMealForNow() -> Meal {
        let calendar = Calendar.current
        let now = Date()
        
        // Начало и конец текущего дня
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Определение типа приема пищи на основе времени суток
        let foodScanMealType = getMealTypeForTime(date: now)
        
        // Запрос существующего приема пищи того же типа за сегодня
        let fetchRequest: NSFetchRequest<Meal> = Meal.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "(date >= %@) AND (date < %@) AND (type == %@)",
            startOfDay as NSDate,
            endOfDay as NSDate,
            foodScanMealType.rawValue
        )
        
        do {
            let existingMeals = try context.fetch(fetchRequest)
            
            // Если уже есть подходящий прием пищи, используем его
            if let existingMeal = existingMeals.first {
                return existingMeal
            }
        } catch {
            print("Ошибка при поиске существующего приема пищи: \(error)")
        }
        
        // Если нет подходящего приема пищи, создаем новый
        let newMeal = Meal(context: context)
        newMeal.id = UUID()
        newMeal.date = now
        newMeal.type = foodScanMealType.rawValue
        
        // Сохраняем новый прием пищи
        do {
            try context.save()
        } catch {
            print("Ошибка при создании нового приема пищи: \(error)")
        }
        
        return newMeal
    }
    
    // Определяем тип приема пищи на основе времени суток
    private func getMealTypeForTime(date: Date) -> FoodScanMealType {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Определяем, в какое время суток попадает время
        if hour >= 5 && hour < 11 {
            return .breakfast
        } else if hour >= 11 && hour < 16 {
            return .lunch
        } else if hour >= 16 && hour < 21 {
            return .dinner
        } else {
            return .snack
        }
    }
    
    // Обновляем данные о потреблении пищи за день
    func updateConsumptionData() {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Запрос всех приемов пищи за сегодня
        let fetchRequest: NSFetchRequest<Meal> = Meal.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "(date >= %@) AND (date < %@)",
            startOfDay as NSDate, endOfDay as NSDate
        )
        
        do {
            let meals = try context.fetch(fetchRequest)
            
            // Сбрасываем счетчики потребления
            var totalCalories: Double = 0
            var totalProtein: Double = 0
            var totalCarbs: Double = 0
            var totalFat: Double = 0
            
            // Суммируем потребление из всех приемов пищи
            for meal in meals {
                if let mealFoods = meal.mealFoods?.allObjects as? [MealFood] {
                    for mealFood in mealFoods {
                        if let food = mealFood.food {
                            totalCalories += food.calories * mealFood.amount
                            totalProtein += food.protein * mealFood.amount
                            totalCarbs += food.carbs * mealFood.amount
                            totalFat += food.fat * mealFood.amount
                        }
                    }
                }
            }
            
            // Обновляем опубликованные переменные
            DispatchQueue.main.async {
                self.caloriesConsumed = totalCalories
                self.proteinConsumed = totalProtein
                self.carbsConsumed = totalCarbs
                self.fatConsumed = totalFat
            }
            
        } catch {
            print("Ошибка при расчете потребления: \(error)")
        }
    }
    
    // Метод для получения дневного потребления
    func fetchTodayConsumption() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<Meal> = Meal.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        
        do {
            let meals = try context.fetch(fetchRequest)
            caloriesConsumed = meals.reduce(0) { $0 + $1.totalCalories }
            proteinConsumed = meals.reduce(0) { $0 + $1.totalProtein }
            carbsConsumed = meals.reduce(0) { $0 + $1.totalCarbs }
            fatConsumed = meals.reduce(0) { $0 + $1.totalFat }
            
            // Если у нас есть приемы пищи, мы должны установить analyzedFood на последний добавленный продукт
            if let latestMeal = meals.sorted(by: { $0.date ?? Date() > $1.date ?? Date() }).first,
               let latestMealFood = latestMeal.mealFoods?.allObjects.first as? MealFood {
                analyzedFood = latestMealFood.food
            }
            
        } catch {
            print("Error fetching meals: \(error)")
        }
    }
    
    // Получение недавних продуктов
    func fetchRecentFoods() {
        // Реализация функции для получения недавних продуктов
        // Эта функция должна загружать и обновлять список недавно добавленных продуктов
    }
    
    // Получение рекомендуемых продуктов
    func fetchRecommendedFoods() {
        // Отключаем создание демо-продуктов для предотвращения появления Apple по умолчанию
        print("FoodScanViewModel: Запрос рекомендуемых продуктов отключен для предотвращения появления Apple по умолчанию")
        // Раньше здесь создавались рекомендуемые продукты, включая Apple
        
        // Проверяем наличие существующих распознанных продуктов
        if !self.recognizedFoods.isEmpty {
            return
        }
        
        // НЕ устанавливаем продукт Apple в качестве analyzed food
        // Это могло быть причиной появления Apple по умолчанию
    }
    
    // Вспомогательный метод для создания образцов рекомендуемых продуктов
    private func createSampleRecommendedFoods() -> [Food] {
        var recommendedFoods: [Food] = []
        
        // Создаем только безопасные демо-продукты, исключая яблоко
        let bananaFood = Food(context: context)
        bananaFood.id = UUID()
        bananaFood.name = "Banana"
        bananaFood.calories = 89
        bananaFood.protein = 1.1
        bananaFood.carbs = 23.0
        bananaFood.fat = 0.3
        bananaFood.sugar = 12.0
        bananaFood.fiber = 2.6
        bananaFood.createdAt = Date()
        bananaFood.servingSize = 100
        bananaFood.servingUnit = "г"
        
        // Добавляем только банан и не добавляем яблоко
        recommendedFoods.append(bananaFood)
        
        return recommendedFoods
    }
    
    // Метод для ручного добавления продукта
    func addManualFood(name: String) {
        isScanning = true
        errorMessage = nil
        
        foodDataService.searchFoodByTextWithOpenFoodFacts(query: name) { [weak self] result in
                guard let self = self else { return }
            
            // Обрабатываем результат напрямую
                self.isScanning = false
                
                switch result {
                case .success(let foods):
                    if let firstFood = foods.first {
                        self.analyzedFood = firstFood
                    self.addFoodToCurrentMeal(food: firstFood)
                    } else {
                    self.errorMessage = "Продукт не найден"
                    }
                    
                case .failure(let error):
                self.errorMessage = "Ошибка при поиске: \(error.localizedDescription)"
            }
        }
    }
    
    // Метод для сброса сканера и начала нового сканирования
    func resetScanner() {
        print("Resetting scanner state...")
        isScanning = false
        isAnalyzing = false
        errorMessage = nil
        processingProgress = 0.0
        
        // Не очищаем recognizedFoods и analyzedFood,
        // чтобы сохранить их для отображения в истории,
        // но устанавливаем флаг, что готовы к новому сканированию
        
        // Отправляем уведомление о сбросе сканера
        NotificationCenter.default.post(
            name: NSNotification.Name("ScannerResetCompleted"),
            object: nil
        )
    }
    
    func addFoodFromNutrition(name: String, calories: Double, protein: Double, fat: Double, carbs: Double, image: UIImage? = nil) -> Food {
        // Create new food entity
        let food = Food(context: context)
        food.id = UUID()
        food.name = name
        food.calories = calories
        food.protein = protein
        food.fat = fat
        food.carbs = carbs
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = 100
        
        // Save image data if available
        if let image = image, let imageData = image.jpegData(compressionQuality: 0.7) {
            food.imageData = imageData
        }
        
        // Save the context
        do {
            try context.save()
            
            // Также сохраняем в UserDefaults для персистентности
            saveFoodToUserDefaults(food)
            
            print("✅ Продукт \(name) сохранен в CoreData и UserDefaults")
        } catch {
            print("❌ Error saving food from nutrition: \(error)")
        }
        
        // Add the food to a meal
        addRecognizedFoodToMeal()
        
        // Set the analyzed food
        self.analyzedFood = food
        
        // Post notification that food was analyzed successfully
        NotificationCenter.default.post(name: Notification.Name.foodAnalyzedSuccessfully, object: nil)
        
        return food
    }
    
    // Метод для создания продукта из данных о питательной ценности
    func createFoodFromNutrition(_ nutrition: FoodNutrition, image: UIImage? = nil) -> Food {
        let food = addFoodFromNutrition(
            name: nutrition.foodName,
            calories: nutrition.calories,
            protein: nutrition.protein,
            fat: nutrition.fat,
            carbs: nutrition.carbs,
            image: image
        )
        
        // Устанавливаем проанализированную еду
        self.analyzedFood = food
        
        // Отправляем уведомление для обновления главного экрана
        NotificationCenter.default.post(name: Notification.Name.foodAnalyzedSuccessfully, object: nil)
        
        return food
    }
    
    // Вспомогательный метод для анимации прогресса
    private func startProgressAnimation() {
        scanningProgress = 0.0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let weakSelf = self else {
                timer.invalidate()
                return
            }
            
            // Create a more dynamic progress animation that moves quickly at first
            // then slows down as it approaches completion
            if weakSelf.scanningProgress < 0.3 {
                // Move quickly at the beginning (6% per tick)
                weakSelf.scanningProgress += 0.06
            } else if weakSelf.scanningProgress < 0.7 {
                // Medium speed in the middle (3% per tick)
                weakSelf.scanningProgress += 0.03
            } else {
                // Slower at the end (1% per tick)
                weakSelf.scanningProgress += 0.01
            }
            
            // Cap at 95% (the final 5% will be added when complete)
            if weakSelf.scanningProgress >= 0.95 {
                weakSelf.scanningProgress = 0.95
                timer.invalidate()
            }
        }
    }
    
    // Метод для остановки анимации прогресса
    private func stopProgressAnimation() {
        progressTimer?.invalidate()
        progressTimer = nil
        // Устанавливаем 100% прогресс
        self.scanningProgress = 1.0
    }
    
    // Вспомогательный метод для нормализации ориентации изображения
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
    
    private func handleRecognizedFoods(_ recognizedFoods: [RecognizedFood]) {
        if recognizedFoods.isEmpty {
            self.errorMessage = "Не удалось распознать продукт"
            return
        }
        
        // Берем первый распознанный продукт
        if let firstFood = recognizedFoods.first {
            // Create or get the Food object
            if let nutrition = firstFood.nutritionData {
                let foodItem = createOrGetFood(name: firstFood.name, nutritionInfo: nutrition)
                
                // Set recognized food and save image
                self.recognizedFood = foodItem
                if let originalImage = firstFood.originalImage,
                   let imageData = originalImage.jpegData(compressionQuality: 0.7) {
                    foodItem.imageData = imageData
                    do {
                        try context.save()
                        
                        // Сохраняем изображение в UserDefaults как резервную копию
                        if let id = foodItem.id, let name = foodItem.name {
                            let backupKey = "imageBackup_\(name)_\(id.uuidString)"
                            UserDefaults.standard.set(imageData, forKey: backupKey)
                            
                            // Обновляем информацию о продукте в UserDefaults
                            saveFoodToUserDefaults(foodItem)
                            
                            print("✅ Изображение для \(name) сохранено в CoreData и UserDefaults")
                        }
                    } catch {
                        print("❌ Error saving image data: \(error)")
                    }
                }
                
                // Add food to meal
                addFoodToMeal(food: foodItem)
                
                // Post notification that food analysis is complete
                NotificationCenter.default.post(name: Notification.Name.didCompleteFoodAnalysis, object: nil)
            } else {
                self.errorMessage = "Не удалось получить питательную ценность продукта"
            }
        } else {
            self.errorMessage = "Не удалось распознать продукт на изображении"
        }
    }
    
    // MARK: - Food Creation Methods
    
    private func createOrFetchFood(name: String, nutrition: NutritionInfo, image: Data?, completion: @escaping (Food) -> Void) {
        // Проверяем, существует ли уже такой продукт
        if let existingFood = getFoodByName(name: name) {
            // Используем существующий продукт
            completion(existingFood)
            return
        }
        
        // Создаем новый продукт
        let food = Food(context: context)
        food.id = UUID()
        food.name = name
        food.calories = nutrition.calories
        food.protein = nutrition.protein
        food.fat = nutrition.fat
        food.carbs = nutrition.carbs
        food.fiber = nutrition.fiber
        food.sugar = nutrition.sugar
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = nutrition.servingSize
        food.servingUnit = "г"
        
        // Сохраняем изображение, если оно есть
        if let imageData = image {
            food.imageData = imageData
        }
        
        // Сохраняем в базу данных
        do {
            try context.save()
            
            // Сохраняем в UserDefaults для персистентности
            saveFoodToUserDefaults(food)
            
            print("✅ Продукт \(name) сохранен в CoreData и UserDefaults")
            completion(food)
        } catch {
            print("❌ Ошибка при сохранении продукта: \(error)")
            
            // Если произошла ошибка, все равно возвращаем созданный объект, но без сохранения
            completion(food)
        }
    }
    
    private func createOrGetFood(name: String, nutritionInfo: NutritionData) -> Food {
        // Проверяем, существует ли уже такой продукт
        if let existingFood = getFoodByName(name: name) {
            return existingFood
        }
        
        // Создаем новый продукт
        let food = Food(context: context)
        food.id = UUID()
        food.name = name
        food.calories = nutritionInfo.calories
        food.protein = nutritionInfo.protein
        food.fat = nutritionInfo.fat
        food.carbs = nutritionInfo.carbs
        food.fiber = nutritionInfo.fiber ?? 0
        food.sugar = nutritionInfo.sugar ?? 0
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = 100
        food.servingUnit = "г"
        
        // Сохраняем в базу данных
        do {
            try context.save()
            
            // Сохраняем в UserDefaults для персистентности
            saveFoodToUserDefaults(food)
            
            print("✅ Продукт \(name) сохранен в CoreData и UserDefaults")
        } catch {
            print("❌ Ошибка при сохранении продукта: \(error)")
        }
        
        return food
    }
    
    // Добавляем отсутствующий метод для addRecognizedFoodToMeal
    private func addRecognizedFoodToMeal() {
        guard let food = self.analyzedFood else { return }
        addFoodToCurrentMeal(food: food)
    }
    
    // MARK: - Обработка успешного сканирования
    func handleSuccessfulScan(food: Food) {
        // Устанавливаем распознанную еду
        self.recognizedFood = food
        self.analyzedFood = food
        
        // Добавляем продукт в прием пищи и обновляем данные потребления
        addFoodToCurrentMeal(food: food)
        
        // Обновляем данные о потреблении на текущий день
        fetchTodayConsumption()
        
        // Завершаем анимацию прогресса
        stopProgressAnimation()
        
        // Имитируем задержку распознавания для лучшего UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Отправляем уведомления для обновления интерфейса
            NotificationCenter.default.post(name: Notification.Name.foodAnalyzedSuccessfully, object: nil)
            
            // Прекращаем анализ
            self.isAnalyzing = false
            self.isScanning = false
            self.scanningState = .success
            
            // Небольшая дополнительная задержка перед переходом на главный экран
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Закрываем камеру и возвращаемся на главный экран
                NavigationCoordinator.shared.showScanCamera = false
                
                // Отправляем уведомление о необходимости перехода на главный экран
                NotificationCenter.default.post(name: Notification.Name.navigateToHomeScreen, object: nil)
            }
        }
    }
    
    // Метод для создания Food из NutritionData
    private func createFoodFromNutritionData(name: String, nutritionData: NutritionData, image: UIImage? = nil) -> Food {
        // Проверяем, существует ли уже такой продукт
        if let existingFood = getFoodByName(name: name) {
            return existingFood
        }
        
        // Создаем новый продукт
        let food = Food(context: context)
        food.id = UUID()
        food.name = name
        food.calories = nutritionData.calories
        food.protein = nutritionData.protein
        food.fat = nutritionData.fat
        food.carbs = nutritionData.carbs
        food.fiber = nutritionData.fiber ?? 0
        food.sugar = nutritionData.sugar ?? 0
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = 100
        food.servingUnit = "г"
        
        // Сохраняем изображение, если оно есть
        if let imageData = image?.jpegData(compressionQuality: 0.7) {
            food.imageData = imageData
        }
        
        // Сохраняем в CoreData
        do {
            try context.save()
            
            // Также сохраняем продукт в UserDefaults для восстановления при перезапуске
            saveFoodToUserDefaults(food)
            
            print("✅ Продукт \(name) сохранен в CoreData и UserDefaults")
        } catch {
            print("❌ Ошибка при сохранении продукта: \(error)")
        }
        
        return food
    }
    
    // Сохраняем продукт в UserDefaults для восстановления при перезапуске
    private func saveFoodToUserDefaults(_ food: Food) {
        guard let id = food.id, let name = food.name else { return }
        
        // Explicitly mark as a single food item (not an ingredient)
        UserDefaults.standard.set(true, forKey: "single_food_\(id.uuidString)")
        
        // Получаем текущую историю еды
        var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        
        // Создаем запись для истории
        var foodDict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "calories": food.calories,
            "protein": food.protein,
            "carbs": food.carbs,
            "fat": food.fat,
            "servingSize": food.servingSize,
            "servingUnit": food.servingUnit ?? "г",
            "isFavorite": food.isFavorite,
            "createdAtTimestamp": (food.createdAt ?? Date()).timeIntervalSince1970,
            "hasImageData": food.imageData != nil && food.imageData!.count > 0,
            "isIngredient": food.isIngredient
        ]
        
        // Если у нас есть изображение, сохраняем его как резервную копию
        if let imageData = food.imageData, imageData.count > 0 {
            let backupKey = "imageBackup_\(name)_\(id.uuidString)"
            UserDefaults.standard.set(imageData, forKey: backupKey)
            print("✅ Сохранено резервное изображение для \(name) (размер: \(imageData.count) байт)")
            
            // Если это яблоко, дополнительно сохраняем как запасное изображение - ОТКЛЮЧЕНО
            // Предотвращаем появление яблок по умолчанию
            /*
            if name.lowercased() == "apple" {
                UserDefaults.standard.set(imageData, forKey: "lastAppleImage")
                print("🍎 Обновлено запасное изображение яблока (размер: \(imageData.count) байт)")
            }
            */
        } else {
            print("⚠️ У продукта \(name) отсутствует изображение")
        }
        
        // Проверяем, есть ли уже такой продукт в истории
        if let index = foodHistory.firstIndex(where: { ($0["id"] as? String) == id.uuidString }) {
            // Обновляем существующую запись
            foodHistory[index] = foodDict
            print("🔄 Обновлена запись продукта \(name) в истории UserDefaults")
        } else {
            // Добавляем новую запись в начало списка
            foodHistory.insert(foodDict, at: 0)
            print("➕ Добавлен новый продукт \(name) в историю UserDefaults")
        }
        
        // Ограничиваем количество записей
        let oldCount = foodHistory.count
        if foodHistory.count > 30 {
            foodHistory = Array(foodHistory.prefix(30))
            print("📊 История продуктов сокращена с \(oldCount) до \(foodHistory.count) записей")
        }
        
        // Сохраняем обновленную историю
        UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        
        // Также сохраняем ID последнего отсканированного продукта
        UserDefaults.standard.set(id.uuidString, forKey: "lastScannedFoodID")
        
        // Синхронизируем UserDefaults для гарантированного сохранения
        UserDefaults.standard.synchronize()
        
        print("✅ Продукт \(name) (ID: \(id.uuidString)) успешно сохранен в UserDefaults")
    }
}

// Убираем дублирующиеся объявления Notification.Name, так как они теперь в NSNotification+Extensions.swift
// MARK: - Notification Names
//extension Notification.Name {
//    static let didFinishFoodAnalysis = Notification.Name("didFinishFoodAnalysis")
//    static let didFinishBarcodeScanning = Notification.Name("didFinishBarcodeScanning")
//    static let didCancelFoodAnalysis = Notification.Name("didCancelFoodAnalysis")
//    static let foodAnalyzedSuccessfully = Notification.Name("FoodAnalyzedSuccessfully")
//}



