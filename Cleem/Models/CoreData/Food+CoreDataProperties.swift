//
//  Food+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 14.05.25.
//
//

import Foundation
import CoreData


extension Food {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Food> {
        return NSFetchRequest<Food>(entityName: "Food")
    }

    @NSManaged public var barcode: String?
    @NSManaged public var brand: String?
    @NSManaged public var calories: Double
    @NSManaged public var carbs: Double
    @NSManaged public var category: String?
    @NSManaged public var cholesterol: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var fat: Double
    @NSManaged public var fiber: Double
    @NSManaged public var id: UUID?
    @NSManaged public var image: Data?
    @NSManaged public var imageData: Data?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var isIngredient: Bool
    @NSManaged public var name: String?
    @NSManaged public var protein: Double
    @NSManaged public var servingSize: Double
    @NSManaged public var servingUnit: String?
    @NSManaged public var sodium: Double
    @NSManaged public var sugar: Double
    @NSManaged public var wasTracked: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var isComposed: Bool
    @NSManaged public var ingredients: NSSet?
    @NSManaged public var mealFoods: NSSet?

}

// MARK: Generated accessors for ingredients
extension Food {

    @objc(addIngredientsObject:)
    @NSManaged public func addToIngredients(_ value: Ingredient)

    @objc(removeIngredientsObject:)
    @NSManaged public func removeFromIngredients(_ value: Ingredient)

    @objc(addIngredients:)
    @NSManaged public func addToIngredients(_ values: NSSet)

    @objc(removeIngredients:)
    @NSManaged public func removeFromIngredients(_ values: NSSet)

}

// MARK: Generated accessors for mealFoods
extension Food {

    @objc(addMealFoodsObject:)
    @NSManaged public func addToMealFoods(_ value: MealFood)

    @objc(removeMealFoodsObject:)
    @NSManaged public func removeFromMealFoods(_ value: MealFood)

    @objc(addMealFoods:)
    @NSManaged public func addToMealFoods(_ values: NSSet)

    @objc(removeMealFoods:)
    @NSManaged public func removeFromMealFoods(_ values: NSSet)

}

extension Food : Identifiable {

}
