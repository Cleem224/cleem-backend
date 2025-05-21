//
//  MealFood+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 20.04.25.
//
//

import Foundation
import CoreData


extension MealFood {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealFood> {
        return NSFetchRequest<MealFood>(entityName: "MealFood")
    }

    @NSManaged public var amount: Double
    @NSManaged public var calories: Double
    @NSManaged public var carbs: Double
    @NSManaged public var fat: Double
    @NSManaged public var id: UUID?
    @NSManaged public var protein: Double
    @NSManaged public var unit: String?
    @NSManaged public var food: Food?
    @NSManaged public var meal: Meal?

}

extension MealFood : Identifiable {

}
