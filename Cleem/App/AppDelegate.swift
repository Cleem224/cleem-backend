import Foundation
import UIKit
import SwiftUI
import CoreData
// Удаляем условный импорт
// #if canImport(GoogleSignIn)
// import GoogleSignIn
// #endif

// Ensure GoogleSignInURLHandler is available
// This is a custom import for the App.swift file where GoogleSignInURLHandler is defined

// AppDelegate to handle application lifecycle events
class AppDelegate: NSObject, ObservableObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: Приложение запущено")
        
        // Инициализация GoogleSignIn
        print("AppDelegate: Инициализация GoogleSignInLinker")
        GoogleSignInLinker.shared.registerClasses()
        
        // Устанавливаем значение use_new_recognition в true по умолчанию
        UserDefaults.standard.set(true, forKey: "use_new_recognition")
        
        // Инициализация API ключей только для менеджера
        FoodRecognitionManagerV2.initializeApiKeys()
        
        // Создаем глобальный UIFont без специфичных для системы знаков
        setupCustomFont()
        
        // Configure Logging
        setupLogger()
        
        // Инициализация значений по умолчанию, если их нет
        initializeUserDefaults()
        
        // Debug CoreData - проверяем, есть ли продукты в базе данных при запуске
        debugCheckFoodItems()
        
        return true
    }
    
    // Обработка URL для Google Sign-In
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("AppDelegate: Обработка URL \(url)")
        // Используем GoogleSignInURLHandler для обработки URL
        return GoogleSignInURLHandler.shared.handleURL(app, open: url, options: options)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("AppDelegate: Приложение закрывается, сохраняем данные")
        // Save CoreData context
        CoreDataManager.shared.saveContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("AppDelegate: Приложение уходит в фон, сохраняем данные")
        // Save CoreData context
        CoreDataManager.shared.saveContext()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("AppDelegate: Приложение теряет активность, сохраняем данные")
        // Save CoreData context
        CoreDataManager.shared.saveContext()
    }
    
    // Метод для создания глобального UIFont без специфичных для системы знаков
    private func setupCustomFont() {
        print("AppDelegate: Настройка пользовательского шрифта")
        // Здесь можно настроить пользовательский шрифт, если необходимо
        // Например:
        // UIFont.familyNames.forEach { print($0) }
    }
    
    // Метод для настройки логирования
    private func setupLogger() {
        print("AppDelegate: Настройка логирования")
        // Здесь можно настроить систему логирования
    }
    
    // Метод для гарантированной инициализации UserDefaults
    private func initializeUserDefaults() {
        print("AppDelegate: Инициализация UserDefaults")
        
        // Всегда удаляем lastAppleImage при запуске приложения
        UserDefaults.standard.removeObject(forKey: "lastAppleImage")
        
        // Проверяем и инициализируем foodHistory
        if UserDefaults.standard.object(forKey: "foodHistory") == nil {
            print("AppDelegate: Создание пустого массива foodHistory в UserDefaults")
            UserDefaults.standard.set([], forKey: "foodHistory")
        }
        
        // Проверяем есть ли данные о еде и отображаем для отладки
        if let foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] {
            print("AppDelegate: foodHistory уже существует, найдено \(foodHistory.count) записей")
            
            // Фильтруем яблоки при инициализации приложения
            var filteredFoodHistory = foodHistory
            let initialCount = filteredFoodHistory.count
            
            // Удаляем все записи с "apple" в названии, если они не являются последним отсканированным продуктом
            let lastScannedFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID")
            filteredFoodHistory.removeAll { item in
                if let name = item["name"] as? String,
                   name.lowercased() == "apple",
                   let id = item["id"] as? String,
                   id != lastScannedFoodID {
                    print("AppDelegate: 🍎 Удаляем Apple из истории еды для предотвращения появления по умолчанию")
                    return true
                }
                return false
            }
            
            // Если мы удалили яблоки из истории, сохраняем обновленную историю
            if initialCount != filteredFoodHistory.count {
                UserDefaults.standard.set(filteredFoodHistory, forKey: "foodHistory")
                UserDefaults.standard.synchronize()
                print("AppDelegate: Удалено \(initialCount - filteredFoodHistory.count) яблок из истории еды")
            }
        } else {
            print("AppDelegate: Ошибка - foodHistory не найден в UserDefaults после инициализации")
        }
        
        // Проверяем, синхронизированы ли данные
        UserDefaults.standard.synchronize()
    }
    
    // Функция для отладки - проверяет наличие продуктов в базе данных при запуске
    private func debugCheckFoodItems() {
        DispatchQueue.main.async {
            let context = CoreDataManager.shared.context
            let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
            
            do {
                let foods = try context.fetch(fetchRequest)
                print("DEBUG - При запуске найдено продуктов в CoreData: \(foods.count)")
                
                // Проверяем и удаляем дефолтные яблоки, которые создаются при инициализации
                var applesToDelete = [Food]()
                
                // Получаем ID последнего отсканированного продукта
                let lastScannedFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID")
                
                for food in foods {
                    // Находим яблоки, которые не являются последним отсканированным продуктом
                    if let name = food.name?.lowercased(),
                       name == "apple",
                       let foodId = food.id?.uuidString,
                       foodId != lastScannedFoodID {
                        print("DEBUG - 🍎 Найдено Apple для удаления: ID=\(foodId)")
                        applesToDelete.append(food)
                    }
                }
                
                // Удаляем найденные яблоки
                if !applesToDelete.isEmpty {
                    print("DEBUG - Удаляем \(applesToDelete.count) яблок из CoreData")
                    for apple in applesToDelete {
                        context.delete(apple)
                    }
                    try context.save()
                    
                    // Очищаем кэш
                    context.refreshAllObjects()
                }
                
                if !foods.isEmpty {
                    for (index, food) in foods.enumerated() {
                        print("  \(index+1). \(food.name ?? "Unknown") (ID: \(food.id?.uuidString ?? "nil"), создан: \(food.createdAt?.description ?? "nil"))")
                        
                        // Восстанавливаем последний отсканированный продукт если ID совпадает
                        if let lastFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID"),
                           let foodId = food.id?.uuidString,
                           foodId == lastFoodID {
                            print("НАЙДЕН последний отсканированный продукт, устанавливаем в NavigationCoordinator")
                            NavigationCoordinator.shared.recentlyScannedFood = food
                            
                            // Отправляем уведомление для обновления интерфейса
                            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                        }
                    }
                }
            } catch {
                print("DEBUG - Ошибка при проверке продуктов в CoreData: \(error)")
            }
        }
    }
}
