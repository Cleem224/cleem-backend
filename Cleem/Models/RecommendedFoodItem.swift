import Foundation
import UIKit

struct RecommendedFoodItem: Identifiable {
    let id: UUID
    let name: String
    let calories: Int
    let servingSize: Double
    let servingUnit: String
    let image: UIImage?
    let category: String
    
    // Данные о питательной ценности
    let protein: Double
    let carbs: Double
    let fat: Double
    
    // Дополнительные данные
    let sugars: Double?
    let fiber: Double?
    let sodium: Double?
    
    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        servingSize: Double,
        servingUnit: String = "г",
        image: UIImage? = nil,
        category: String = "Общее",
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        sugars: Double? = nil,
        fiber: Double? = nil,
        sodium: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.image = image
        self.category = category
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugars = sugars
        self.fiber = fiber
        self.sodium = sodium
    }
    
    // Конвертация в FoodItem
    func toFoodItem() -> FoodItem {
        return FoodItem(
            id: self.id.uuidString,
            name: self.name,
            category: self.category,
            servingSize: self.servingSize,
            servingUnit: self.servingUnit,
            description: nil,
            image: self.image
        )
    }
    
    // Конвертация в FoodNutrition
    func toFoodNutrition() -> FoodNutrition {
        return FoodNutrition(
            calories: Double(self.calories),
            protein: self.protein,
            carbs: self.carbs,
            fat: self.fat,
            sugars: self.sugars,
            fiber: self.fiber,
            sodium: self.sodium,
            servingSize: self.servingSize,
            servingUnit: self.servingUnit,
            foodName: self.name,
            source: "database"
        )
    }
    
    // Образцы рекомендуемых продуктов для демонстрации
    static var sampleRecommendations: [RecommendedFoodItem] = [
        RecommendedFoodItem(
            name: "Яйцо",
            calories: 74,
            servingSize: 50,
            protein: 6.3,
            carbs: 0.6,
            fat: 5.3
        ),
        RecommendedFoodItem(
            name: "Огурец",
            calories: 15,
            servingSize: 100,
            protein: 0.7,
            carbs: 3.6,
            fat: 0.1
        ),
        RecommendedFoodItem(
            name: "Греческий йогурт",
            calories: 59,
            servingSize: 100,
            protein: 10.0,
            carbs: 3.6,
            fat: 0.4
        ),
        RecommendedFoodItem(
            name: "Куриная грудка",
            calories: 165,
            servingSize: 100,
            protein: 31.0,
            carbs: 0.0,
            fat: 3.6
        ),
        RecommendedFoodItem(
            name: "Овсянка",
            calories: 68,
            servingSize: 100,
            servingUnit: "г",
            protein: 2.5,
            carbs: 12.0,
            fat: 1.5,
            fiber: 2.0
        ),
        RecommendedFoodItem(
            name: "Авокадо",
            calories: 160,
            servingSize: 100,
            protein: 2.0,
            carbs: 8.5,
            fat: 14.7,
            fiber: 6.7
        )
    ]
}

