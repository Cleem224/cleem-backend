import Foundation
import UIKit

/// Модель распознанной еды с информацией о питательной ценности и ингредиентах
public struct RecognizedFoodV2: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let confidence: Double
    public let nutritionData: NutritionDataV2?
    public let originalImage: UIImage?
    public let ingredients: [String]?
    
    public init(id: UUID = UUID(), name: String, confidence: Double, nutritionData: NutritionDataV2? = nil, originalImage: UIImage? = nil, ingredients: [String]? = nil) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.nutritionData = nutritionData
        self.originalImage = originalImage
        self.ingredients = ingredients
    }
    
    public static func == (lhs: RecognizedFoodV2, rhs: RecognizedFoodV2) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Модель данных о питательной ценности
public struct NutritionDataV2 {
    public let calories: Double
    public let protein: Double
    public let fat: Double
    public let carbs: Double
    public let sugar: Double?
    public let fiber: Double?
    public let sodium: Double?
    public let cholesterol: Double?
    public let servingSize: Double?
    public let servingUnit: String?
    public let source: String
    public let foodLabel: String
    
    public init(calories: Double, protein: Double, fat: Double, carbs: Double, sugar: Double? = nil, fiber: Double? = nil, sodium: Double? = nil, source: String, foodLabel: String, cholesterol: Double? = nil, servingSize: Double? = nil, servingUnit: String? = nil) {
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.sugar = sugar
        self.fiber = fiber
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = source
        self.foodLabel = foodLabel
    }
    
    /// Преобразование в FoodNutrition для обратной совместимости
    public func toFoodNutrition() -> FoodNutrition {
        return FoodNutrition(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugars: sugar,
            fiber: fiber,
            sodium: sodium,
            servingSize: servingSize ?? 100.0,
            servingUnit: servingUnit ?? "г",
            foodName: foodLabel,
            source: source
        )
    }
}

/// Расширение для форматирования данных о питании
extension NutritionDataV2 {
    /// Форматирование значений питательных веществ для отображения
    public func formattedValue(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }
    
    public var formattedCalories: String {
        return String(format: "%.0f", calories)
    }
    
    public var formattedProtein: String {
        return formattedValue(protein)
    }
    
    public var formattedFat: String {
        return formattedValue(fat)
    }
    
    public var formattedCarbs: String {
        return formattedValue(carbs)
    }
    
    public var formattedSugar: String {
        if let sugar = sugar {
            return formattedValue(sugar)
        }
        return "N/A"
    }
    
    public var formattedFiber: String {
        if let fiber = fiber {
            return formattedValue(fiber)
        }
        return "N/A"
    }
    
    public var formattedSodium: String {
        if let sodium = sodium {
            return formattedValue(sodium)
        }
        return "N/A"
    }
}

// MARK: - Dummy data

extension RecognizedFoodV2 {
    /// Создание фиктивных данных для примера
    static var dummyData: [RecognizedFoodV2] {
        [
            RecognizedFoodV2(
                name: "Яблоко",
                confidence: 0.95,
                nutritionData: NutritionDataV2(
                    calories: 52,
                    protein: 0.3,
                    fat: 0.2,
                    carbs: 14,
                    sugar: 10.4,
                    fiber: 2.4,
                    sodium: 1,
                    source: "spoonacular",
                    foodLabel: "Яблоко",
                    cholesterol: 0,
                    servingSize: 100,
                    servingUnit: "г"
                ),
                ingredients: nil
            ),
            RecognizedFoodV2(
                name: "Плов с бараниной",
                confidence: 0.92,
                nutritionData: NutritionDataV2(
                    calories: 350,
                    protein: 15,
                    fat: 18,
                    carbs: 30,
                    sugar: 2,
                    fiber: 3,
                    sodium: 400,
                    source: "spoonacular_combined",
                    foodLabel: "Плов с бараниной",
                    cholesterol: 25,
                    servingSize: 100,
                    servingUnit: "г"
                ),
                ingredients: ["рис", "баранина", "морковь", "лук", "масло"]
            ),
            RecognizedFoodV2(
                name: "Цезарь с курицей",
                confidence: 0.87,
                nutritionData: NutritionDataV2(
                    calories: 280,
                    protein: 22,
                    fat: 14,
                    carbs: 12,
                    sugar: 3,
                    fiber: 4,
                    sodium: 350,
                    source: "spoonacular_combined",
                    foodLabel: "Цезарь с курицей",
                    cholesterol: 40,
                    servingSize: 100,
                    servingUnit: "г"
                ),
                ingredients: ["салат айсберг", "куриная грудка", "сыр пармезан", "гренки", "соус цезарь"]
            )
        ]
    }
} 