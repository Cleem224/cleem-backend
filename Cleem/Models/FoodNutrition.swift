import Foundation

// Модель для питательной ценности, совместимая со старым интерфейсом
public struct FoodNutrition: Codable, Identifiable {
    public let id: UUID = UUID()
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let sugars: Double?
    public let fiber: Double?
    public let sodium: Double?
    public let servingSize: Double
    public let servingUnit: String
    public let foodName: String
    
    // Метаданные
    public let source: String // "edamam", "openFoodFacts", etc.
    
    public init(calories: Double, protein: Double, carbs: Double, fat: Double, sugars: Double?, fiber: Double?, sodium: Double?, servingSize: Double, servingUnit: String, foodName: String, source: String) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sugars = sugars
        self.fiber = fiber
        self.sodium = sodium
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.foodName = foodName
        self.source = source
    }
}

// Для обратной совместимости со старым кодом
public typealias NutritionResponse = LegacyNutritionResponse

// Модель для совместимости со старым кодом
public struct LegacyNutritionResponse: Codable {
    public let nutritional_info: APIFoodNutritionInfo
    public let serving_size: APIServingSize?
    public let foodName: String
    
    // Метод для преобразования в новую модель
    public func toFoodNutrition() -> FoodNutrition {
        return FoodNutrition(
            calories: nutritional_info.calories,
            protein: nutritional_info.protein,
            carbs: nutritional_info.totalCarbs,
            fat: nutritional_info.totalFat,
            sugars: nutritional_info.sugars,
            fiber: nutritional_info.fiber,
            sodium: nutritional_info.sodium,
            servingSize: serving_size?.size ?? 100.0,
            servingUnit: serving_size?.unit ?? "г",
            foodName: foodName,
            source: "legacy"
        )
    }
    
    public init(nutritional_info: APIFoodNutritionInfo, serving_size: APIServingSize?, foodName: String) {
        self.nutritional_info = nutritional_info
        self.serving_size = serving_size
        self.foodName = foodName
    }
}

// Модель для декодирования информации о пищевой ценности (для совместимости)
public struct APIFoodNutritionInfo: Codable {
    public let calories: Double
    public let totalFat: Double
    public let saturatedFat: Double?
    public let cholesterol: Double?
    public let sodium: Double?
    public let totalCarbs: Double
    public let sugars: Double?
    public let protein: Double
    public let fiber: Double?
    
    public enum CodingKeys: String, CodingKey {
        case calories = "calories"
        case totalFat = "fat"
        case saturatedFat = "saturated fat"
        case cholesterol = "cholesterol"
        case sodium = "sodium"
        case totalCarbs = "carbohydrates"
        case sugars = "sugar"
        case protein = "protein"
        case fiber = "fiber"
    }
    
    public init(calories: Double, totalFat: Double, saturatedFat: Double?, cholesterol: Double?, sodium: Double?, totalCarbs: Double, sugars: Double?, protein: Double, fiber: Double?) {
        self.calories = calories
        self.totalFat = totalFat
        self.saturatedFat = saturatedFat
        self.cholesterol = cholesterol
        self.sodium = sodium
        self.totalCarbs = totalCarbs
        self.sugars = sugars
        self.protein = protein
        self.fiber = fiber
    }
}

// Модель размера порции для API (для совместимости)
public struct APIServingSize: Codable {
    public let size: Double
    public let unit: String
    
    public init(size: Double, unit: String) {
        self.size = size
        self.unit = unit
    }
}

// Для преобразования между форматами
extension NutritionData {
    public func toFoodNutrition(foodName: String) -> FoodNutrition {
        return FoodNutrition(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugars: sugar,
            fiber: fiber,
            sodium: sodium,
            servingSize: 100.0,
            servingUnit: "г",
            foodName: foodName,
            source: "edamam"
        )
    }
    
    public func toLegacyNutritionResponse(foodName: String) -> NutritionResponse {
        let nutritionalInfo = APIFoodNutritionInfo(
            calories: calories,
            totalFat: fat,
            saturatedFat: nil,
            cholesterol: nil,
            sodium: sodium,
            totalCarbs: carbs,
            sugars: sugar,
            protein: protein,
            fiber: fiber
        )
        
        let servingSize = APIServingSize(size: 100, unit: "г")
        
        return NutritionResponse(
            nutritional_info: nutritionalInfo,
            serving_size: servingSize,
            foodName: foodName
        )
    }
}

// Static examples for testing and preview purposes
extension FoodNutrition {
    public static let apple = FoodNutrition(
        calories: 95,
        protein: 0.5,
        carbs: 25.0,
        fat: 0.3,
        sugars: 19.0,
        fiber: 4.4,
        sodium: 2.0,
        servingSize: 100.0,
        servingUnit: "г",
        foodName: "Apple",
        source: "preview"
    )
    
    public static let chicken = FoodNutrition(
        calories: 165,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        sugars: 0.0,
        fiber: 0.0,
        sodium: 74.0,
        servingSize: 100.0,
        servingUnit: "г",
        foodName: "Chicken Breast",
        source: "preview"
    )
}

