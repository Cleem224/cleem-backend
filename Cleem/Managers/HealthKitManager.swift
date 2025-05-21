import Foundation
import HealthKit
import Combine
import Security

// Helper class to store authorization status in Keychain
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    func saveBoolean(_ value: Bool, for key: String) -> Bool {
        let data = Data([value ? 1 : 0])
        return saveData(data, for: key)
    }
    
    func getBoolean(for key: String) -> Bool? {
        guard let data = getData(for: key), data.count > 0 else {
            return nil
        }
        return data[0] == 1
    }
    
    private func saveData(_ data: Data, for key: String) -> Bool {
        // Create query
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        // Delete existing key first
        SecItemDelete(query as CFDictionary)
        
        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getData(for key: String) -> Data? {
        // Create query
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        // Get result
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    func removeData(for key: String) -> Bool {
        // Create query
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        // Delete
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

class HealthKitManager: ObservableObject {
    // Shared instance for singleton access
    static let shared = HealthKitManager()
    
    // Available health store
    private let healthStore = HKHealthStore()
    
    // Published properties for steps and calories
    @Published var steps: Int = 0
    @Published var caloriesBurned: Double = 0
    @Published var stepsCalories: Double = 0 // Новая переменная для отслеживания калорий от шагов
    @Published var activityCalories: Double = 0 // Новая переменная для отслеживания калорий от активностей
    @Published var isAuthorized: Bool = false
    @Published var isLoading: Bool = false
    
    // Cancellables for combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Timer for updating data
    private var updateTimer: Timer?
    
    // Timestamp of the last data update
    private var lastUpdateTime: Date = Date(timeIntervalSince1970: 0)
    // Minimal interval between updates (1 minute)
    private let minUpdateInterval: TimeInterval = 60
    
    // Флаг, указывающий, что данные уже были обновлены в текущей сессии
    private var dataUpdatedThisSession: Bool = false
    
    // Keychain keys
    private let authStatusKey = "com.cleem.healthkit.authorization.status"
    
    // Private initialization
    private init() {
        print("HealthKitManager initializing, checking if HealthKit is available")
        
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        // Load initial state from Keychain and UserDefaults for redundancy
        if let keychainStatus = KeychainHelper.shared.getBoolean(for: authStatusKey) {
            isAuthorized = keychainStatus
            print("Initial authorization status from Keychain: \(isAuthorized)")
        } else {
            // Fallback to UserDefaults if not in Keychain
            isAuthorized = UserDefaults.standard.bool(forKey: authStatusKey)
            print("Initial authorization status from UserDefaults: \(isAuthorized)")
            
            // Make sure we save this to Keychain right away
            _ = KeychainHelper.shared.saveBoolean(isAuthorized, for: authStatusKey)
        }
        
        // Восстанавливаем калории от активностей из истории
        restoreActivityCaloriesFromHistory()
        
        // Always verify the real status
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkRealAuthorizationStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Force check the true authorization status with HealthKit
    func forceCheckAuthorization() {
        checkRealAuthorizationStatus()
    }
    
    /// Request authorization for reading health data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        isLoading = true
        
        // Define the types of data we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isLoading = false
                
                if success {
                    print("HealthKit authorization granted")
                    
                    // Update our published property
                    self.isAuthorized = true
                    
                    // Save to Keychain first (most reliable)
                    _ = KeychainHelper.shared.saveBoolean(true, for: self.authStatusKey)
                    
                    // Also save to UserDefaults as backup
                    UserDefaults.standard.set(true, forKey: self.authStatusKey)
                    UserDefaults.standard.synchronize()
                    
                    print("Authorization status saved to Keychain and UserDefaults")
                    
                    // Start fetching data if authorized
                    self.startFetchingHealthData()
                    
                    // Double-check the authorization status after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.checkRealAuthorizationStatus()
                    }
                } else {
                    print("HealthKit authorization failed: \(String(describing: error))")
                    
                    // Update our published property
                    self.isAuthorized = false
                    
                    // Save to Keychain and UserDefaults
                    _ = KeychainHelper.shared.saveBoolean(false, for: self.authStatusKey)
                    UserDefaults.standard.set(false, forKey: self.authStatusKey)
                    UserDefaults.standard.synchronize()
                }
                
                completion(success, error)
            }
        }
    }
    
    /// Start fetching health data once per app launch
    func startFetchingHealthData() {
        // Проверяем, обновлялись ли данные в этой сессии
        if !dataUpdatedThisSession {
            print("Fetching health data (first update this session)")
            
            // Обновляем флаг
            dataUpdatedThisSession = true
            
            // Обновляем timestamp
            lastUpdateTime = Date()
            
            // Fetch data
            fetchTodaySteps()
            fetchTodayCaloriesBurned()
            
            // Cancel existing timer if any
            updateTimer?.invalidate()
            
            // Set up timer to update every 15 minutes in background (для редких фоновых обновлений)
            updateTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
                print("Timer triggered rare background health data update")
                self?.lastUpdateTime = Date()
                self?.fetchTodaySteps()
                self?.fetchTodayCaloriesBurned()
            }
        } else {
            print("Skipping health data update (already updated this session)")
        }
    }
    
    /// Stop fetching health data
    func stopFetchingHealthData() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Reset authorization status (for debugging)
    func resetAuthorizationStatus() {
        print("Resetting HealthKit authorization status")
        
        // Clear from Keychain
        _ = KeychainHelper.shared.removeData(for: authStatusKey)
        
        // Clear from UserDefaults too
        UserDefaults.standard.set(false, forKey: authStatusKey)
        UserDefaults.standard.synchronize()
        
        // Update published property
        isAuthorized = false
        
        // Stop any active timers
        stopFetchingHealthData()
        
        // Reset data
        steps = 0
        caloriesBurned = 0
        stepsCalories = 0
        activityCalories = 0
    }
    
    /// Сбросить флаг обновления данных в текущей сессии
    /// Вызывается при завершении работы приложения
    func resetSessionUpdateFlag() {
        print("Resetting session update flag")
        dataUpdatedThisSession = false
    }
    
    /// Добавить сожженные калории от тренировки
    func addBurnedCalories(calories: Double, activity: String, duration: Int) {
        // Увеличиваем количество калорий от активностей
        self.activityCalories += calories
        
        // Обновляем общее количество сожженных калорий
        updateTotalCaloriesBurned()
        
        print("Added \(calories) calories burned from \(activity) (\(duration) mins). Activities calories: \(self.activityCalories), Total burned: \(self.caloriesBurned)")
        
        // Сохраняем тренировку в базу данных или UserDefaults для истории
        saveTrainingToHistory(calories: calories, activity: activity, duration: duration)
    }
    
    /// Subtract burned calories when an activity is deleted
    func subtractBurnedCalories(calories: Double) {
        // Уменьшаем количество калорий от активностей
        self.activityCalories = max(0, self.activityCalories - calories)
        
        // Обновляем общее количество сожженных калорий
        updateTotalCaloriesBurned()
        
        print("Subtracted \(calories) calories. New activities calories: \(self.activityCalories), Total burned: \(self.caloriesBurned)")
    }
    
    /// Сохранить тренировку в историю
    private func saveTrainingToHistory(calories: Double, activity: String, duration: Int) {
        // Получаем текущую дату и время
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: date)
        
        // Создаем уникальный идентификатор для тренировки
        let activityId = UUID().uuidString
        
        // Создаем структуру данных тренировки
        let trainingData: [String: Any] = [
            "id": activityId, // Добавляем уникальный идентификатор
            "activity": activity,
            "calories": calories,
            "duration": duration,
            "date": date,
            "time": timeString,
            "timeRaw": date.timeIntervalSince1970 // Добавляем временную метку в секундах
        ]
        
        // Получаем существующую историю тренировок
        var trainingsHistory = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] ?? []
        
        // Добавляем новую тренировку в начало массива (чтобы новые были сверху)
        trainingsHistory.insert(trainingData, at: 0)
        
        // Ограничиваем историю последними 50 тренировками
        if trainingsHistory.count > 50 {
            trainingsHistory = Array(trainingsHistory.prefix(50))
        }
        
        // Сохраняем обновленную историю
        UserDefaults.standard.set(trainingsHistory, forKey: "trainingsHistory")
        UserDefaults.standard.synchronize()
        
        print("Training saved to history: \(activity), \(calories) calories, \(duration) mins, id: \(activityId)")
        
        // Отправляем уведомление об обновлении истории тренировок
        NotificationCenter.default.post(name: NSNotification.Name("TrainingHistoryUpdated"), object: nil)
    }
    
    /// Удалить активность по идентификатору и вычесть её калории
    func deleteActivityById(activityId: String) {
        // Получаем существующую историю тренировок
        if var trainingsHistory = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] {
            // Находим активность с указанным ID
            if let index = trainingsHistory.firstIndex(where: { ($0["id"] as? String) == activityId }),
               let deletedCalories = trainingsHistory[index]["calories"] as? Double {
                
                // Удаляем активность из массива
                trainingsHistory.remove(at: index)
                
                // Сохраняем обновленную историю
                UserDefaults.standard.set(trainingsHistory, forKey: "trainingsHistory")
                UserDefaults.standard.synchronize()
                
                // Уменьшаем количество калорий от активностей
                self.activityCalories = max(0, self.activityCalories - deletedCalories)
                
                // Обновляем общее количество сожженных калорий
                updateTotalCaloriesBurned()
                
                // Отправляем уведомление об обновлении истории тренировок
                NotificationCenter.default.post(name: NSNotification.Name("TrainingHistoryUpdated"), object: nil)
                
                print("Deleted activity with id: \(activityId), subtracted \(deletedCalories) calories. New total burned: \(self.caloriesBurned)")
            } else {
                print("Activity with id \(activityId) not found in history")
            }
        }
    }
    
    /// Add manual training activity
    func addManualTraining(activity: String, calories: Double, duration: Int) {
        // Создаем уникальный идентификатор для активности
        let activityId = UUID().uuidString
        
        // Получаем текущую дату и время
        let date = Date()
        
        // Форматируем текущее время
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)
        
        // Создаем словарь с данными активности
        let trainingData: [String: Any] = [
            "id": activityId,
            "activity": activity,
            "calories": calories,
            "duration": duration,
            "time": timeString,
            "date": date, // Добавляем дату для возможности фильтрации по дням
            "timeRaw": date.timeIntervalSince1970 // Добавляем временную метку в секундах
        ]
        
        // Получаем существующую историю тренировок или создаем новую
        var trainingsHistory = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] ?? []
        
        // Добавляем новую активность в начало массива
        trainingsHistory.insert(trainingData, at: 0)
        
        // Ограничиваем размер истории
        if trainingsHistory.count > 50 {
            trainingsHistory = Array(trainingsHistory.prefix(50))
        }
        
        // Сохраняем обновленную историю
        UserDefaults.standard.set(trainingsHistory, forKey: "trainingsHistory")
        UserDefaults.standard.synchronize()
        
        // Добавляем калории от новой активности
        self.activityCalories += calories
        
        // Обновляем общее количество сожженных калорий
        updateTotalCaloriesBurned()
        
        // Отправляем уведомление об обновлении истории тренировок
        NotificationCenter.default.post(name: NSNotification.Name("TrainingHistoryUpdated"), object: nil)
        
        print("Added manual training: \(activity), \(calories) calories, \(duration) minutes. New total burned: \(self.caloriesBurned)")
    }
    
    // MARK: - Private Methods
    
    /// Check the true authorization status directly with HealthKit
    private func checkRealAuthorizationStatus() {
        // Define the types to check
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let calorieType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        // Check authorization status for each type
        let stepStatus = healthStore.authorizationStatus(for: stepType)
        let calorieStatus = healthStore.authorizationStatus(for: calorieType)
        
        // Log the status for debugging
        print("Real HealthKit authorization status: steps=\(stepStatus), calories=\(calorieStatus)")
        
        // If either type is authorized, consider it authorized (relaxed condition)
        let newAuthStatus = (stepStatus == .sharingAuthorized || calorieStatus == .sharingAuthorized)
        
        // If HealthKit API shows this as authorized, respect that
        if newAuthStatus == true {
            // Always set to true if HealthKit says it's authorized
            if !isAuthorized {
                print("Updating authorization status to TRUE based on HealthKit API")
                isAuthorized = true
                
                // Save to Keychain first (most reliable)
                let keychainSaved = KeychainHelper.shared.saveBoolean(true, for: authStatusKey)
                print("Saved to Keychain: \(keychainSaved)")
                
                // Also save to UserDefaults as backup
                UserDefaults.standard.set(true, forKey: authStatusKey)
                UserDefaults.standard.synchronize()
                
                // Start fetching data
                startFetchingHealthData()
            }
        } else {
            // Only update to false if we're REALLY sure it's not authorized
            // Check our saved status first
            let keychainStatus = KeychainHelper.shared.getBoolean(for: authStatusKey)
            let userDefaultsStatus = UserDefaults.standard.bool(forKey: authStatusKey)
            
            print("Saved authorization: Keychain=\(String(describing: keychainStatus)), UserDefaults=\(userDefaultsStatus)")
            
            // If either saved status is true, prefer that over HealthKit API
            if keychainStatus == true || userDefaultsStatus == true {
                print("Keeping authorization as TRUE based on saved status")
                
                // Make sure our published property is consistent
                if !isAuthorized {
                    isAuthorized = true
                    startFetchingHealthData()
                }
            } else if isAuthorized {
                // Only change from true to false if both saved statuses are false
                print("Updating authorization status to FALSE based on HealthKit API and saved status")
                isAuthorized = false
                
                // Update saved values
                _ = KeychainHelper.shared.saveBoolean(false, for: authStatusKey)
                UserDefaults.standard.set(false, forKey: authStatusKey)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    /// Fetch today's steps
    private func fetchTodaySteps() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("Step count type is not available")
            return
        }
        
        // Get steps for today
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, let result = result, let sum = result.sumQuantity() else {
                if let error = error {
                    print("Error fetching step count: \(error.localizedDescription)")
                }
                return
            }
            
            // Update the steps property on the main thread
            DispatchQueue.main.async {
                let newSteps = Int(sum.doubleValue(for: HKUnit.count()))
                self.steps = newSteps
                
                // Рассчитываем калории от шагов (примерно 0.05 ккал на шаг)
                let newStepsCalories = Double(newSteps) * 0.05
                self.stepsCalories = newStepsCalories
                
                // Обновляем общее количество сожженных калорий
                self.updateTotalCaloriesBurned()
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Fetch today's calories burned
    private func fetchTodayCaloriesBurned() {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("Active energy burned type is not available")
            return
        }
        
        // Get calories burned for today
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, error in
            guard let self = self, let result = result, let sum = result.sumQuantity() else {
                if let error = error {
                    print("Error fetching calories burned: \(error.localizedDescription)")
                }
                return
            }
            
            // Update the caloriesBurned property on the main thread
            DispatchQueue.main.async {
                // Сохраняем калории из HealthKit отдельно (это калории от активностей, записанные в HealthKit)
                let healthKitCalories = sum.doubleValue(for: HKUnit.kilocalorie())
                
                // Обновляем общее количество сожженных калорий
                self.updateTotalCaloriesBurned()
            }
        }
        
        healthStore.execute(query)
    }
    
    /// Обновляет общее количество сожженных калорий
    private func updateTotalCaloriesBurned() {
        // Учитываем калории от шагов и от активностей
        let totalCalories = stepsCalories + activityCalories
        
        // Если значение изменилось, обновляем опубликованное свойство
        if totalCalories != caloriesBurned {
            caloriesBurned = totalCalories
            print("Обновлено общее количество сожженных калорий: \(caloriesBurned) (шаги: \(stepsCalories), активности: \(activityCalories))")
            
            // Оповещаем об изменении
            objectWillChange.send()
        }
    }
    
    /// Calculate calories burned from steps
    func calculateCaloriesFromSteps(steps: Int, weightKg: Double, heightCm: Double, age: Int, gender: String, durationMinutes: Int = 30) -> Double {
        // Default values if user data is missing
        let effectiveWeight = weightKg > 0 ? weightKg : 70
        let effectiveHeight = heightCm > 0 ? heightCm : 170
        let effectiveAge = age > 0 ? age : 30
        
        // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
        let bmr: Double
        if gender.lowercased() == "male" {
            bmr = 10 * effectiveWeight + 6.25 * effectiveHeight - 5 * Double(effectiveAge) + 5
        } else {
            bmr = 10 * effectiveWeight + 6.25 * effectiveHeight - 5 * Double(effectiveAge) - 161
        }
        
        // Estimate calories burned per step (average person burns about 0.04 calories per step)
        let caloriesPerStep = 0.04 * (effectiveWeight / 70.0)  // Adjust based on weight
        let estimatedCalories = Double(steps) * caloriesPerStep
        
        return round(estimatedCalories)
    }
    
    /// Восстанавливает калории от активностей из истории тренировок
    private func restoreActivityCaloriesFromHistory() {
        // Получаем существующую историю тренировок только за сегодня
        if let trainingsHistory = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] {
            // Получаем текущую дату
            let today = Calendar.current.startOfDay(for: Date())
            
            // Суммируем калории от всех активностей за сегодня
            var sumCalories = 0.0
            
            for trainingData in trainingsHistory {
                // Проверяем, есть ли дата в записи
                if let trainingDate = trainingData["date"] as? Date,
                   let calories = trainingData["calories"] as? Double {
                    // Получаем начало дня для даты тренировки
                    let trainingDay = Calendar.current.startOfDay(for: trainingDate)
                    
                    // Если тренировка была сегодня, добавляем калории
                    if trainingDay == today {
                        sumCalories += calories
                    }
                }
            }
            
            // Устанавливаем калории от активностей
            if sumCalories > 0 {
                self.activityCalories = sumCalories
                print("Восстановлено \(sumCalories) калорий от активностей из истории")
                
                // Обновляем общее количество сожженных калорий
                updateTotalCaloriesBurned()
            }
        }
    }
    
    // MARK: - Static Methods
    
    /// Создает временный экземпляр HealthKitManager для отображения исторических данных
    static func createTemporary(steps: Int, stepsCalories: Double, activityCalories: Double, trainingsHistory: [[String: Any]]) -> HealthKitManager {
        let tempManager = HealthKitManager.shared
        
        // Создаем копию HealthKitManager с новыми значениями
        let temporaryManager = HealthKitManager()
        temporaryManager.steps = steps
        temporaryManager.stepsCalories = stepsCalories
        temporaryManager.activityCalories = activityCalories
        
        // Устанавливаем общие сожженные калории как сумму
        temporaryManager.caloriesBurned = stepsCalories + activityCalories
        
        // Важно: не переопределяем другие свойства, такие как isAuthorized,
        // так как они должны соответствовать реальному состоянию
        temporaryManager.isAuthorized = tempManager.isAuthorized
        
        // Если нужно отобразить тренировки для конкретной даты,
        // можно заменить trainingsHistory в UserDefaults, но только временно
        if !trainingsHistory.isEmpty {
            // Сохраняем оригинальную историю
            let originalHistory = UserDefaults.standard.array(forKey: "trainingsHistory")
            
            // Временно устанавливаем отфильтрованную историю
            UserDefaults.standard.set(trainingsHistory, forKey: "trainingsHistory")
            
            // Через короткое время восстанавливаем оригинальную историю
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UserDefaults.standard.set(originalHistory, forKey: "trainingsHistory")
                UserDefaults.standard.synchronize()
            }
        }
        
        return temporaryManager
    }
}

