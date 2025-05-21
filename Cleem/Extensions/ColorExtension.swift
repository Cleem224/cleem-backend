import SwiftUI

extension Color {
    // Main app background colors - using the version from CleemApp.swift
    // Use appBackground from CleemApp.swift instead
    
    // Progress circle colors
    static let proteinColor = Color(red: 0.92, green: 0.36, blue: 0.36) // Red
    static let carbsColor = Color(red: 0.36, green: 0.56, blue: 0.92) // Blue
    static let fatColor = Color(red: 0.92, green: 0.62, blue: 0.36) // Orange
    
    // UI Element colors
    static let cardBackground = Color(UIColor.systemGray6) // Light gray for cards
    static let textPrimary = Color.black
    static let textSecondary = Color.gray
    
    // Helper properties to convert between Color and UIColor
    var uiColor: UIColor {
        UIColor(self)
    }
    
    init(uiColor: UIColor) {
        self.init(red: Double(uiColor.rgba.r),
                 green: Double(uiColor.rgba.g),
                 blue: Double(uiColor.rgba.b),
                 opacity: Double(uiColor.rgba.a))
    }
}

// Extension for UIColor to get RGBA components
extension UIColor {
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
} 