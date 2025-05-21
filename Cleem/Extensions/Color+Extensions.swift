import SwiftUI

extension Color {
    // Welcome screen colors - более светлые тона
    static let welcomeYellowLight = Self.hex("FFF8D6")  // Очень светлый желтый сверху
    static let welcomeYellowDark = Self.hex("FFEB9C")   // Светло-желтый снизу
    static let welcomeButtonBackground = Self.hex("FFDE89") // Фон кнопки Get Started
    static let welcomeBrownText = Self.hex("663729")    // Темно-коричневый для текста
    
    // Существующие цвета из приложения
    static let appYellowBackground = Self.hex("FFECBC")
    static let appBrownText = Self.hex("663729")
    
    // Commented out duplicated colors - they are defined in CleemApp.swift
    // static let appBackground = Self.hex("D1EDFD")  // Светло-голубой фон (как на скриншоте)
    // static let appBackgroundPeach = Self.hex("FFE8D6") // Персиковый фон
    
    // Цвета нового дизайна домашнего экрана
    static let homeBackground = Self.hex("E2F2FF")  // Светло-голубой фон домашнего экрана (как на фото)
    static let homeCalendarSelected = Self.hex("000000")  // Черный цвет для выбранной даты
    static let homeCardBackground = Self.hex("EDEDED")  // Серый фон для карточек (как на фото)
    static let homeProgressRed = Self.hex("FF4D4D")  // Красный для круга прогресса протеина (как на фото)
    static let homeProgressBlue = Self.hex("3B82F6")  // Синий для круга прогресса углеводов (как на фото)
    static let homeProgressOrange = Self.hex("FF8533")  // Оранжевый для круга прогресса жиров (как на фото)
    
    // Статический метод создания цвета из hex строки вместо инициализатора
    static func hex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 