import Foundation
import UIKit
import CoreData

class CombinedFoodManager {
    static let shared = CombinedFoodManager()
    
    // Key for storing combined foods in UserDefaults
    private let combinedFoodsKey = "combinedFoods"
    
    // CoreData context
    private let context = CoreDataManager.shared.context
    
    private init() {
        // Empty private initializer for singleton
        
        // Initialize the combined foods list if it doesn't exist
        if UserDefaults.standard.object(forKey: combinedFoodsKey) == nil {
            UserDefaults.standard.set([], forKey: combinedFoodsKey)
            UserDefaults.standard.synchronize()
            print("CombinedFoodManager: Initialized empty combined foods list")
        }
        
        // Check for and remove invalid combined foods
        cleanupInvalidCombinedFoods()
    }
    
    // Create a combined food item from multiple ingredients
    func createCombinedFood(name: String, ingredients: [Food], image: UIImage? = nil) -> CombinedFoodItem {
        print("\n===== СОЗДАНИЕ КОМБИНИРОВАННОГО БЛЮДА =====")
        print("Создаем комбинированное блюдо \(name) с \(ingredients.count) ингредиентами")
        
        // Create a new CombinedFoodItem instance
        let combinedFoodItem = CombinedFoodItem(
            name: name,
            ingredients: ingredients
        )
        
        // Ensure all ingredients are marked as ingredients in UserDefaults
        for ingredient in ingredients {
            // Устанавливаем флаг в CoreData объекте
            ingredient.isIngredient = true
            
            // ВАЖНО: также сохраняем маркер в UserDefaults для каждого ингредиента
            if let id = ingredient.id {
                let key = "food_ingredient_\(id.uuidString)"
                UserDefaults.standard.set(true, forKey: key)
                print("✅ Ингредиент \(ingredient.name ?? "Unknown") (ID: \(id.uuidString)) помечен в UserDefaults [\(key)]")
            }
        }
        
        // Важно: сохраняем контекст CoreData для сохранения изменений
        do {
            try context.save()
            print("✅ Все ингредиенты сохранены в CoreData")
        } catch {
            print("❌ Ошибка при сохранении ингредиентов в CoreData: \(error)")
        }
        
        // Force synchronize to ensure all markers are saved
        UserDefaults.standard.synchronize()
        
        // Process and store the image if available
        if let image = image {
            combinedFoodItem.imageData = processImageForStorage(image: image)
            
            // Store image in UserDefaults for backup
            if let imageData = combinedFoodItem.imageData {
                let imageKey = "combinedFoodImage_\(combinedFoodItem.id.uuidString)"
                UserDefaults.standard.set(imageData, forKey: imageKey)
                print("✅ Сохранено изображение комбинированного блюда размером \(imageData.count) байт")
            }
        } else {
            print("⚠️ Для комбинированного блюда не предоставлено изображение")
        }
        
        // Save to UserDefaults
        saveCombinedFood(combinedFoodItem)
        
        // Notify that food data has been updated
        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        
        print("===== КОМБИНИРОВАННОЕ БЛЮДО СОЗДАНО =====\n")
        return combinedFoodItem
    }
    
    // Save a combined food item to UserDefaults
    private func saveCombinedFood(_ combinedFood: CombinedFoodItem) {
        var combinedFoods = getCombinedFoodsFromUserDefaults()
        
        // Check if this combined food already exists
        if let index = combinedFoods.firstIndex(where: { ($0["id"] as? String) == combinedFood.id.uuidString }) {
            // Update existing entry
            combinedFoods[index] = combinedFood.toDictionary()
        } else {
            // Add new entry
            combinedFoods.append(combinedFood.toDictionary())
        }
        
        // Save back to UserDefaults
        UserDefaults.standard.set(combinedFoods, forKey: combinedFoodsKey)
        
        // Добавляем принудительную синхронизацию для сохранения данных
        UserDefaults.standard.synchronize()
        
        print("📝 Сохранено комбинированное блюдо: \(combinedFood.name) (ID: \(combinedFood.id.uuidString))")
    }
    
    // Get all combined food items
    func getAllCombinedFoods() -> [CombinedFoodItem] {
        let combinedFoodDicts = getCombinedFoodsFromUserDefaults()
        
        print("CombinedFoodManager: Загружено \(combinedFoodDicts.count) комбинированных блюд из UserDefaults")
        
        // Check combined foods against deletion list
        let deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        if !deletedIds.isEmpty {
            print("CombinedFoodManager: Найдено \(deletedIds.count) ID удаленных комбинированных блюд")
        }
        
        var validFoodDicts = combinedFoodDicts
        
        // ENHANCED: Double-check for deleted foods using both the deletion list and permanent deletion list
        var permanentlyDeletedIds = Set<String>()
        
        // Add IDs from deletedCombinedFoods
        deletedIds.forEach { permanentlyDeletedIds.insert($0) }
        
        // Add IDs from permanentlyDeletedIngredients
        if let permanentlyDeletedIngredients = UserDefaults.standard.dictionary(forKey: "permanentlyDeletedIngredients") as? [String: String] {
            permanentlyDeletedIngredients.keys.forEach { permanentlyDeletedIds.insert($0) }
        }
        
        // Add IDs from deletedFoodItems
        if let deletedFoodItems = UserDefaults.standard.array(forKey: "deletedFoodItems") as? [String] {
            deletedFoodItems.forEach { permanentlyDeletedIds.insert($0) }
        }
        
        // Remove any that should be deleted
        validFoodDicts.removeAll { dict in
            if let id = dict["id"] as? String, permanentlyDeletedIds.contains(id) {
                print("CombinedFoodManager: Скрываем удаленное комбинированное блюдо с ID: \(id)")
                return true
            }
            return false
        }
        
        var combinedFoods: [CombinedFoodItem] = []
        var failedItems = 0
        
        for dictionary in validFoodDicts {
            if let combinedFood = CombinedFoodItem.from(dictionary: dictionary, context: context) {
                // Double check this food hasn't been deleted
                if permanentlyDeletedIds.contains(combinedFood.id.uuidString) {
                    print("CombinedFoodManager: Skipping deleted combined food ID: \(combinedFood.id.uuidString)")
                    continue
                }
                
                combinedFoods.append(combinedFood)
                
                // Create backup for this food for better persistence
                ensureBackupExists(combinedFood)
                
                // Проверяем восстановление изображения
                if dictionary["hasImageData"] as? Bool == true,
                   let idString = dictionary["id"] as? String,
                   combinedFood.imageData == nil {
                    
                    print("⚠️ Комбинированное блюдо \(combinedFood.name) должно иметь изображение, но оно не было восстановлено")
                    
                    // Повторная попытка получить изображение
                    let imageKey = "combinedFoodImage_\(idString)"
                    if let imageData = UserDefaults.standard.data(forKey: imageKey),
                       imageData.count > 0 {
                        combinedFood.imageData = imageData
                        print("✅ Повторно восстановлено изображение для \(combinedFood.name)")
                    }
                }
            } else {
                failedItems += 1
                if let id = dictionary["id"] as? String, let name = dictionary["name"] as? String {
                    print("❌ Не удалось восстановить комбинированное блюдо \(name) (ID: \(id))")
                    
                    // Add to deleted list to prevent reappearance
                    if let id = dictionary["id"] as? String, !permanentlyDeletedIds.contains(id) {
                        var updatedDeletedIds = deletedIds
                        updatedDeletedIds.append(id)
                        UserDefaults.standard.set(updatedDeletedIds, forKey: "deletedCombinedFoods")
                    }
                }
            }
        }
        
        if failedItems > 0 {
            print("⚠️ Не удалось восстановить \(failedItems) комбинированных блюд")
            UserDefaults.standard.synchronize()
        }
        
        // Сортируем по времени создания (от новых к старым)
        let sortedFoods = combinedFoods.sorted { $0.createdAt > $1.createdAt }
        
        print("CombinedFoodManager: Успешно восстановлено \(sortedFoods.count) комбинированных блюд")
        
        return sortedFoods
    }
    
    // Delete a combined food item
    func deleteCombinedFood(id: UUID) {
        let idString = id.uuidString
        print("\n=== DELETING COMBINED FOOD ITEM: \(idString) ===")
        
        // 1. First pass: Remove from main combined foods list
        var combinedFoods = getCombinedFoodsFromUserDefaults()
        let countBefore = combinedFoods.count
        combinedFoods.removeAll(where: { ($0["id"] as? String) == idString })
        let countAfter = combinedFoods.count
        
        // 2. Delete all associated data from UserDefaults
        removeAllAssociatedData(id: idString)
        
        // 3. Add ID to deleted combined foods list to prevent reappearance
        var deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        if !deletedIds.contains(idString) {
            deletedIds.append(idString)
            UserDefaults.standard.set(deletedIds, forKey: "deletedCombinedFoods")
        }
        
        // 4. Save updated array and force synchronize
        UserDefaults.standard.set(combinedFoods, forKey: combinedFoodsKey)
        UserDefaults.standard.synchronize()
        
        // 5. Final verification to ensure deletion
        let verificationFoods = UserDefaults.standard.array(forKey: combinedFoodsKey) as? [[String: Any]] ?? []
        let stillExists = verificationFoods.contains(where: { ($0["id"] as? String) == idString })
        
        if stillExists {
            print("⚠️ CRITICAL: Combined food still exists after deletion - forcing clean")
            
            // Forceful removal as last resort
            var finalAttempt = verificationFoods
            finalAttempt.removeAll(where: { ($0["id"] as? String) == idString })
            UserDefaults.standard.set(finalAttempt, forKey: combinedFoodsKey)
            
            // Also try removing the entire 'combinedFoods' array and recreating it
            if finalAttempt.isEmpty {
                UserDefaults.standard.removeObject(forKey: combinedFoodsKey)
            }
            
            UserDefaults.standard.synchronize()
        }
        
        // 6. Update observers
        NotificationCenter.default.post(name: NSNotification.Name("CombinedFoodDeleted"), object: nil, userInfo: ["id": idString])
        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        
        // Log outcome
        if countBefore > countAfter {
            print("✅ Combined food with ID \(idString) successfully deleted")
        } else {
            print("⚠️ Combined food with ID \(idString) was not found for deletion")
        }
        
        print("=== DELETION COMPLETE ===\n")
    }
    
    // Helper method to remove all associated data for a combined food
    private func removeAllAssociatedData(id: String) {
        // Define the key patterns to look for
        let keyPatterns = [
            "combinedFoodImage_\(id)",
            "combinedFoodBackup_\(id)",
            "combined_food_\(id)",
            "ingredient_\(id)"
        ]
        
        // Get all UserDefaults keys
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        var removedCount = 0
        
        // Remove any key that contains the ID or matches our patterns
        for key in allKeys {
            if key.contains(id) || keyPatterns.contains(where: { key.hasPrefix($0) }) {
                UserDefaults.standard.removeObject(forKey: key)
                removedCount += 1
            }
        }
        
        print("✅ Removed \(removedCount) related items from UserDefaults")
    }
    
    // Get combined foods dictionaries from UserDefaults
    private func getCombinedFoodsFromUserDefaults() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: combinedFoodsKey) as? [[String: Any]] ?? []
    }
    
    // Helper function to process images for storage
    private func processImageForStorage(image: UIImage) -> Data? {
        // Resize the image if it's too large
        let maxDimension: CGFloat = 800
        var targetImage = image
        
        if max(image.size.width, image.size.height) > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newWidth = image.size.width * scale
            let newHeight = image.size.height * scale
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: newWidth, height: newHeight), false, 1.0)
            image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                targetImage = resizedImage
            }
            UIGraphicsEndImageContext()
        }
        
        // Compress to JPEG with moderate quality
        return targetImage.jpegData(compressionQuality: 0.6)
    }
    
    // Check for and remove invalid combined foods
    private func cleanupInvalidCombinedFoods() {
        let combinedFoods = getCombinedFoodsFromUserDefaults()
        let deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        
        var validFoodDicts = combinedFoods
        
        // Remove any that should be deleted
        validFoodDicts.removeAll { dict in
            if let id = dict["id"] as? String, deletedIds.contains(id) {
                print("CombinedFoodManager: Скрываем удаленное комбинированное блюдо с ID: \(id)")
                return true
            }
            return false
        }
        
        // Save the updated list - make sure it's properly saved
        UserDefaults.standard.set(validFoodDicts, forKey: combinedFoodsKey)
        UserDefaults.standard.synchronize()
    }
    
    // Method to ensure a backup exists for a combined food
    public func ensureBackupExists(_ combinedFood: CombinedFoodItem) {
        print("CombinedFoodManager: Creating backup for combined food: \(combinedFood.name)")
        
        // Create a full dictionary backup
        let dictionary = combinedFood.toDictionary()
        
        // Save to a backup key
        let backupKey = "combinedFoodBackup_\(combinedFood.id.uuidString)"
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: []) {
            UserDefaults.standard.set(jsonData, forKey: backupKey)
            print("✅ Created data backup for \(combinedFood.name)")
        }
        
        // Save image separately
        if let imageData = combinedFood.imageData {
            let imageKey = "combinedFoodImage_\(combinedFood.id.uuidString)"
            UserDefaults.standard.set(imageData, forKey: imageKey)
            print("✅ Created image backup for \(combinedFood.name) (\(imageData.count) bytes)")
        }
        
        // Force synchronize
        UserDefaults.standard.synchronize()
    }
    
    // Refresh a combined food to move it to the top of Recently Logged
    func refreshCombinedFood(id: UUID) {
        print("=== REFRESHING COMBINED FOOD: \(id.uuidString) ===")
        
        var combinedFoods = getCombinedFoodsFromUserDefaults()
        
        // Find the food by ID
        if let index = combinedFoods.firstIndex(where: { ($0["id"] as? String) == id.uuidString }) {
            // Get the food
            var foodDict = combinedFoods[index]
            
            // Update timestamp to current time
            foodDict["createdAtTimestamp"] = Date().timeIntervalSince1970
            
            // Remove from current position
            combinedFoods.remove(at: index)
            
            // Add to the beginning
            combinedFoods.insert(foodDict, at: 0)
            
            // Save back to UserDefaults
            UserDefaults.standard.set(combinedFoods, forKey: combinedFoodsKey)
            UserDefaults.standard.synchronize()
            
            print("✅ Combined food refreshed and moved to top of Recently Logged")
            
            // Notify UI to update
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
        } else {
            print("❌ Combined food with ID \(id.uuidString) not found")
        }
    }
}




