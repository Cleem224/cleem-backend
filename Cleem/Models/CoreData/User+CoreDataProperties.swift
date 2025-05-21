//
//  User+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 20.04.25.
//
//

import Foundation
import CoreData


extension User {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }

    @NSManaged public var activityLevel: String?
    @NSManaged public var age: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var currentWeight: Double
    @NSManaged public var dailyCalorieGoal: Double
    @NSManaged public var dailyCarbsGoal: Double
    @NSManaged public var dailyFatGoal: Double
    @NSManaged public var dailyProteinGoal: Double
    @NSManaged public var dailyStepsTarget: Int32
    @NSManaged public var dailyWaterTarget: Double
    @NSManaged public var gender: String?
    @NSManaged public var goal: String?
    @NSManaged public var height: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var targetWeight: Double
    @NSManaged public var weight: Double
    @NSManaged public var meals: NSSet?
    @NSManaged public var steps: NSSet?
    @NSManaged public var waterIntakes: NSSet?
    @NSManaged public var weightRecords: NSSet?

}

// MARK: Generated accessors for meals
extension User {

    @objc(addMealsObject:)
    @NSManaged public func addToMeals(_ value: Meal)

    @objc(removeMealsObject:)
    @NSManaged public func removeFromMeals(_ value: Meal)

    @objc(addMeals:)
    @NSManaged public func addToMeals(_ values: NSSet)

    @objc(removeMeals:)
    @NSManaged public func removeFromMeals(_ values: NSSet)

}

// MARK: Generated accessors for steps
extension User {

    @objc(addStepsObject:)
    @NSManaged public func addToSteps(_ value: Steps)

    @objc(removeStepsObject:)
    @NSManaged public func removeFromSteps(_ value: Steps)

    @objc(addSteps:)
    @NSManaged public func addToSteps(_ values: NSSet)

    @objc(removeSteps:)
    @NSManaged public func removeFromSteps(_ values: NSSet)

}

// MARK: Generated accessors for waterIntakes
extension User {

    @objc(addWaterIntakesObject:)
    @NSManaged public func addToWaterIntakes(_ value: WaterIntake)

    @objc(removeWaterIntakesObject:)
    @NSManaged public func removeFromWaterIntakes(_ value: WaterIntake)

    @objc(addWaterIntakes:)
    @NSManaged public func addToWaterIntakes(_ values: NSSet)

    @objc(removeWaterIntakes:)
    @NSManaged public func removeFromWaterIntakes(_ values: NSSet)

}

// MARK: Generated accessors for weightRecords
extension User {

    @objc(addWeightRecordsObject:)
    @NSManaged public func addToWeightRecords(_ value: WeightRecord)

    @objc(removeWeightRecordsObject:)
    @NSManaged public func removeFromWeightRecords(_ value: WeightRecord)

    @objc(addWeightRecords:)
    @NSManaged public func addToWeightRecords(_ values: NSSet)

    @objc(removeWeightRecords:)
    @NSManaged public func removeFromWeightRecords(_ values: NSSet)

}

extension User : Identifiable {

}
