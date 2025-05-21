import Foundation
import UIKit
import CoreData

// Model representing a combined dish with multiple ingredients
class CombinedFoodItem: NSObject, Identifiable {
    let id: UUID
    var name: String
    var originalName: String?
    var ingredients: [Food] {
        didSet {
            // При изменении списка ингредиентов, обновляем значения питательных веществ
            updateNutritionValues()
            
            // Сохраняем обновленное блюдо
            CombinedFoodManager.shared.ensureBackupExists(self)
            
            // Отправляем уведомление об обновлении
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        }
    }
    var createdAt: Date
    var imageData: Data?
    
    // Сохраняем кэшированные значения для питательных веществ
    private var _calories: Double = 0
    private var _protein: Double = 0
    private var _carbs: Double = 0
    private var _fat: Double = 0
    
    // Инициализируем кэшированные значения при создании объекта
    private func updateNutritionValues() {
        _calories = ingredients.reduce(0) { $0 + $1.calories }
        _protein = ingredients.reduce(0) { $0 + $1.protein }
        _carbs = ingredients.reduce(0) { $0 + $1.carbs }
        _fat = ingredients.reduce(0) { $0 + $1.fat }
    }
    
    // Computed properties based on ingredients using cached values
    var calories: Double {
        get { return _calories }
    }
    
    var protein: Double {
        get { return _protein }
    }
    
    var carbs: Double {
        get { return _carbs }
    }
    
    var fat: Double {
        get { return _fat }
    }
    
    init(id: UUID = UUID(), name: String, ingredients: [Food], createdAt: Date = Date(), imageData: Data? = nil, originalName: String? = nil) {
        self.id = id
        self.name = name
        self.originalName = originalName
        self.ingredients = ingredients
        self.createdAt = createdAt
        self.imageData = imageData
        
        super.init()
        
        // Инициализируем кэшированные значения
        updateNutritionValues()
        
        // Удаляем вызов createBackup из конструктора
        // Резервная копия будет создаваться в CombinedFoodManager
    }
    
    // Converts the CombinedFoodItem to a dictionary for storage in UserDefaults
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "createdAtTimestamp": createdAt.timeIntervalSince1970,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat,
            "isCombined": true,
            "hasImageData": imageData != nil && imageData!.count > 0
        ]
        
        // Сохраняем originalName если он есть
        if let originalName = originalName {
            dict["originalName"] = originalName
        }
        
        // Store ingredient IDs
        let ingredientIds = ingredients.compactMap { $0.id?.uuidString }
        dict["ingredientIds"] = ingredientIds
        
        // Store detailed information about ingredients for backup
        var ingredientsDetails: [[String: Any]] = []
        for ingredient in ingredients {
            guard let id = ingredient.id?.uuidString else { continue }
            
            var ingredientDict: [String: Any] = [
                "id": id,
                "name": ingredient.name ?? "Unknown",
                "calories": ingredient.calories,
                "protein": ingredient.protein,
                "carbs": ingredient.carbs,
                "fat": ingredient.fat
            ]
            
            if let createdAt = ingredient.createdAt {
                ingredientDict["createdAtTimestamp"] = createdAt.timeIntervalSince1970
            }
            
            ingredientsDetails.append(ingredientDict)
        }
        dict["ingredientsDetails"] = ingredientsDetails
        
        return dict
    }
    
    // Create a CombinedFoodItem from a dictionary
    static func from(dictionary: [String: Any], context: NSManagedObjectContext) -> CombinedFoodItem? {
        guard
            let idString = dictionary["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = dictionary["name"] as? String,
            let ingredientIds = dictionary["ingredientIds"] as? [String],
            let timestamp = dictionary["createdAtTimestamp"] as? Double else {
            print("❌ Ошибка восстановления комбинированного блюда: отсутствуют обязательные поля")
            
            // Пытаемся найти резервную копию
            if let idString = dictionary["id"] as? String,
               let backupData = UserDefaults.standard.data(forKey: "combinedFoodBackup_\(idString)"),
               let backupDict = try? JSONSerialization.jsonObject(with: backupData, options: []) as? [String: Any] {
                print("✅ Найдена резервная копия блюда, пробуем восстановить её")
                return from(dictionary: backupDict, context: context)
            }
            
            return nil
        }
        
        // Получаем originalName если он есть
        let originalName = dictionary["originalName"] as? String
        
        // Проверяем, не удалено ли это блюдо
        let deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        if deletedIds.contains(idString) {
            print("⚠️ Блюдо \(name) (ID: \(idString)) было ранее удалено, пропускаем восстановление")
            return nil
        }
        
        // Fetch all the ingredients from CoreData
        var ingredients: [Food] = []
        var missingIngredients: [String] = []
        
        for idString in ingredientIds {
            if let uuid = UUID(uuidString: idString) {
                let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                fetchRequest.fetchLimit = 1
                
                do {
                    let results = try context.fetch(fetchRequest)
                    if let ingredient = results.first {
                        // Проверяем, не помечен ли этот ингредиент как полностью удаленный
                        let permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] ?? [:]
                        if permanentlyDeletedIngredients[idString] != nil {
                            print("⚠️ Ингредиент \(ingredient.name ?? "Unknown") (ID: \(idString)) находится в списке удаленных ингредиентов")
                            // Все равно добавляем, чтобы блюдо могло загрузиться
                        }
                        
                        ingredients.append(ingredient)
                        
                        // Убедимся, что ингредиент помечен как ингредиент
                        ingredient.isIngredient = true
                        
                        // Сохраняем маркер ингредиента в UserDefaults для надежности
                        UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                    } else {
                        missingIngredients.append(idString)
                        print("⚠️ Ингредиент с ID \(idString) не найден в CoreData")
                    }
                } catch {
                    print("❌ Ошибка при загрузке ингредиента: \(error)")
                    missingIngredients.append(idString)
                }
            } else {
                print("❌ Некорректный UUID ингредиента: \(idString)")
                missingIngredients.append(idString)
            }
        }
        
        // Если есть отсутствующие ингредиенты, пробуем восстановить их из деталей
        if !missingIngredients.isEmpty {
            print("⚠️ Отсутствуют некоторые ингредиенты в CoreData. Пробуем восстановить из резервной информации...")
            
            if let ingredientsDetails = dictionary["ingredientsDetails"] as? [[String: Any]] {
                // Создаем временные ингредиенты из информации в словаре
                for detailDict in ingredientsDetails {
                    guard
                        let idString = detailDict["id"] as? String,
                        let name = detailDict["name"] as? String,
                        missingIngredients.contains(idString),  // Восстанавливаем только отсутствующие
                        let uuid = UUID(uuidString: idString) else {
                        continue
                    }
                    
                    // Проверяем, не помечен ли этот ингредиент как полностью удаленный
                    let permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] ?? [:]
                    if permanentlyDeletedIngredients[idString] != nil {
                        print("⚠️ Пропускаем восстановление ингредиента \(name) (ID: \(idString)), так как он находится в списке удаленных")
                        continue
                    }
                    
                    // Создаем новый объект Food в CoreData
                    let newIngredient = Food(context: context)
                    newIngredient.id = uuid
                    newIngredient.name = name
                    newIngredient.calories = detailDict["calories"] as? Double ?? 0
                    newIngredient.protein = detailDict["protein"] as? Double ?? 0
                    newIngredient.carbs = detailDict["carbs"] as? Double ?? 0
                    newIngredient.fat = detailDict["fat"] as? Double ?? 0
                    
                    // Восстановление времени создания
                    if let timestamp = detailDict["createdAtTimestamp"] as? Double {
                        newIngredient.createdAt = Date(timeIntervalSince1970: timestamp)
                    } else {
                        newIngredient.createdAt = Date()
                    }
                    
                    // Помечаем как ингредиент
                    newIngredient.isIngredient = true
                    UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                    
                    // Добавляем в список ингредиентов
                    ingredients.append(newIngredient)
                    
                    print("✅ Восстановлен ингредиент \(name) из резервной информации")
                }
                
                // Сохраняем восстановленные ингредиенты в CoreData
                do {
                    try context.save()
                    print("✅ Восстановленные ингредиенты сохранены в CoreData")
                } catch {
                    print("❌ Ошибка при сохранении восстановленных ингредиентов: \(error)")
                }
            } else {
                print("❌ Нет резервной информации об ингредиентах")
            }
        }
        
        // Only proceed if we have at least one ingredient
        if ingredients.isEmpty {
            print("❌ Не удалось восстановить комбинированное блюдо \(name) (ID: \(idString)): нет ни одного ингредиента")
            return nil
        }
        
        if !missingIngredients.isEmpty {
            print("⚠️ Некоторые ингредиенты не удалось найти: \(missingIngredients.joined(separator: ", "))")
        }
        
        print("✅ Восстановлено комбинированное блюдо \(name) с \(ingredients.count) ингредиентами")
        
        // Try to restore image if there was one
        var imageData: Data? = nil
        if let hasImage = dictionary["hasImageData"] as? Bool, hasImage {
            let imageKey = "combinedFoodImage_\(idString)"
            imageData = UserDefaults.standard.data(forKey: imageKey)
            if imageData == nil || imageData!.isEmpty {
                print("⚠️ Комбинированное блюдо \(name) должно иметь изображение, но оно не было восстановлено")
            } else {
                print("✅ Повторно восстановлено изображение для \(name)")
            }
        }
        
        let createdAt = Date(timeIntervalSince1970: timestamp)
        
        // Create the combined food item
        let combinedFood = CombinedFoodItem(
            id: id,
            name: name,
            ingredients: ingredients,
            createdAt: createdAt,
            imageData: imageData,
            originalName: originalName
        )
        
        // Создаем резервную копию через менеджер
        CombinedFoodManager.shared.ensureBackupExists(combinedFood)
        
        return combinedFood
    }
}



