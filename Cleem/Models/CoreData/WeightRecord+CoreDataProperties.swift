//
//  WeightRecord+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 20.04.25.
//
//

import Foundation
import CoreData


extension WeightRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeightRecord> {
        return NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }

    @NSManaged public var bodyFatPercentage: Double
    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var unit: String?
    @NSManaged public var weight: Double
    @NSManaged public var user: User?

}

extension WeightRecord : Identifiable {

}
