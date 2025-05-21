import Foundation
import UIKit

struct FoodItem: Identifiable {
    let id: String
    let name: String
    let category: String
    let servingSize: Double
    let servingUnit: String?
    let description: String?
    let image: UIImage?
    
    init(id: String = UUID().uuidString,
         name: String,
         category: String,
         servingSize: Double = 100,
         servingUnit: String? = "g",
         description: String? = nil,
         image: UIImage? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.description = description
        self.image = image
    }
}

// Make FoodItem conform to Hashable for use in SwiftUI Lists with ForEach
extension FoodItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        lhs.id == rhs.id
    }
}

