//
//  Meal+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 23.04.25.
//
//

import Foundation
import CoreData


extension Meal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Meal> {
        return NSFetchRequest<Meal>(entityName: "Meal")
    }

    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var notes: String?
    @NSManaged public var totalCalories: Double
    @NSManaged public var totalCarbs: Double
    @NSManaged public var totalFat: Double
    @NSManaged public var totalProtein: Double
    @NSManaged public var type: String?
    @NSManaged public var mealFoods: NSSet?
    @NSManaged public var user: User?

}

// MARK: Generated accessors for mealFoods
extension Meal {

    @objc(addMealFoodsObject:)
    @NSManaged public func addToMealFoods(_ value: MealFood)

    @objc(removeMealFoodsObject:)
    @NSManaged public func removeFromMealFoods(_ value: MealFood)

    @objc(addMealFoods:)
    @NSManaged public func addToMealFoods(_ values: NSSet)

    @objc(removeMealFoods:)
    @NSManaged public func removeFromMealFoods(_ values: NSSet)

}

extension Meal : Identifiable {

}
