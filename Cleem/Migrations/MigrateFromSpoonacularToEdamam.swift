import Foundation
import Combine
import UIKit
import CoreData

/// Утилита для миграции с Spoonacular API на Edamam API
class SpoonacularToEdamamMigration {
    
    static let shared = SpoonacularToEdamamMigration()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Приватный инициализатор для синглтона
    }
    
    /// Главный метод миграции
    func migrateToEdamam(completion: @escaping (Bool, String) -> Void) {
        print("🔄 Начинаем миграцию с Spoonacular на Edamam API")
        
        // 1. Обновляем ключи API в UserDefaults
        updateApiKeys()
        
        // 2. Получаем данные из CoreData для пересчета
        let foods = getFoodsWithSpoonacularSource()
        
        if foods.isEmpty {
            print("✅ Нет данных для миграции с Spoonacular на Edamam")
            completion(true, "Миграция не требуется. Нет данных с источником Spoonacular.")
            return
        }
        
        print("🔄 Найдено \(foods.count) записей для пересчета")
        
        // 3. Пересчитываем данные с использованием Edamam
        migrateNutritionData(for: foods) { success, message in
            completion(success, message)
        }
    }
    
    /// Обновление ключей API в UserDefaults
    private func updateApiKeys() {
        // Метод для обновления/очистки API ключей
        
        // Удаляем Spoonacular API ключ, если он существует
        if UserDefaults.standard.object(forKey: "spoonacular_api_key") != nil {
            UserDefaults.standard.removeObject(forKey: "spoonacular_api_key")
        }
        
        // Проверяем, что ключи Edamam установлены
        if UserDefaults.standard.string(forKey: "edamam_app_id") == nil {
            UserDefaults.standard.set("", forKey: "edamam_app_id")
        }
        
        if UserDefaults.standard.string(forKey: "edamam_app_key") == nil {
            UserDefaults.standard.set("", forKey: "edamam_app_key")
        }
        
        print("✅ API ключи обновлены в UserDefaults")
    }
    
    /// Получение записей из CoreData с источником Spoonacular
    private func getFoodsWithSpoonacularSource() -> [RecognizedFoodV2] {
        var foods: [RecognizedFoodV2] = []
        
        // Используем CoreDataManager вместо AppDelegate
        let context = CoreDataManager.shared.context
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "FoodItem")
        fetchRequest.predicate = NSPredicate(format: "nutritionSource CONTAINS[cd] %@", "spoonacular")
        
        do {
            let result = try context.fetch(fetchRequest) as! [NSManagedObject]
            
            for data in result {
                if let name = data.value(forKey: "name") as? String,
                   let calories = data.value(forKey: "calories") as? Double,
                   let protein = data.value(forKey: "protein") as? Double,
                   let fat = data.value(forKey: "fat") as? Double,
                   let carbs = data.value(forKey: "carbs") as? Double {
                    
                    let sugar = data.value(forKey: "sugar") as? Double
                    let fiber = data.value(forKey: "fiber") as? Double
                    let sodium = data.value(forKey: "sodium") as? Double
                    let cholesterol = data.value(forKey: "cholesterol") as? Double
                    let id = data.value(forKey: "id") as? UUID
                    
                    let nutritionData = NutritionDataV2(
                        calories: calories,
                        protein: protein,
                        fat: fat,
                        carbs: carbs,
                        sugar: sugar,
                        fiber: fiber,
                        sodium: sodium,
                        source: "spoonacular",
                        foodLabel: name,
                        cholesterol: cholesterol,
                        servingSize: 100.0,
                        servingUnit: "g"
                    )
                    
                    // Гарантированно получаем UUID
                    let foodId: UUID
                    if let safeId = id {
                        foodId = safeId
                    } else {
                        foodId = UUID()
                    }
                    
                    let food = RecognizedFoodV2(
                        id: foodId,
                        name: name,
                        confidence: 1.0,
                        nutritionData: nutritionData,
                        originalImage: nil,
                        ingredients: nil
                    )
                    
                    foods.append(food)
                }
            }
        } catch {
            print("🔴 Ошибка при получении данных: \(error)")
            return []
        }
        
        return foods
    }
    
    /// Миграция данных о питательной ценности с использованием Edamam API
    private func migrateNutritionData(for foods: [RecognizedFoodV2], completion: @escaping (Bool, String) -> Void) {
        // Проверяем наличие ключей Edamam
        let edamamAppId = UserDefaults.standard.string(forKey: "edamam_app_id") ?? ""
        let edamamAppKey = UserDefaults.standard.string(forKey: "edamam_app_key") ?? ""
        
        guard !edamamAppId.isEmpty, !edamamAppKey.isEmpty else {
            print("⚠️ Отсутствуют ключи Edamam API")
            completion(false, "Отсутствуют ключи Edamam API. Пожалуйста, установите их в настройках.")
            return
        }
        
        // Если нет записей для обработки
        if foods.isEmpty {
            completion(true, "Миграция успешно завершена. Записей для обработки не найдено.")
            return
        }
        
        // Создаем очередь для безопасного доступа к счетчику
        let counterQueue = DispatchQueue(label: "com.cleem.migrationCounter")
        var migratedCount = 0
        let totalCount = foods.count
        
        // Создаем массив задач
        for food in foods {
            // Используем значение name напрямую, так как оно неопциональное
            let foodName = food.name
            
            // Если имя пустое, пропускаем
            if foodName.isEmpty {
                continue // Пропускаем продукты с пустым именем
            }
            
            // food.id это неопциональный UUID, поэтому просто используем его
            let foodId: UUID = food.id
            
            requestNutritionData(foodName: foodName, id: foodId, edamamAppId: edamamAppId, edamamAppKey: edamamAppKey) { 
                // Безопасно увеличиваем счетчик обработанных записей и проверяем завершение
                counterQueue.sync {
                    migratedCount += 1
                    print("🔄 Обработано \(migratedCount) из \(totalCount) записей")
                    
                    // Если обработали все записи, выполняем завершение
                    if migratedCount == totalCount {
                        DispatchQueue.main.async {
                            completion(true, "Миграция успешно завершена. Обработано \(migratedCount) записей.")
                        }
                    }
                }
            }
        }
    }
    
    /// Запрос данных о питательной ценности из Edamam API и обновление в CoreData
    private func requestNutritionData(foodName: String, id: UUID, edamamAppId: String, edamamAppKey: String, completion: @escaping () -> Void) {
        // Перевод русских названий на английский
        let translatedName = translateFoodNameToEnglish(foodName)
        
        let urlString = "https://api.edamam.com/api/nutrition-data"
        guard var urlComponents = URLComponents(string: urlString) else {
            print("⚠️ Неверный URL для запроса к Edamam API")
            completion()
            return
        }
        
        // Добавляем параметры запроса с переведенным названием
        urlComponents.queryItems = [
            URLQueryItem(name: "app_id", value: edamamAppId),
            URLQueryItem(name: "app_key", value: edamamAppKey),
            URLQueryItem(name: "ingr", value: "100g \(translatedName)")
        ]
        
        guard let url = urlComponents.url else {
            print("⚠️ Не удалось создать URL с параметрами")
            completion()
            return
        }
        
        print("🌐 Запрос к Edamam: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { completion() }
            
            guard let self = self, let data = data, error == nil else {
                print("⚠️ Ошибка при запросе к Edamam API: \(error?.localizedDescription ?? "неизвестная ошибка")")
                return
            }
            
            // Декодируем и обрабатываем ответ
            do {
                let response = try JSONDecoder().decode(EdamamNutritionResponse.self, from: data)
                
                // Извлекаем нутриенты
                let calories = response.totalNutrients.ENERC_KCAL?.quantity ?? 0
                let protein = response.totalNutrients.PROCNT?.quantity ?? 0
                let fat = response.totalNutrients.FAT?.quantity ?? 0
                let carbs = response.totalNutrients.CHOCDF?.quantity ?? 0
                let sugar = response.totalNutrients.SUGAR?.quantity
                let fiber = response.totalNutrients.FIBTG?.quantity
                let sodium = response.totalNutrients.NA?.quantity
                let cholesterol = response.totalNutrients.CHOLE?.quantity
                
                // Обновляем данные в CoreData
                DispatchQueue.main.async {
                    self.updateFoodInCoreData(
                        id: id,
                        calories: calories,
                        protein: protein, 
                        fat: fat, 
                        carbs: carbs, 
                        sugar: sugar, 
                        fiber: fiber, 
                        sodium: sodium, 
                        cholesterol: cholesterol
                    )
                    
                    print("✅ Обновлены данные для \(foodName)")
                }
            } catch {
                print("⚠️ Ошибка декодирования ответа от Edamam API: \(error)")
            }
        }.resume()
    }
    
    /// Метод для перевода названий продуктов с русского на английский
    private func translateFoodNameToEnglish(_ russianName: String) -> String {
        // Проверяем, не пустая ли строка
        guard !russianName.isEmpty else {
            return russianName
        }
        
        // Базовый URL для Google Translate API
        let urlString = "https://translation.googleapis.com/language/translate/v2"
        guard var urlComponents = URLComponents(string: urlString) else {
            print("⚠️ Неверный URL для API перевода")
            return russianName
        }
        
        // Получаем API ключ из UserDefaults или используем дефолтный
        let apiKey = UserDefaults.standard.string(forKey: "google_translate_api_key") ?? "AIzaSyBKaHxMvfr2PJ4T5_sJNGd9pc9PfOXaURs"
        
        // Добавляем параметры запроса
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: russianName),
            URLQueryItem(name: "source", value: "ru"),
            URLQueryItem(name: "target", value: "en")
        ]
        
        guard let url = urlComponents.url else {
            print("⚠️ Не удалось создать URL с параметрами для перевода")
            return russianName
        }
        
        print("🌐 Запрос на перевод: \(russianName)")
        
        // Создаем запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Создаем семафор для синхронного запроса
        let semaphore = DispatchSemaphore(value: 0)
        
        // Переменные для результата
        var translatedText = russianName
        
        // Выполняем запрос
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            guard let data = data, error == nil else {
                print("⚠️ Ошибка при запросе перевода: \(error?.localizedDescription ?? "неизвестная ошибка")")
                return
            }
            
            // Пытаемся десериализовать JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataObject = json["data"] as? [String: Any],
                   let translations = dataObject["translations"] as? [[String: Any]],
                   let firstTranslation = translations.first,
                   let translation = firstTranslation["translatedText"] as? String {
                    translatedText = translation
                    print("🔄 Перевод: '\(russianName)' -> '\(translation)'")
                } else {
                    print("⚠️ Неожиданный формат ответа от API перевода")
                }
            } catch {
                print("⚠️ Ошибка парсинга JSON: \(error)")
            }
        }
        
        // Запускаем задачу
        task.resume()
        
        // Ждем выполнения запроса
        _ = semaphore.wait(timeout: .now() + 5)
        
        return translatedText
    }
    
    /// Обновление данных в CoreData
    private func updateFoodInCoreData(id: UUID, calories: Double, protein: Double, fat: Double, carbs: Double, sugar: Double?,
        fiber: Double?, sodium: Double?, cholesterol: Double?) {
        // Используем CoreDataManager вместо AppDelegate
        let context = CoreDataManager.shared.context
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "FoodItem")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            if let result = try context.fetch(fetchRequest) as? [NSManagedObject], let foodItem = result.first {
                // Обновляем питательные вещества
                foodItem.setValue(calories, forKey: "calories")
                foodItem.setValue(protein, forKey: "protein")
                foodItem.setValue(fat, forKey: "fat")
                foodItem.setValue(carbs, forKey: "carbs")
                
                if let sugar = sugar {
                    foodItem.setValue(sugar, forKey: "sugar")
                }
                
                if let fiber = fiber {
                    foodItem.setValue(fiber, forKey: "fiber")
                }
                
                if let sodium = sodium {
                    foodItem.setValue(sodium, forKey: "sodium")
                }
                
                if let cholesterol = cholesterol {
                    foodItem.setValue(cholesterol, forKey: "cholesterol")
                }
                
                // Обновляем источник данных
                foodItem.setValue("edamam", forKey: "nutritionSource")
                
                try context.save()
            }
        } catch {
            print("⚠️ Ошибка при обновлении данных в CoreData: \(error)")
        }
    }
    
    // MARK: - Модели для Edamam API

    struct EdamamNutritionResponse: Decodable {
        let totalNutrients: TotalNutrients
    }

    struct TotalNutrients: Decodable {
        let ENERC_KCAL: Nutrient?
        let PROCNT: Nutrient?
        let FAT: Nutrient?
        let CHOCDF: Nutrient?
        let SUGAR: Nutrient?
        let FIBTG: Nutrient?
        let NA: Nutrient?
        let CHOLE: Nutrient?
    }

    struct Nutrient: Decodable {
        let quantity: Double
        let unit: String
    }
} 