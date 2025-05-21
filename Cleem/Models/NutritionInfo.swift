import Foundation

// Модель данных для хранения информации о пищевой ценности продукта
struct NutritionInfo: Codable, Identifiable {
    var id = UUID()
    
    // Основные значения
    var calories: Double = 0
    var proteins: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    
    // Детальная информация
    var sugar: Double = 0
    var fiber: Double = 0
    var saturatedFat: Double = 0
    var unsaturatedFat: Double = 0
    var sodium: Double = 0
    var potassium: Double = 0
    var cholesterol: Double = 0
    
    // Витамины и минералы (в процентах от дневной нормы)
    var vitaminA: Double = 0
    var vitaminC: Double = 0
    var calcium: Double = 0
    var iron: Double = 0
    
    // Размер порции в граммах
    var servingSize: Double = 100
    
    // Алиасы свойств для совместимости с разными наименованиями в коде
    var protein: Double {
        get { return proteins }
        set { proteins = newValue }
    }
    
    // Создание информации о питании из Open Food Facts данных
    static func fromOpenFoodFacts(_ nutrients: OpenFoodFactsNutrients, servingSize: String? = nil) -> NutritionInfo {
        var nutrition = NutritionInfo()
        
        // Заполняем основную информацию
        nutrition.calories = nutrients.energyKcal100g ?? 0
        nutrition.proteins = nutrients.proteins100g ?? 0
        nutrition.carbs = nutrients.carbohydrates100g ?? 0
        nutrition.fat = nutrients.fat100g ?? 0
        
        // Заполняем детальную информацию
        nutrition.sugar = nutrients.sugars100g ?? 0
        nutrition.fiber = nutrients.fiber100g ?? 0
        nutrition.sodium = nutrients.sodium100g ?? 0
        
        // Парсим размер порции, если он доступен
        if let servingSizeStr = servingSize, let size = parseServingSize(from: servingSizeStr) {
            nutrition.servingSize = size
        }
        
        return nutrition
    }
    
    // Создание информации о питании из данных FoodRecognitionManager
    static func fromNutritionData(_ nutrition: NutritionData) -> NutritionInfo {
        var nutritionInfo = NutritionInfo()
        
        // Заполняем основную информацию
        nutritionInfo.calories = nutrition.calories
        nutritionInfo.proteins = nutrition.protein
        nutritionInfo.carbs = nutrition.carbs
        nutritionInfo.fat = nutrition.fat
        
        // Заполняем детальную информацию, если доступна
        nutritionInfo.sugar = nutrition.sugar ?? 0
        nutritionInfo.fiber = nutrition.fiber ?? 0
        nutritionInfo.sodium = nutrition.sodium ?? 0
        
        return nutritionInfo
    }
    
    // Функция для получения строки с основной информацией
    func basicInfoString() -> String {
        return String(format: "%.0f ккал | Б: %.1fг | Ж: %.1fг | У: %.1fг", calories, proteins, fat, carbs)
    }
    
    // Функция для получения процента калорий от белков, жиров и углеводов
    func macroPercentages() -> (proteins: Double, fat: Double, carbs: Double) {
        let total = proteins * 4 + fat * 9 + carbs * 4
        if total <= 0 {
            return (proteins: 0, fat: 0, carbs: 0)
        }
        
        return (
            proteins: (proteins * 4 / total) * 100,
            fat: (fat * 9 / total) * 100,
            carbs: (carbs * 4 / total) * 100
        )
    }
    
    // Вспомогательный метод для парсинга размера порции
    private static func parseServingSize(from string: String) -> Double? {
        // Ищем числовое значение в строке
        let pattern = "([0-9]+[.,]?[0-9]*)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        guard let regex = regex,
              let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)),
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }
        
        let value = string[range]
        return Double(value.replacingOccurrences(of: ",", with: "."))
    }
}


