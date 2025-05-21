import SwiftUI

/// Component for displaying a row of nutrient information with name and value
public struct NutrientRow: View {
    let name: String
    let value: String
    
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
    
    public var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 16))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
        }
    }
} 