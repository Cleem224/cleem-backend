//
//  Steps+CoreDataProperties.swift
//  Cleem
//
//  Created by Faiq Novruzov on 20.04.25.
//
//

import Foundation
import CoreData


extension Steps {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Steps> {
        return NSFetchRequest<Steps>(entityName: "Steps")
    }

    @NSManaged public var calories: Double
    @NSManaged public var count: Int32
    @NSManaged public var date: Date?
    @NSManaged public var distance: Double
    @NSManaged public var id: UUID?
    @NSManaged public var source: String?
    @NSManaged public var user: User?

}

extension Steps : Identifiable {

}
