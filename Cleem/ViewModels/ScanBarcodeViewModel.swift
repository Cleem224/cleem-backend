import Foundation
import CoreData
import UIKit

class ScanBarcodeViewModel: ObservableObject {
    @Published var recognizedBarcode: String? = nil
    @Published var isScanning = false
    @Published var analyzedFood: Food?
    @Published var errorMessage: String? = nil
    
    private var viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataManager.shared.context) {
        self.viewContext = context
    }
    
    // Метод для сканирования штрих-кода
    func scanBarcode(barcode: String) {
        self.recognizedBarcode = barcode
        self.isScanning = true
        
        // Моделируем процесс запроса к API (в реальности здесь был бы API запрос)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // Для демонстрации создаем продукт на основе штрих-кода
            let newFood = Food(context: self.viewContext)
            newFood.id = UUID()
            
            // В реальном приложении информация приходила бы из API по штрихкоду
            // Для демонстрации используем тестовые данные
            newFood.name = "Product with barcode \(barcode)"
            newFood.calories = 120
            newFood.protein = 5
            newFood.fat = 3
            newFood.carbs = 18
            newFood.createdAt = Date()  // Используем createdAt вместо timestamp
            
            // Сохраняем в Core Data
            do {
                try self.viewContext.save()
                self.analyzedFood = newFood
                
                // Завершаем сканирование
                self.isScanning = false
                
                // Отправляем уведомление о завершении
                NotificationCenter.default.post(name: NSNotification.Name("BarcodeAnalysisCompleted"), object: nil)
            } catch {
                self.errorMessage = "Не удалось сохранить продукт: \(error.localizedDescription)"
                self.isScanning = false
            }
        }
    }
} 