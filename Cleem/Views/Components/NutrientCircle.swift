import SwiftUI

/// A reusable nutrient circle component that displays a nutritional value with a colored circular progress indicator
struct NutrientCircle: View {
    // For ScanCameraViewV2 style
    var value: Int
    var label: String
    var unit: String
    var color: Color
    
    // For FoodDetailView style (optional parameters)
    var maxValue: Double?
    var title: String?
    var unitText: String?
    
    init(value: Int, label: String, unit: String, color: Color) {
        self.value = value
        self.label = label
        self.unit = unit
        self.color = color
        self.maxValue = 100 // Default max value
    }
    
    // Initialize with FoodDetailView style
    init(value: Double, maxValue: Double, title: String, unitText: String, color: Color) {
        self.value = Int(value)
        self.maxValue = maxValue
        self.title = title
        self.unitText = unitText
        self.color = color
        self.label = title.prefix(1).uppercased()
        self.unit = unitText
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(Double(value) / (maxValue ?? 100.0), 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: value)
                
                // Center content
                VStack(spacing: 2) {
                    Text(String(value))
                        .font(.system(size: 18, weight: .bold))
                    
                    if title == nil {
                        // Display unit only for ScanCameraViewV2 style
                        Text(unit)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    } else {
                        // Display unitText for FoodDetailView style
                        Text(unitText ?? unit)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Display label or title below
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
} 