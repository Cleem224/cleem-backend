//
//  WaterIntake+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 20.04.25.
//
//

import Foundation
import CoreData


extension WaterIntake {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WaterIntake> {
        return NSFetchRequest<WaterIntake>(entityName: "WaterIntake")
    }

    @NSManaged public var amount: Double
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var unit: String?
    @NSManaged public var user: User?

}

extension WaterIntake : Identifiable {

}
