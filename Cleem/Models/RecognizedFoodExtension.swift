import Foundation
import UIKit

// Расширение для RecognizedFood, чтобы соответствовать протоколу FoodDisplayable
extension RecognizedFood: FoodDisplayable {
    public var displayName: String {
        return self.name
    }
    
    public var displayCalories: Double {
        return self.nutritionData?.calories ?? 0
    }
    
    public var displayServingSize: Double {
        return 100 // Стандартный размер порции
    }
    
    public var displayServingUnit: String? {
        return "г"
    }
    
    public var displayImage: UIImage? {
        return self.originalImage
    }
    
    public var displayProtein: Double? {
        return self.nutritionData?.protein
    }
    
    public var displayCarbs: Double? {
        return self.nutritionData?.carbs
    }
    
    public var displayFat: Double? {
        return self.nutritionData?.fat
    }
    
    public var displayCategory: String? {
        return "Food"
    }
    
    public var displaySugar: Double? {
        return self.nutritionData?.sugar
    }
    
    public var displayFiber: Double? {
        return self.nutritionData?.fiber
    }
    
    public var displaySodium: Double? {
        return self.nutritionData?.sodium
    }
}

// Расширение для RecognizedFoodV2, чтобы соответствовать протоколу FoodDisplayable
extension RecognizedFoodV2: FoodDisplayable {
    public var displayName: String {
        return self.name
    }
    
    public var displayCalories: Double {
        return self.nutritionData?.calories ?? 0
    }
    
    public var displayServingSize: Double {
        return 100 // Стандартный размер порции
    }
    
    public var displayServingUnit: String? {
        return "г"
    }
    
    public var displayImage: UIImage? {
        return self.originalImage
    }
    
    public var displayProtein: Double? {
        return self.nutritionData?.protein
    }
    
    public var displayCarbs: Double? {
        return self.nutritionData?.carbs
    }
    
    public var displayFat: Double? {
        return self.nutritionData?.fat
    }
    
    public var displayCategory: String? {
        return "Food"
    }
    
    public var displaySugar: Double? {
        return self.nutritionData?.sugar
    }
    
    public var displayFiber: Double? {
        return self.nutritionData?.fiber
    }
    
    public var displaySodium: Double? {
        return self.nutritionData?.sodium
    }
}

