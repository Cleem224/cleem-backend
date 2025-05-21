import Foundation
import CoreData
import UIKit

extension Food {
    // MARK: - Computed Properties
    
    // Ensure we have a valid ID
    @objc var foodId: String {
        get {
            id?.uuidString ?? UUID().uuidString
        }
        set {
            id = UUID(uuidString: newValue) ?? UUID()
        }
    }
    
    // Get timestamp with a fallback to createdAt
    @objc var currentTimestamp: Date {
        get {
            return timestamp ?? createdAt ?? Date()
        }
        set {
            timestamp = newValue
        }
    }
    
    // MARK: - Helper methods
    
    // Create a sample food for scanning functionality
    static func createSampleFood(fromImage image: UIImage) -> Food {
        let context = CoreDataManager.shared.context
        let food = Food(context: context)
        food.id = UUID()
        
        // Несколько вариантов популярных блюд для случайного выбора
        let commonFoods = [
            "Mixed pizza": (2120.0, 88.0, 224.0, 96.0),
            "Pasta Carbonara": (950.0, 40.0, 90.0, 50.0),
            "Caesar Salad": (520.0, 30.0, 25.0, 35.0),
            "Beef Steak": (680.0, 60.0, 0.0, 45.0),
            "Salmon Fillet": (410.0, 45.0, 0.0, 25.0),
            "Sushi Roll": (350.0, 20.0, 40.0, 12.0),
            "Chicken Curry": (580.0, 35.0, 40.0, 30.0),
            "Fruit Smoothie": (320.0, 8.0, 70.0, 2.0),
            "Protein Shake": (250.0, 40.0, 10.0, 5.0)
        ]
        
        // Выбираем случайное блюдо из списка
        let randomIndex = Int.random(in: 0..<commonFoods.count)
        let foodArray = Array(commonFoods)
        let selectedFood = foodArray[randomIndex]
        
        // Устанавливаем свойства
        food.name = selectedFood.0
        food.calories = selectedFood.1.0
        food.protein = selectedFood.1.1
        food.carbs = selectedFood.1.2
        food.fat = selectedFood.1.3
        
        // Сохраняем изображение
        if let imageData = image.jpegData(compressionQuality: 0.7) {
            food.imageData = imageData
        }
        
        food.createdAt = Date()
        food.timestamp = Date()
        food.servingSize = 100
        food.servingUnit = "г"
        
        // Сохраняем в CoreData
        CoreDataManager.shared.saveContext()
        
        return food
    }
}

