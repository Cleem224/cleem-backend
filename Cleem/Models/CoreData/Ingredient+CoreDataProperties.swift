//
//  Ingredient+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 13.05.25.
//
//

import Foundation
import CoreData


extension Ingredient {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Ingredient> {
        return NSFetchRequest<Ingredient>(entityName: "Ingredient")
    }

    @NSManaged public var amount: Double
    @NSManaged public var calories: Double
    @NSManaged public var carbs: Double
    @NSManaged public var fat: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var originalName: String?
    @NSManaged public var protein: Double
    @NSManaged public var unit: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var food: Food?

}

extension Ingredient : Identifiable {

}
