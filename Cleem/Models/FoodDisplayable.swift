import Foundation
import UIKit
import CoreData

// Протокол для унификации отображения продуктов в приложении
public protocol FoodDisplayable: Identifiable {
    var displayName: String { get }
    var displayCalories: Double { get }
    var displayServingSize: Double { get }
    var displayServingUnit: String? { get }
    var displayImage: UIImage? { get }
    var displayProtein: Double? { get }
    var displayCarbs: Double? { get }
    var displayFat: Double? { get }
    var displayCategory: String? { get }
    var displaySugar: Double? { get }
    var displayFiber: Double? { get }
    var displaySodium: Double? { get }
}

// Реализация для Core Data модели Food
extension Food: FoodDisplayable {
    public var displayName: String {
        return self.name ?? "Unknown"
    }
    
    public var displayCalories: Double {
        return self.calories
    }
    
    public var displayServingSize: Double {
        return self.servingSize
    }
    
    public var displayServingUnit: String? {
        return self.servingUnit
    }
    
    public var displayImage: UIImage? {
        if let imageData = self.imageData {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    public var displayProtein: Double? {
        return self.protein
    }
    
    public var displayCarbs: Double? {
        return self.carbs
    }
    
    public var displayFat: Double? {
        return self.fat
    }
    
    public var displayCategory: String? {
        return "Food"
    }
    
    public var displaySugar: Double? {
        return self.sugar
    }
    
    public var displayFiber: Double? {
        return self.fiber
    }
    
    public var displaySodium: Double? {
        return self.sodium
    }
}

// Реализация для модели RecommendedFoodItem
extension RecommendedFoodItem: FoodDisplayable {
    public var displayName: String {
        return self.name
    }
    
    public var displayCalories: Double {
        return Double(self.calories)
    }
    
    public var displayServingSize: Double {
        return self.servingSize
    }
    
    public var displayServingUnit: String? {
        return self.servingUnit
    }
    
    public var displayImage: UIImage? {
        return self.image
    }
    
    public var displayProtein: Double? {
        return self.protein
    }
    
    public var displayCarbs: Double? {
        return self.carbs
    }
    
    public var displayFat: Double? {
        return self.fat
    }
    
    public var displayCategory: String? {
        return self.category
    }
    
    public var displaySugar: Double? {
        return self.sugars
    }
    
    public var displayFiber: Double? {
        return self.fiber
    }
    
    public var displaySodium: Double? {
        return self.sodium
    }
}

