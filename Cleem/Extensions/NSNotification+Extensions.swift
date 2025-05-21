import Foundation

// MARK: - Notification Names
// Это единственное место в приложении для определения имен уведомлений
// Не создавайте дублирующихся определений в других файлах!
extension Notification.Name {
    // Уведомления для сканирования пищи
    static let didCompleteFoodAnalysis = Notification.Name("didCompleteFoodAnalysis")
    static let didRecognizeBarcode = Notification.Name("didRecognizeBarcode")
    static let didFinishFoodAnalysis = Notification.Name("didFinishFoodAnalysis")
    static let didFinishBarcodeScanning = Notification.Name("didFinishBarcodeScanning")
    static let didCancelFoodAnalysis = Notification.Name("didCancelFoodAnalysis")
    
    // Уведомления для обновления интерфейса
    static let foodAnalyzedSuccessfully = Notification.Name("foodAnalyzedSuccessfully")
    
    // Уведомления для обновления данных пользователя
    static let nutritionValuesUpdated = Notification.Name("nutritionValuesUpdated")
    
    // Уведомления для навигации
    static let navigateToHomeScreen = Notification.Name("navigateToHomeScreen")
}
