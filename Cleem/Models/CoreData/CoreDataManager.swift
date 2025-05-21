import CoreData
import Foundation
import UIKit

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {
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
        
        // Проверка модели данных при инициализации
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.verifyDataModel()
        }
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Cleem")
        
        // Настраиваем опции для предотвращения конфликтов с моделью
        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Use a more aggressive merge policy to resolve entity conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Make sure constraint conflicts are handled correctly
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        print("CoreData: Using aggressive merge policy to prevent entity conflicts")
        
        // Cleanup duplicate food entries on startup
        self.cleanupDuplicateFoodEntities(in: container.viewContext)
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                // Perform validation before saving
                for object in context.insertedObjects {
                    try object.validateForInsert()
                }
                for object in context.updatedObjects {
                    try object.validateForUpdate()
                }
                
                try context.save()
                print("CoreData: Context successfully saved")
            } catch {
                let nserror = error as NSError
                print("CoreData: Error saving context: \(nserror), \(nserror.userInfo)")
                
                // Try to resolve conflicts
                if let conflicts = nserror.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [NSMergeConflict] {
                    for conflict in conflicts {
                        context.refresh(conflict.sourceObject, mergeChanges: true)
                    }
                    
                    // Try saving again
                    do {
                        try context.save()
                        print("CoreData: Context saved after resolving conflicts")
                    } catch {
                        print("CoreData: Failed to save after resolving conflicts: \(error)")
                    }
                }
            }
        } else {
            print("CoreData: No changes to save")
        }
    }
    
    // Save the context when the app is about to terminate
    @objc private func saveContextOnTerminate() {
        print("CoreData: Приложение закрывается, сохраняем контекст")
        saveContext()
    }
    
    // Save the context when the app enters background
    @objc private func saveContextOnBackground() {
        print("CoreData: Приложение уходит в фон, сохраняем контекст")
        saveContext()
    }
    
    // Метод для создания демо-данных при первом запуске
    func setupDefaultData() {
        // Проверка, были ли уже созданы демо-данные
        let userDefaults = UserDefaults.standard
        let isDataInitialized = userDefaults.bool(forKey: "isDefaultDataInitialized")
        
        if !isDataInitialized {
            // Создаем тестовые данные
            createDemoFoods()
            
            // Отмечаем, что данные уже созданы
            userDefaults.set(true, forKey: "isDefaultDataInitialized")
            userDefaults.synchronize()
        }
    }
    
    // Создаем демо продукты
    private func createDemoFoods() {
        let demoFoods: [(name: String, calories: Double, protein: Double, carbs: Double, fat: Double)] = [
            // Удаляем яблоко из списка демо-продуктов
            // ("Apple", 52, 0.3, 14, 0.2),
            ("Banana", 89, 1.1, 23, 0.3),
            ("Chicken Breast", 165, 31, 0, 3.6),
            ("Oatmeal", 68, 2.4, 12, 1.4),
            ("Egg", 78, 6.3, 0.6, 5.3)
        ]
        
        for foodData in demoFoods {
            let food = Food(context: context)
            food.id = UUID()
            food.name = foodData.name
            food.calories = foodData.calories
            food.protein = foodData.protein
            food.carbs = foodData.carbs
            food.fat = foodData.fat
            food.createdAt = Date()
            food.servingSize = 100
            food.servingUnit = "г"
        }
        
        // Сохраняем созданные объекты
        saveContext()
    }
    
    // Метод для очистки дублирующихся записей Food
    private func cleanupDuplicateFoodEntities(in context: NSManagedObjectContext) {
        // Получаем все записи Food
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        do {
            let foods = try context.fetch(fetchRequest)
            
            // Создаем словарь для отслеживания уникальных имен и их первых встреченных объектов
            var uniqueNameMap: [String: Food] = [:]
            var duplicates: [Food] = []
            
            for food in foods {
                guard let name = food.name, !name.isEmpty else { continue }
                
                if uniqueNameMap[name] != nil {
                    // Это дубликат, добавляем в список для удаления
                    duplicates.append(food)
                } else {
                    // Это первый экземпляр с таким именем
                    uniqueNameMap[name] = food
                }
            }
            
            // Удаляем дубликаты
            for duplicate in duplicates {
                context.delete(duplicate)
            }
            
            // Сохраняем изменения
            if !duplicates.isEmpty {
                try context.save()
                print("Удалено \(duplicates.count) дублирующихся записей Food")
            }
            
        } catch {
            print("Ошибка при очистке дубликатов: \(error)")
        }
    }
    
    // Метод для проверки модели данных
    private func verifyDataModel() {
        print("CoreDataManager: Проверка модели данных...")
        
        do {
            // Проверяем, можем ли мы получить описание сущности Food
            let foodEntityDescription = NSEntityDescription.entity(forEntityName: "Food", in: self.context)
            
            if foodEntityDescription == nil {
                print("CoreDataManager: ОШИБКА - Сущность Food не найдена!")
            } else {
                print("CoreDataManager: Сущность Food успешно найдена в модели данных")
                
                // Пробуем загрузить существующие записи Food
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Food")
                let count = try context.count(for: fetchRequest)
                print("CoreDataManager: В базе данных найдено \(count) записей Food")
                
                // Не создаем демо-запись при инициализации, чтобы предотвратить
                // появление яблока по умолчанию в Recently Logged
                if count == 0 {
                    print("CoreDataManager: База данных пуста, но мы не создаем демо-запись Apple для предотвращения появления по умолчанию")
                    // Раньше здесь создавалась демо-запись "Apple", которая появлялась в Recently Logged
                }
            }
        } catch {
            print("CoreDataManager: ОШИБКА при проверке модели данных: \(error)")
        }
    }
    
    // Метод для сохранения еды в UserDefaults (аналогично активностям)
    func saveFoodToUserDefaults(food: Food) {
        // Skip ingredients - don't save them to UserDefaults history
        if food.isIngredient {
            print("CoreDataManager: Пропускаем сохранение в UserDefaults для ингредиента: \(food.name ?? "Unknown")")
            return
        }
        
        print("CoreDataManager: Сохраняем еду в UserDefaults: \(food.name ?? "Unknown")")
        
        guard let foodId = food.id else {
            print("CoreDataManager: Ошибка - у еды нет ID")
            return
        }
        
        // Explicitly mark as a single food item (not an ingredient)
        UserDefaults.standard.set(true, forKey: "single_food_\(foodId.uuidString)")
        
        // Преобразуем Date в TimeInterval для надежного хранения в UserDefaults
        // Always use current time to ensure newly added items appear at the top
        let createdAtTimestamp = Date().timeIntervalSince1970
        
        // Update the food's createdAt to match what we're storing in UserDefaults
        food.createdAt = Date()
        
        // Проверяем, есть ли изображение и оно не пустое
        let hasImageData = food.imageData != nil && food.imageData!.count > 0
        
        if hasImageData {
            print("CoreDataManager: 📸 Продукт \(food.name ?? "Unknown") имеет изображение размером \(food.imageData!.count) байт")
            
            // Проверяем, что изображение может быть прочитано как UIImage
            if let imageData = food.imageData, UIImage(data: imageData) != nil {
                print("CoreDataManager: ✅ Изображение для \(food.name ?? "Unknown") валидно и может быть отображено")
            } else {
                print("CoreDataManager: ⚠️ Изображение для \(food.name ?? "Unknown") не может быть прочитано как UIImage!")
            }
        } else {
            print("CoreDataManager: ⚠️ Продукт \(food.name ?? "Unknown") не имеет изображения")
        }
        
        // Создаем словарь с данными о еде
        var foodData: [String: Any] = [
            "id": foodId.uuidString,
            "name": food.name ?? "Unknown",
            "calories": food.calories,
            "protein": food.protein,
            "carbs": food.carbs,
            "fat": food.fat,
            "createdAtTimestamp": createdAtTimestamp, // Используем текущее время
            "servingSize": food.servingSize,
            "servingUnit": food.servingUnit ?? "г",
            "isFavorite": food.isFavorite,
            "hasImageData": hasImageData, // Добавляем флаг наличия изображения
            "isIngredient": false // Explicitly mark as not an ingredient
        ]
        
        // Получаем существующую историю еды или создаем новую
        var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        
        print("CoreDataManager: Текущая история (до): \(foodHistory.count) записей")
        
        // Удаляем существующие записи с тем же ID
        foodHistory.removeAll { existingFood in
            if let existingId = existingFood["id"] as? String {
                return existingId == foodId.uuidString
            }
            return false
        }
        
        // Always add at the beginning of the array to ensure it appears first
        foodHistory.insert(foodData, at: 0)
        
        // Ограничиваем размер истории
        if foodHistory.count > 50 {
            foodHistory = Array(foodHistory.prefix(50))
        }
        
        print("CoreDataManager: Текущая история (после): \(foodHistory.count) записей")
        
        // Сохраняем обновленную историю
        UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        UserDefaults.standard.set(foodId.uuidString, forKey: "lastScannedFoodID")
        UserDefaults.standard.synchronize()
        
        // Дополнительно, сохраняем в CoreData для поддержки изображений
        let context = self.context
        
        // Обновляем изображение в CoreData, если у объекта есть изображение
        if hasImageData {
            // Ищем объект в CoreData по ID
            let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", foodId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let foods = try context.fetch(fetchRequest)
                if let existingFood = foods.first {
                    // Обновляем изображение, если оно есть
                    if existingFood.imageData == nil || existingFood.imageData!.isEmpty {
                        existingFood.imageData = food.imageData
                        print("CoreDataManager: ✅ Обновлено изображение для существующего продукта \(existingFood.name ?? "Unknown") в CoreData")
                    }
                    
                    // Update the createdAt timestamp
                    existingFood.createdAt = Date()
                } else {
                    // Создаем новый объект в CoreData
                    let newFood = Food(context: context)
                    newFood.id = foodId
                    newFood.name = food.name
                    newFood.calories = food.calories
                    newFood.protein = food.protein
                    newFood.carbs = food.carbs
                    newFood.fat = food.fat
                    newFood.createdAt = Date() // Current time for new food
                    newFood.servingSize = food.servingSize
                    newFood.servingUnit = food.servingUnit
                    newFood.isFavorite = food.isFavorite
                    newFood.imageData = food.imageData
                    print("CoreDataManager: ✅ Создан новый продукт \(newFood.name ?? "Unknown") с изображением в CoreData")
                }
                
                // Сохраняем контекст
                try context.save()
                print("CoreDataManager: ✅ Контекст CoreData успешно сохранен")
            } catch {
                print("CoreDataManager: ⚠️ Ошибка при обновлении продукта в CoreData: \(error)")
            }
        }
        
        // Проверяем, успешно ли сохранилось
        let savedHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        let savedLastId = UserDefaults.standard.string(forKey: "lastScannedFoodID") ?? "nil"
        
        print("CoreDataManager: После сохранения: \(savedHistory.count) записей, lastScannedFoodID = \(savedLastId)")
        
        // Отправляем уведомление об обновлении истории еды
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            print("CoreDataManager: Отправлено уведомление FoodUpdated")
        }
        
        print("CoreDataManager: Еда успешно сохранена в UserDefaults и CoreData, ID: \(foodId.uuidString)")
    }
    
    func getFoodWithImage(id: UUID) -> Food? {
        print("CoreDataManager: Получаем продукт с изображением по ID: \(id.uuidString)")
        
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let foods = try context.fetch(fetchRequest)
            guard let food = foods.first else {
                print("CoreDataManager: ❌ Продукт с ID \(id.uuidString) не найден")
                return nil
            }
            
            // Проверяем наличие валидного изображения
            if let imageData = food.imageData, imageData.count >= 50, UIImage(data: imageData) != nil {
                print("CoreDataManager: ✅ Продукт имеет валидное изображение размером \(imageData.count) байт")
                return food
            }
            
            // Изображение отсутствует или повреждено - пробуем найти резервную копию
            print("CoreDataManager: ⚠️ Продукт существует, но без валидного изображения")
            
            // Если это яблоко, проверяем специальный бэкап - ОТКЛЮЧЕНО
            // Предотвращаем появление яблок по умолчанию
            /*
            if food.name?.lowercased() == "apple",
               let appleData = UserDefaults.standard.data(forKey: "lastAppleImage"),
               let appleImage = UIImage(data: appleData) {
                print("CoreDataManager: 🍎 Найдено запасное изображение яблока размером \(appleData.count) байт")
                food.imageData = appleData
                saveContext()
                return food
            }
            */
            
            // Ищем резервную копию в UserDefaults по шаблону ключа
            if let name = food.name {
                let prefix = "imageBackup_\(name)_"
                let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
                
                for key in userDefaultsKeys where key.hasPrefix(prefix) {
                    if let backupData = UserDefaults.standard.data(forKey: key),
                       backupData.count >= 100,
                       let _ = UIImage(data: backupData) {
                        print("CoreDataManager: ✅ Найдено резервное изображение по ключу \(key)")
                        food.imageData = backupData
                        saveContext()
                        return food
                    }
                }
            }
            
            // Не найдено резервное изображение
            print("CoreDataManager: ❌ Резервное изображение не найдено")
            return food
            
        } catch {
            print("CoreDataManager: ❌ Ошибка при поиске продукта: \(error)")
            return nil
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Food Synchronization

    // Synchronize all food data between CoreData and UserDefaults
    func synchronizeAllFoodData() {
        print("\n===== SYNCHRONIZING ALL FOOD DATA =====")
        
        // 1. First, ensure UserDefaults food history exists
        if UserDefaults.standard.object(forKey: "foodHistory") == nil {
            print("Creating empty foodHistory in UserDefaults")
            UserDefaults.standard.set([], forKey: "foodHistory")
        }
        
        // 2. Get all foods from CoreData
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let foods = try context.fetch(fetchRequest)
            print("Found \(foods.count) foods in CoreData")
            
            // 3. Get current food history from UserDefaults
            var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
            
            // 4. Check for integrity of UserDefaults data
            let foodsInUserDefaults = foodHistory.compactMap { $0["id"] as? String }
            print("Found \(foodsInUserDefaults.count) foods in UserDefaults history")
            
            // 5. Sync CoreData to UserDefaults
            var updatedFoodHistory = foodHistory
            var newItemsCount = 0
            
            for food in foods {
                guard let id = food.id?.uuidString, let name = food.name else { continue }
                
                // Skip ingredients
                if food.isIngredient {
                    continue
                }
                
                // Check if this food exists in UserDefaults
                if !foodsInUserDefaults.contains(id) {
                    // Add missing food to UserDefaults
                    let foodData: [String: Any] = [
                        "id": id,
                        "name": name,
                        "calories": food.calories,
                        "protein": food.protein,
                        "carbs": food.carbs,
                        "fat": food.fat,
                        "createdAtTimestamp": (food.createdAt ?? Date()).timeIntervalSince1970,
                        "servingSize": food.servingSize,
                        "servingUnit": food.servingUnit ?? "г",
                        "isFavorite": food.isFavorite,
                        "hasImageData": food.imageData != nil && food.imageData!.count > 0,
                        "isIngredient": false
                    ]
                    
                    // Add to UserDefaults food history
                    updatedFoodHistory.append(foodData)
                    newItemsCount += 1
                    
                    print("Added missing food to UserDefaults: \(name)")
                }
            }
            
            // Sort by timestamp
            updatedFoodHistory.sort {
                let timestamp1 = $0["createdAtTimestamp"] as? Double ?? 0
                let timestamp2 = $1["createdAtTimestamp"] as? Double ?? 0
                return timestamp1 > timestamp2
            }
            
            // Save if changes were made
            if newItemsCount > 0 {
                UserDefaults.standard.set(updatedFoodHistory, forKey: "foodHistory")
                print("Added \(newItemsCount) missing foods to UserDefaults")
            }
            
            // 6. Sync combined foods
            syncCombinedFoods()
            
            // 7. Force synchronize UserDefaults
            UserDefaults.standard.synchronize()
            
            // 8. Notify UI to update
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
            
        } catch {
            print("Error synchronizing food data: \(error)")
        }
        
        print("===== FOOD DATA SYNCHRONIZATION COMPLETED =====\n")
    }
    
    // Helper method to synchronize combined foods
    private func syncCombinedFoods() {
        // Get combined foods from UserDefaults
        let combinedFoods = UserDefaults.standard.array(forKey: "combinedFoods") as? [[String: Any]] ?? []
        
        if combinedFoods.isEmpty {
            print("No combined foods found in UserDefaults")
            return
        }
        
        print("Synchronizing \(combinedFoods.count) combined foods")
        
        // Get deletion lists
        let deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        
        // Find any combined foods that might be in the deletion list but still present
        var needsUpdate = false
        var validCombinedFoods = combinedFoods
        
        // Remove any that are in the deletion list
        validCombinedFoods.removeAll { item in
            if let id = item["id"] as? String, deletedIds.contains(id) {
                needsUpdate = true
                print("Removed deleted combined food with ID: \(id)")
                return true
            }
            return false
        }
        
        // Make sure all combined foods have valid ingredients
        for (index, food) in validCombinedFoods.enumerated() {
            if let ingredients = food["ingredientsDetails"] as? [[String: Any]] {
                // Check that ingredients exist
                if ingredients.isEmpty {
                    validCombinedFoods.remove(at: index)
                    needsUpdate = true
                    print("Removed combined food with no ingredients")
                }
            } else {
                // Invalid format - no ingredients details
                validCombinedFoods.remove(at: index)
                needsUpdate = true
                print("Removed combined food with invalid format")
            }
        }
        
        // Update UserDefaults if changes were made
        if needsUpdate {
            UserDefaults.standard.set(validCombinedFoods, forKey: "combinedFoods")
            print("Updated combined foods in UserDefaults")
        }
    }
    
    // MARK: - Food Management
    
    // Save a food item to be shown in Recently Logged
    func saveFoodItem(food: Food) {
        guard let foodId = food.id else {
            print("ERROR: Cannot save food without ID")
            return
        }
        
        print("=== SAVING FOOD ITEM: \(food.name ?? "Unknown") ===")
        
        // 1. Проверяем, есть ли у продукта ингредиенты
        let hasIngredients = (food.ingredients?.count ?? 0) > 0
        
        if hasIngredients {
            print("Продукт имеет \(food.ingredients?.count ?? 0) ингредиентов - это составное блюдо")
        }
        
        // 2. Однозначно отмечаем, что это не ингредиент (для отображения в UI)
        UserDefaults.standard.set(true, forKey: "single_food_\(foodId.uuidString)")
        UserDefaults.standard.set(false, forKey: "food_ingredient_\(foodId.uuidString)")
        food.isIngredient = false
        
        // 3. Удаляем из всех списков удаленных продуктов
        removeFromDeletionLists(id: foodId.uuidString)
        
        // 4. Отмечаем как последний отсканированный продукт
        UserDefaults.standard.set(foodId.uuidString, forKey: "lastScannedFoodID")
        
        // 5. Обновляем временную метку для правильной сортировки
        food.createdAt = Date()
        
        // 6. Создаем запись для истории продуктов
        var foodData: [String: Any] = [
            "id": foodId.uuidString,
            "name": food.name ?? "Unknown",
            "calories": food.calories,
            "protein": food.protein,
            "carbs": food.carbs,
            "fat": food.fat,
            "createdAtTimestamp": Date().timeIntervalSince1970,
            "servingSize": food.servingSize,
            "servingUnit": food.servingUnit ?? "г",
            "isFavorite": food.isFavorite,
            "hasImageData": food.imageData != nil && food.imageData!.count > 0,
            "isIngredient": false
        ]
        
        // Добавляем информацию об ингредиентах, если они есть
        if hasIngredients {
            foodData["hasIngredients"] = true
            foodData["ingredientsCount"] = food.ingredients?.count ?? 0
            
            // Добавляем список названий ингредиентов
            if let ingredients = food.ingredients as? Set<Ingredient> {
                var ingredientNames: [String] = []
                for ingredient in ingredients {
                    if let name = ingredient.name {
                        ingredientNames.append(name)
                    }
                }
                foodData["ingredientNames"] = ingredientNames
            }
        }
        
        // 7. Обновляем историю продуктов
        var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        
        // Удаляем существующую запись с тем же ID (если есть)
        foodHistory.removeAll { ($0["id"] as? String) == foodId.uuidString }
        
        // Добавляем в начало и ограничиваем размер
        foodHistory.insert(foodData, at: 0)
        if foodHistory.count > 50 {
            foodHistory = Array(foodHistory.prefix(50))
        }
        
        UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        
        // 8. Сохраняем резервную копию изображения
        if let imageData = food.imageData, imageData.count > 0, let name = food.name {
            let backupKey = "imageBackup_\(name)_\(foodId.uuidString)"
            UserDefaults.standard.set(imageData, forKey: backupKey)
            print("✅ Создана резервная копия изображения для \(name) (\(imageData.count) байт)")
        }
        
        // 9. Сохраняем в CoreData
        do {
            try context.save()
            print("✅ Продукт сохранен в CoreData")
        } catch {
            print("❌ Ошибка сохранения продукта в CoreData: \(error)")
        }
        
        // 10. Принудительная синхронизация и оповещение
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        }
        
        print("=== FOOD SAVED SUCCESSFULLY ===")
    }
    
    // Delete a food item
    func deleteFoodItem(id: UUID) {
        let idString = id.uuidString
        print("\n=== DELETING FOOD: \(idString) ===")
        
        // 1. Полностью удаляем продукт из всех списков в UserDefaults
        removeFromFoodHistory(id: idString)
        addToDeletionLists(id: idString, name: lookupFoodName(id: id))
        
        // 2. Удаляем все связанные с продуктом метки в UserDefaults
        let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in userDefaultsKeys {
            if key.contains(idString) ||
               key.hasSuffix("_\(idString)") ||
               key.contains("food_\(idString)") ||
               key.contains("imageBackup") && key.contains(idString) {
                UserDefaults.standard.removeObject(forKey: key)
                print("✅ Удален ключ из UserDefaults: \(key)")
            }
        }
        
        // 3. Удаляем из списка последних отсканированных продуктов
        if UserDefaults.standard.string(forKey: "lastScannedFoodID") == idString {
            UserDefaults.standard.removeObject(forKey: "lastScannedFoodID")
        }
        
        // 4. Физически удаляем из CoreData
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let food = results.first {
                // Сохраняем имя для логирования
                let foodName = food.name ?? "Unknown"
                
                // Сначала отвязываем все связи
                if let mealFoods = food.mealFoods as? Set<MealFood> {
                    for mealFood in mealFoods {
                        context.delete(mealFood)
                    }
                }
                
                if let ingredients = food.ingredients as? Set<Ingredient> {
                    for ingredient in ingredients {
                        context.delete(ingredient)
                    }
                }
                
                // Теперь удаляем сам продукт
                context.delete(food)
                
                // Сохраняем изменения
                try context.save()
                
                print("✅ Продукт физически удален из CoreData: \(foodName)")
            } else {
                print("⚠️ Продукт с ID \(idString) не найден в CoreData")
            }
        } catch {
            print("❌ Ошибка при удалении продукта из CoreData: \(error)")
        }
        
        // 5. Синхронизируем UserDefaults и отправляем уведомление об обновлении
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        }
        
        print("=== FOOD DELETED SUCCESSFULLY ===\n")
    }
    
    // Delete a combined food
    func deleteCombinedFood(id: UUID, ingredients: [Food]) {
        let idString = id.uuidString
        print("\n=== DELETING COMBINED FOOD: \(idString) with \(ingredients.count) ingredients ===")
        
        // 1. Add to deleted combined foods list
        var deletedCombinedFoodIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        if !deletedCombinedFoodIds.contains(idString) {
            deletedCombinedFoodIds.append(idString)
            UserDefaults.standard.set(deletedCombinedFoodIds, forKey: "deletedCombinedFoods")
        }
        
        // 2. Process all ingredients
        for ingredient in ingredients {
            if let ingredientId = ingredient.id {
                let ingredientIdString = ingredientId.uuidString
                
                // 2.1 Mark as ingredient in UserDefaults
                UserDefaults.standard.set(true, forKey: "food_ingredient_\(ingredientIdString)")
                UserDefaults.standard.set(false, forKey: "single_food_\(ingredientIdString)")
                
                // 2.2 Mark as ingredient in CoreData
                ingredient.isIngredient = true
                
                // 2.3 Add to deletion lists for complete tracking
                addToDeletionLists(id: ingredientIdString, name: ingredient.name)
            }
        }
        
        // 3. Save CoreData changes
        do {
            try context.save()
            print("✅ All ingredients updated in CoreData")
        } catch {
            print("❌ Error updating ingredients in CoreData: \(error)")
        }
        
        // 4. Remove from any food history lists
        removeFromFoodHistory(id: idString)
        
        // 5. Remove all associated data
        let imageKey = "combinedFoodImage_\(idString)"
        let backupKey = "combinedFoodBackup_\(idString)"
        UserDefaults.standard.removeObject(forKey: imageKey)
        UserDefaults.standard.removeObject(forKey: backupKey)
        
        // 6. Force synchronize and notify
        UserDefaults.standard.synchronize()
        
        // 7. Send multiple notifications for different parts of the app to handle
        DispatchQueue.main.async {
            // First notify about general food update
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            
            // Then specifically notify about this combined food deletion
            NotificationCenter.default.post(
                name: NSNotification.Name("CombinedFoodDeleted"),
                object: nil,
                userInfo: ["id": idString]
            )
        }
        
        print("=== COMBINED FOOD DELETED SUCCESSFULLY ===\n")
    }
    
    // MARK: - Helper methods
    
    // Add ID to deletion lists
    private func addToDeletionLists(id: String, name: String?) {
        // Add to deletedFoodItems
        var deletedFoodIds = UserDefaults.standard.array(forKey: "deletedFoodItems") as? [String] ?? []
        if !deletedFoodIds.contains(id) {
            deletedFoodIds.append(id)
            UserDefaults.standard.set(deletedFoodIds, forKey: "deletedFoodItems")
        }
        
        // Add to permanentlyDeletedIngredients
        var permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] ?? [:]
        permanentlyDeletedIngredients[id] = name ?? "Unknown"
        UserDefaults.standard.set(permanentlyDeletedIngredients, forKey: "permanentlyDeletedIngredients")
    }
    
    // Remove ID from deletion lists
    private func removeFromDeletionLists(id: String) {
        // Remove from deletedFoodItems
        var deletedFoodIds = UserDefaults.standard.array(forKey: "deletedFoodItems") as? [String] ?? []
        deletedFoodIds.removeAll { $0 == id }
        UserDefaults.standard.set(deletedFoodIds, forKey: "deletedFoodItems")
        
        // Remove from permanentlyDeletedIngredients
        var permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] ?? [:]
        permanentlyDeletedIngredients.removeValue(forKey: id)
        UserDefaults.standard.set(permanentlyDeletedIngredients, forKey: "permanentlyDeletedIngredients")
        
        // Remove from deletedCombinedFoods
        var deletedCombinedFoodIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        deletedCombinedFoodIds.removeAll { $0 == id }
        UserDefaults.standard.set(deletedCombinedFoodIds, forKey: "deletedCombinedFoods")
    }
    
    // Remove from food history
    private func removeFromFoodHistory(id: String) {
        var foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] ?? []
        let initialCount = foodHistory.count
        
        foodHistory.removeAll { ($0["id"] as? String) == id }
        
        if initialCount != foodHistory.count {
            UserDefaults.standard.set(foodHistory, forKey: "foodHistory")
        }
    }
    
    // Look up a food's name by ID
    private func lookupFoodName(id: UUID) -> String {
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.name ?? "Unknown"
        } catch {
            return "Unknown"
        }
    }
    
    // Remove from all deletion lists related to combined foods
    public func purgeAllDataForCombinedFood(id: UUID) {
        let idString = id.uuidString
        print("\n=== PURGING ALL DATA FOR COMBINED FOOD: \(idString) ===")
        
        // 1. Remove all UserDefaults data with this ID
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        var removedKeyCount = 0
        
        for key in allKeys {
            if key.contains(idString) {
                UserDefaults.standard.removeObject(forKey: key)
                removedKeyCount += 1
                print("✅ Removed key from UserDefaults: \(key)")
            }
        }
        
        // 2. Ensure it's in deletion lists
        var deletedCombinedFoodIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        if !deletedCombinedFoodIds.contains(idString) {
            deletedCombinedFoodIds.append(idString)
            UserDefaults.standard.set(deletedCombinedFoodIds, forKey: "deletedCombinedFoods")
            print("✅ Added to deletedCombinedFoods list")
        }
        
        // 3. Force synchronize
        UserDefaults.standard.synchronize()
        
        print("=== PURGE COMPLETE: Removed \(removedKeyCount) keys ===\n")
    }
}

// Логгер для CoreData (только для отладки)
#if DEBUG
class CoreDataLogger {
    static func setup() {
        // Включаем логирование SQL запросов
        UserDefaults.standard.set(true, forKey: "com.apple.CoreData.SQLDebug")
        UserDefaults.standard.set(true, forKey: "com.apple.CoreData.Logging.stderr")
    }
}
#endif




