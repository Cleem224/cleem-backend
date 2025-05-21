import Foundation
import SwiftUI
import Cleem
import Combine

class UserProfile: ObservableObject, Codable {
    // Shared instance
    static let shared = UserProfile()
    
    // Персональные данные
    @Published var name: String = ""
    @Published var dateOfBirth: Date? = nil
    @Published var age: Int = 30
    @Published var gender: Gender = .male
    
    // Физические параметры
    @Published var heightInCm: Int = 170
    @Published var weightInKg: Double = 70.0
    @Published var targetWeightInKg: Double = 65.0
    
    // Цели и предпочтения
    @Published var goal: Goal = .loseWeight
    @Published var fitnessGoal: FitnessGoal = .loseWeight // Для совместимости со старым кодом
    @Published var activityLevel: ActivityLevel = .sedentary
    @Published var diet: Diet = .none
    @Published var preferredLanguage: Language? = .english
    @Published var dailyStepsTarget: Int = 10000
    
    // Рассчитанные значения
    @Published var bmi: Double = 0.0
    @Published var dailyCalories: Double = 2000.0
    @Published var proteinInGrams: Double = 120.0
    @Published var carbsInGrams: Double = 200.0
    @Published var fatsInGrams: Double = 65.0
    
    // Свойства для обратной совместимости
    @Published var dailyCalorieTarget: Int = 2000
    @Published var proteinGramsTarget: Int = 125
    @Published var carbsGramsTarget: Int = 225
    @Published var fatGramsTarget: Int = 65
    
    // Свойства для отслеживания фактического потребления (для прогресс-кругов)
    @Published var consumedCalories: Double = 0.0
    @Published var consumedProtein: Double = 0.0
    @Published var consumedCarbs: Double = 0.0
    @Published var consumedFat: Double = 0.0
    
    // Флаг для управления автоматическим пересчетом нутриентов
    @Published var autoCalculateNutrients: Bool = true
    
    // Перечисления для пользовательских данных
    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }
    
    enum Goal: String, Codable, CaseIterable {
        case loseWeight = "Lose Weight"
        case maintainWeight = "Maintain Weight"
        case gainMuscle = "Gain Muscle"
    }
    
    // Для совместимости со старым кодом
    enum FitnessGoal: String, Codable, CaseIterable {
        case loseWeight = "Lose Weight"
        case maintain = "Maintain Weight"
        case gainMuscle = "Gain Muscle"
        
        var calorieAdjustment: Double {
            switch self {
            case .loseWeight: return 0.8  // 20% deficit
            case .maintain: return 1.0    // Maintain
            case .gainMuscle: return 1.15 // 15% surplus
            }
        }
    }
    
    enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary = "Sedentary"
        case lightlyActive = "Lightly Active"
        case moderatelyActive = "Moderately Active"
        case active = "Active"
        case veryActive = "Very Active"
        
        // Для совместимости со старым кодом
        static var light: ActivityLevel { return .lightlyActive }
        static var moderate: ActivityLevel { return .moderatelyActive }
        static var extraActive: ActivityLevel { return .veryActive }
        
        var activityMultiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .lightlyActive: return 1.375
            case .moderatelyActive: return 1.55
            case .active: return 1.725
            case .veryActive: return 1.9
            }
        }
    }
    
    enum Diet: String, Codable, CaseIterable {
        case none = "No specific diet"
        case keto = "Keto"
        case mediterranean = "Mediterranean"
        case intermittentFasting = "Intermittent Fasting"
        case dukan = "Dukan"
    }
    
    enum Language: String, Codable, CaseIterable {
        case english = "English"
        case russian = "Russian"
        case spanish = "Spanish"
        case french = "Français"
        case chinese = "中文"
        case german = "Deutsch"
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .russian: return "🇷🇺"
            case .spanish: return "🇪🇸"
            case .french: return "🇫🇷"
            case .chinese: return "🇨🇳"
            case .german: return "🇩🇪"
            }
        }
        
        var code: String {
            switch self {
            case .english: return "EN"
            case .russian: return "RU"
            case .spanish: return "ES"
            case .french: return "FR"
            case .chinese: return "CH"
            case .german: return "DE"
            }
        }
    }
    
    // CodingKeys для Codable
    enum CodingKeys: String, CodingKey {
        case name, dateOfBirth, age, gender, heightInCm, weightInKg, targetWeightInKg
        case goal, fitnessGoal, activityLevel, diet, preferredLanguage
        case bmi, dailyCalories, proteinInGrams, carbsInGrams, fatsInGrams
        case dailyCalorieTarget, proteinGramsTarget, carbsGramsTarget, fatGramsTarget
        case consumedCalories, consumedProtein, consumedCarbs, consumedFat
        case autoCalculateNutrients
        case dailyStepsTarget
    }
    
    // MARK: - Инициализаторы
    
    init() {
        calculateDailyTargets()
    }
    
    // MARK: - Codable
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 30
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender) ?? .male
        
        heightInCm = try container.decodeIfPresent(Int.self, forKey: .heightInCm) ?? 170
        weightInKg = try container.decodeIfPresent(Double.self, forKey: .weightInKg) ?? 70.0
        targetWeightInKg = try container.decodeIfPresent(Double.self, forKey: .targetWeightInKg) ?? 65.0
        
        goal = try container.decodeIfPresent(Goal.self, forKey: .goal) ?? .loseWeight
        fitnessGoal = try container.decodeIfPresent(FitnessGoal.self, forKey: .fitnessGoal) ?? .loseWeight
        activityLevel = try container.decodeIfPresent(ActivityLevel.self, forKey: .activityLevel) ?? .sedentary
        diet = try container.decodeIfPresent(Diet.self, forKey: .diet) ?? .none
        preferredLanguage = try container.decodeIfPresent(Language?.self, forKey: .preferredLanguage) ?? .english
        
        bmi = try container.decodeIfPresent(Double.self, forKey: .bmi) ?? 0.0
        dailyCalories = try container.decodeIfPresent(Double.self, forKey: .dailyCalories) ?? 2000.0
        proteinInGrams = try container.decodeIfPresent(Double.self, forKey: .proteinInGrams) ?? 120.0
        carbsInGrams = try container.decodeIfPresent(Double.self, forKey: .carbsInGrams) ?? 200.0
        fatsInGrams = try container.decodeIfPresent(Double.self, forKey: .fatsInGrams) ?? 65.0
        
        dailyCalorieTarget = try container.decodeIfPresent(Int.self, forKey: .dailyCalorieTarget) ?? 2000
        proteinGramsTarget = try container.decodeIfPresent(Int.self, forKey: .proteinGramsTarget) ?? 125
        carbsGramsTarget = try container.decodeIfPresent(Int.self, forKey: .carbsGramsTarget) ?? 225
        fatGramsTarget = try container.decodeIfPresent(Int.self, forKey: .fatGramsTarget) ?? 65
        
        // Декодируем значения потребления (по умолчанию 0)
        consumedCalories = try container.decodeIfPresent(Double.self, forKey: .consumedCalories) ?? 0.0
        consumedProtein = try container.decodeIfPresent(Double.self, forKey: .consumedProtein) ?? 0.0
        consumedCarbs = try container.decodeIfPresent(Double.self, forKey: .consumedCarbs) ?? 0.0
        consumedFat = try container.decodeIfPresent(Double.self, forKey: .consumedFat) ?? 0.0
        
        autoCalculateNutrients = try container.decodeIfPresent(Bool.self, forKey: .autoCalculateNutrients) ?? true
        
        dailyStepsTarget = try container.decodeIfPresent(Int.self, forKey: .dailyStepsTarget) ?? 10000
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(dateOfBirth, forKey: .dateOfBirth)
        try container.encode(age, forKey: .age)
        try container.encode(gender, forKey: .gender)
        
        try container.encode(heightInCm, forKey: .heightInCm)
        try container.encode(weightInKg, forKey: .weightInKg)
        try container.encode(targetWeightInKg, forKey: .targetWeightInKg)
        
        try container.encode(goal, forKey: .goal)
        try container.encode(fitnessGoal, forKey: .fitnessGoal)
        try container.encode(activityLevel, forKey: .activityLevel)
        try container.encode(diet, forKey: .diet)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        
        try container.encode(bmi, forKey: .bmi)
        try container.encode(dailyCalories, forKey: .dailyCalories)
        try container.encode(proteinInGrams, forKey: .proteinInGrams)
        try container.encode(carbsInGrams, forKey: .carbsInGrams)
        try container.encode(fatsInGrams, forKey: .fatsInGrams)
        
        try container.encode(dailyCalorieTarget, forKey: .dailyCalorieTarget)
        try container.encode(proteinGramsTarget, forKey: .proteinGramsTarget)
        try container.encode(carbsGramsTarget, forKey: .carbsGramsTarget)
        try container.encode(fatGramsTarget, forKey: .fatGramsTarget)
        
        // Кодируем значения потребления
        try container.encode(consumedCalories, forKey: .consumedCalories)
        try container.encode(consumedProtein, forKey: .consumedProtein)
        try container.encode(consumedCarbs, forKey: .consumedCarbs)
        try container.encode(consumedFat, forKey: .consumedFat)
        
        try container.encode(autoCalculateNutrients, forKey: .autoCalculateNutrients)
        
        try container.encode(dailyStepsTarget, forKey: .dailyStepsTarget)
    }
    
    // MARK: - Методы для расчетов
    
    // Обновление профиля
    func updateProfile() {
        // Не пересчитываем значения, чтобы не перезаписать изменения
        // calculateDailyTargets()
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
        
        saveProfile()
    }
    
    // Сохранение профиля
    private func saveProfile() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "userProfile")
        } catch {
            print("Ошибка при сохранении профиля: \(error.localizedDescription)")
        }
    }
    
    // Расчет BMI
    func calculateBMI() -> Double {
        let heightInMeters = Double(heightInCm) / 100.0
        let bmi = weightInKg / (heightInMeters * heightInMeters)
        
        // Обновление значения и округление до 1 десятичного знака
        self.bmi = round(bmi * 10) / 10
        return self.bmi
    }
    
    // Расчет дневной нормы калорий
    func calculateDailyCalories() -> Double {
        // Расчет базового обмена веществ (BMR) по формуле Миффлина-Сан Жеора
        let s = gender == .male ? 5 : -161
        let bmr = 10 * weightInKg + 6.25 * Double(heightInCm) - 5 * Double(age) + Double(s)
        
        // Коэффициент активности
        let activityMultiplier = self.activityLevel.activityMultiplier
        
        // Расчет общей потребности в калориях с учетом целей
        var tdee = bmr * activityMultiplier
        
        // Корректировка калорий в зависимости от цели
        switch goal {
        case .loseWeight:
            tdee *= 0.8 // Дефицит 20%
        case .maintainWeight:
            // Без изменений
            break
        case .gainMuscle:
            tdee *= 1.1 // Профицит 10%
        }
        
        // Окончательное значение с округлением до ближайших 50 калорий
        self.dailyCalories = round(tdee / 50) * 50
        return self.dailyCalories
    }
    
    // Расчет целевого потребления белка
    func calculateProteinTarget() -> Double {
        // Распределение макроэлементов в зависимости от цели и диеты
        var proteinPercentage: Double = 0.3 // 30% по умолчанию
        
        // Корректировка для различных диет
        switch diet {
        case .keto:
            proteinPercentage = 0.25 // 25%
        case .mediterranean:
            proteinPercentage = 0.20 // 20%
        case .intermittentFasting, .dukan, .none:
            // Оставляем значения по умолчанию или корректируем в зависимости от цели
            switch goal {
            case .loseWeight:
                proteinPercentage = 0.35
            case .maintainWeight:
                // Стандартное распределение
                break
            case .gainMuscle:
                proteinPercentage = 0.35
            }
        }
        
        // Расчет граммов белка
        let caloriesFromProtein = dailyCalories * proteinPercentage
        // 1 г белка = 4 калории
        proteinInGrams = round(caloriesFromProtein / 4)
        return proteinInGrams
    }
    
    // Расчет целевого потребления углеводов
    func calculateCarbsTarget() -> Double {
        // Распределение макроэлементов в зависимости от цели и диеты
        var carbsPercentage: Double = 0.45 // 45% по умолчанию
        
        // Корректировка для различных диет
        switch diet {
        case .keto:
            carbsPercentage = 0.05 // 5%
        case .mediterranean:
            carbsPercentage = 0.50 // 50%
        case .intermittentFasting, .dukan, .none:
            // Оставляем значения по умолчанию или корректируем в зависимости от цели
            switch goal {
            case .loseWeight:
                carbsPercentage = 0.40
            case .maintainWeight:
                // Стандартное распределение
                break
            case .gainMuscle:
                carbsPercentage = 0.45
            }
        }
        
        // Расчет граммов углеводов
        let caloriesFromCarbs = dailyCalories * carbsPercentage
        // 1 г углеводов = 4 калории
        carbsInGrams = round(caloriesFromCarbs / 4)
        return carbsInGrams
    }
    
    // Расчет целевого потребления жиров
    func calculateFatsTarget() -> Double {
        // Распределение макроэлементов в зависимости от цели и диеты
        var fatsPercentage: Double = 0.25 // 25% по умолчанию
        
        // Корректировка для различных диет
        switch diet {
        case .keto:
            fatsPercentage = 0.7 // 70%
        case .mediterranean:
            fatsPercentage = 0.30 // 30%
        case .intermittentFasting, .dukan, .none:
            // Оставляем значения по умолчанию или корректируем в зависимости от цели
            switch goal {
            case .loseWeight:
                fatsPercentage = 0.25
            case .maintainWeight:
                // Стандартное распределение
                break
            case .gainMuscle:
                fatsPercentage = 0.20
            }
        }
        
        // Расчет граммов жиров
        let caloriesFromFats = dailyCalories * fatsPercentage
        // 1 г жиров = 9 калорий
        fatsInGrams = round(caloriesFromFats / 9)
        return fatsInGrams
    }
    
    // Расчет макроэлементов
    func calculateDailyTargets() {
        // Сначала рассчитываем BMI и дневные калории
        _ = calculateBMI()
        _ = calculateDailyCalories()
        
        // Распределение макроэлементов в зависимости от цели и диеты
        var proteinPercentage: Double = 0.3 // 30% по умолчанию
        var carbsPercentage: Double = 0.45 // 45% по умолчанию
        var fatsPercentage: Double = 0.25 // 25% по умолчанию
        
        // Корректировка для различных диет
        switch diet {
        case .keto:
            proteinPercentage = 0.25 // 25%
            carbsPercentage = 0.05 // 5%
            fatsPercentage = 0.7 // 70%
        case .mediterranean:
            proteinPercentage = 0.20 // 20%
            carbsPercentage = 0.50 // 50%
            fatsPercentage = 0.30 // 30%
        case .intermittentFasting, .dukan, .none:
            // Оставляем значения по умолчанию или корректируем в зависимости от цели
            switch goal {
            case .loseWeight:
                proteinPercentage = 0.35
                carbsPercentage = 0.40
                fatsPercentage = 0.25
            case .maintainWeight:
                // Стандартное распределение
                break
            case .gainMuscle:
                proteinPercentage = 0.35
                carbsPercentage = 0.45
                fatsPercentage = 0.20
            }
        }
        
        // Расчет граммов макроэлементов
        let caloriesFromProtein = dailyCalories * proteinPercentage
        let caloriesFromCarbs = dailyCalories * carbsPercentage
        let caloriesFromFats = dailyCalories * fatsPercentage
        
        // Конвертация из калорий в граммы
        // 1 г белка = 4 калории, 1 г углеводов = 4 калории, 1 г жиров = 9 калорий
        proteinInGrams = round(caloriesFromProtein / 4)
        carbsInGrams = round(caloriesFromCarbs / 4)
        fatsInGrams = round(caloriesFromFats / 9)
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
    }
    
    // Пересчет параметров при изменении белка
    func recalculateFromProtein(newProtein: Double) {
        // Если автоматический пересчет отключен, просто обновляем значение белка
        if !autoCalculateNutrients {
            proteinInGrams = newProtein
            proteinGramsTarget = Int(proteinInGrams)
            saveProfile()
            return
        }
        
        // Сохраняем новое значение белка
        proteinInGrams = newProtein
        
        // Рассчитываем общее количество калорий от протеина (1г = 4 калории)
        let proteinCalories = newProtein * 4
        
        // Если текущие калории равны 0, используем стандартное соотношение
        if dailyCalories <= 0 {
            // Устанавливаем новые калории на основе протеина (при условии, что протеин составляет 30%)
            dailyCalories = proteinCalories / 0.3
            
            // Вызываем полный пересчет, чтобы получить правильные значения жиров и углеводов
            recalculateNutrientsFromCalories(newCalories: dailyCalories)
            return
        }
        
        // Определяем текущие пропорции
        let currentProteinRatio = (proteinInGrams * 4) / dailyCalories
        let currentCarbsRatio = (carbsInGrams * 4) / dailyCalories
        let currentFatsRatio = (fatsInGrams * 9) / dailyCalories
        
        // Рассчитываем сумму всех текущих соотношений (должна быть около 1)
        let totalRatio = currentProteinRatio + currentCarbsRatio + currentFatsRatio
        
        // Корректируем соотношения, чтобы сумма была равна 1
        let adjustedCarbsRatio = currentCarbsRatio / (totalRatio - currentProteinRatio) * (1 - proteinCalories / dailyCalories)
        let adjustedFatsRatio = currentFatsRatio / (totalRatio - currentProteinRatio) * (1 - proteinCalories / dailyCalories)
        
        // Рассчитываем новые калории от углеводов и жиров
        let carbsCalories = dailyCalories * adjustedCarbsRatio
        let fatsCalories = dailyCalories * adjustedFatsRatio
        
        // Конвертируем калории в граммы
        carbsInGrams = round(carbsCalories / 4)
        fatsInGrams = round(fatsCalories / 9)
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
        
        // Сохраняем изменения в профиле
        saveProfile()
    }
    
    // Пересчет параметров при изменении углеводов
    func recalculateFromCarbs(newCarbs: Double) {
        // Если автоматический пересчет отключен, просто обновляем значение углеводов
        if !autoCalculateNutrients {
            carbsInGrams = newCarbs
            carbsGramsTarget = Int(carbsInGrams)
            saveProfile()
            return
        }
        
        // Сохраняем новое значение углеводов
        carbsInGrams = newCarbs
        
        // Рассчитываем общее количество калорий от углеводов (1г = 4 калории)
        let carbsCalories = newCarbs * 4
        
        // Если текущие калории равны 0, используем стандартное соотношение
        if dailyCalories <= 0 {
            // Устанавливаем новые калории на основе углеводов (при условии, что углеводы составляют 45%)
            dailyCalories = carbsCalories / 0.45
            
            // Вызываем полный пересчет, чтобы получить правильные значения белков и жиров
            recalculateNutrientsFromCalories(newCalories: dailyCalories)
            return
        }
        
        // Определяем текущие пропорции
        let currentProteinRatio = (proteinInGrams * 4) / dailyCalories
        let currentCarbsRatio = (carbsInGrams * 4) / dailyCalories
        let currentFatsRatio = (fatsInGrams * 9) / dailyCalories
        
        // Рассчитываем сумму всех текущих соотношений (должна быть около 1)
        let totalRatio = currentProteinRatio + currentCarbsRatio + currentFatsRatio
        
        // Корректируем соотношения, чтобы сумма была равна 1
        let adjustedProteinRatio = currentProteinRatio / (totalRatio - currentCarbsRatio) * (1 - carbsCalories / dailyCalories)
        let adjustedFatsRatio = currentFatsRatio / (totalRatio - currentCarbsRatio) * (1 - carbsCalories / dailyCalories)
        
        // Рассчитываем новые калории от белков и жиров
        let proteinCalories = dailyCalories * adjustedProteinRatio
        let fatsCalories = dailyCalories * adjustedFatsRatio
        
        // Конвертируем калории в граммы
        proteinInGrams = round(proteinCalories / 4)
        fatsInGrams = round(fatsCalories / 9)
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
        
        // Сохраняем изменения в профиле
        saveProfile()
    }
    
    // Пересчет параметров при изменении жиров
    func recalculateFromFats(newFats: Double) {
        // Если автоматический пересчет отключен, просто обновляем значение жиров
        if !autoCalculateNutrients {
            fatsInGrams = newFats
            fatGramsTarget = Int(fatsInGrams)
            saveProfile()
            return
        }
        
        // Сохраняем новое значение жиров
        fatsInGrams = newFats
        
        // Рассчитываем общее количество калорий от жиров (1г = 9 калорий)
        let fatsCalories = newFats * 9
        
        // Если текущие калории равны 0, используем стандартное соотношение
        if dailyCalories <= 0 {
            // Устанавливаем новые калории на основе жиров (при условии, что жиры составляют 25%)
            dailyCalories = fatsCalories / 0.25
            
            // Вызываем полный пересчет, чтобы получить правильные значения белков и углеводов
            recalculateNutrientsFromCalories(newCalories: dailyCalories)
            return
        }
        
        // Определяем текущие пропорции
        let currentProteinRatio = (proteinInGrams * 4) / dailyCalories
        let currentCarbsRatio = (carbsInGrams * 4) / dailyCalories
        let currentFatsRatio = (fatsInGrams * 9) / dailyCalories
        
        // Рассчитываем сумму всех текущих соотношений (должна быть около 1)
        let totalRatio = currentProteinRatio + currentCarbsRatio + currentFatsRatio
        
        // Корректируем соотношения, чтобы сумма была равна 1
        let adjustedProteinRatio = currentProteinRatio / (totalRatio - currentFatsRatio) * (1 - fatsCalories / dailyCalories)
        let adjustedCarbsRatio = currentCarbsRatio / (totalRatio - currentFatsRatio) * (1 - fatsCalories / dailyCalories)
        
        // Рассчитываем новые калории от белков и углеводов
        let proteinCalories = dailyCalories * adjustedProteinRatio
        let carbsCalories = dailyCalories * adjustedCarbsRatio
        
        // Конвертируем калории в граммы
        proteinInGrams = round(proteinCalories / 4)
        carbsInGrams = round(carbsCalories / 4)
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
        
        // Сохраняем изменения в профиле
        saveProfile()
    }
    
    // Обновленный метод для пересчета макронутриентов на основе измененных калорий
    func recalculateNutrientsFromCalories(newCalories: Double) {
        // Если автоматический пересчет отключен, просто обновляем значение калорий
        if !autoCalculateNutrients {
            dailyCalories = newCalories
            dailyCalorieTarget = Int(dailyCalories)
            saveProfile()
            return
        }
        
        // Если текущие калории равны 0, используем стандартное распределение
        if dailyCalories <= 0 {
            // Сохраняем новое значение калорий
            dailyCalories = newCalories
            
            // Распределение макроэлементов в зависимости от цели и диеты
            var proteinPercentage: Double = 0.3 // 30% по умолчанию
            var carbsPercentage: Double = 0.45 // 45% по умолчанию
            var fatsPercentage: Double = 0.25 // 25% по умолчанию
            
            // Корректировка для различных диет
            switch diet {
            case .keto:
                proteinPercentage = 0.25 // 25%
                carbsPercentage = 0.05 // 5%
                fatsPercentage = 0.7 // 70%
            case .mediterranean:
                proteinPercentage = 0.20 // 20%
                carbsPercentage = 0.50 // 50%
                fatsPercentage = 0.30 // 30%
            case .intermittentFasting, .dukan, .none:
                // Оставляем значения по умолчанию или корректируем в зависимости от цели
                switch goal {
                case .loseWeight:
                    proteinPercentage = 0.35
                    carbsPercentage = 0.40
                    fatsPercentage = 0.25
                case .maintainWeight:
                    // Стандартное распределение
                    break
                case .gainMuscle:
                    proteinPercentage = 0.35
                    carbsPercentage = 0.45
                    fatsPercentage = 0.20
                }
            }
            
            // Расчет граммов макроэлементов на основе новых калорий
            let caloriesFromProtein = dailyCalories * proteinPercentage
            let caloriesFromCarbs = dailyCalories * carbsPercentage
            let caloriesFromFats = dailyCalories * fatsPercentage
            
            // Конвертация из калорий в граммы
            proteinInGrams = round(caloriesFromProtein / 4)
            carbsInGrams = round(caloriesFromCarbs / 4)
            fatsInGrams = round(caloriesFromFats / 9)
        } else {
            // Сохраняем соотношение макронутриентов при изменении калорий
            
            // Рассчитываем текущие пропорции
            let proteinPercentage = (proteinInGrams * 4) / dailyCalories
            let carbsPercentage = (carbsInGrams * 4) / dailyCalories
            let fatsPercentage = (fatsInGrams * 9) / dailyCalories
            
            // Сохраняем новое значение калорий
            dailyCalories = newCalories
            
            // Применяем те же пропорции к новым калориям
            let newProteinCalories = dailyCalories * proteinPercentage
            let newCarbsCalories = dailyCalories * carbsPercentage
            let newFatsCalories = dailyCalories * fatsPercentage
            
            // Конвертируем в граммы
            proteinInGrams = round(newProteinCalories / 4)
            carbsInGrams = round(newCarbsCalories / 4)
            fatsInGrams = round(newFatsCalories / 9)
        }
        
        // Обновляем старые свойства для совместимости
        dailyCalorieTarget = Int(dailyCalories)
        proteinGramsTarget = Int(proteinInGrams)
        carbsGramsTarget = Int(carbsInGrams)
        fatGramsTarget = Int(fatsInGrams)
        
        // Сохраняем изменения в профиле
        saveProfile()
    }
    
    // Добавляем метод для учета потребленной пищи
    func addConsumedFood(calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.consumedCalories += calories
        self.consumedProtein += protein
        self.consumedCarbs += carbs
        self.consumedFat += fat
        
        // Сохраняем изменения
        saveProfile()
        
        // Отправляем уведомление об обновлении
        NotificationCenter.default.post(
            name: .nutritionValuesUpdated,
            object: nil,
            userInfo: nil
        )
    }
    
    // Метод для сброса потребленных значений (например, в начале нового дня)
    func resetConsumedValues() {
        self.consumedCalories = 0.0
        self.consumedProtein = 0.0
        self.consumedCarbs = 0.0
        self.consumedFat = 0.0
        
        // Сохраняем изменения
        saveProfile()
    }
    
    // MARK: - Методы для копирования и сброса
    
    /// Создает копию профиля для временного отображения
    func copy() -> UserProfile {
        let copy = UserProfile()
        
        // Копируем персональные данные
        copy.name = self.name
        copy.dateOfBirth = self.dateOfBirth
        copy.age = self.age
        copy.gender = self.gender
        
        // Копируем физические параметры
        copy.heightInCm = self.heightInCm
        copy.weightInKg = self.weightInKg
        copy.targetWeightInKg = self.targetWeightInKg
        
        // Копируем цели и предпочтения
        copy.goal = self.goal
        copy.fitnessGoal = self.fitnessGoal
        copy.activityLevel = self.activityLevel
        copy.diet = self.diet
        copy.preferredLanguage = self.preferredLanguage
        copy.dailyStepsTarget = self.dailyStepsTarget
        
        // Копируем рассчитанные значения
        copy.bmi = self.bmi
        copy.dailyCalories = self.dailyCalories
        copy.proteinInGrams = self.proteinInGrams
        copy.carbsInGrams = self.carbsInGrams
        copy.fatsInGrams = self.fatsInGrams
        
        // Копируем свойства для обратной совместимости
        copy.dailyCalorieTarget = self.dailyCalorieTarget
        copy.proteinGramsTarget = self.proteinGramsTarget
        copy.carbsGramsTarget = self.carbsGramsTarget
        copy.fatGramsTarget = self.fatGramsTarget
        
        // Копируем значения потребления
        copy.consumedCalories = self.consumedCalories
        copy.consumedProtein = self.consumedProtein
        copy.consumedCarbs = self.consumedCarbs
        copy.consumedFat = self.consumedFat
        
        copy.autoCalculateNutrients = self.autoCalculateNutrients
        
        return copy
    }
    
    // MARK: - Методы для отслеживания потребления нутриентов
    
    // Добавление потребленных нутриентов
    func addConsumedNutrients(calories: Double, protein: Double, carbs: Double, fat: Double) {
        consumedCalories += calories
        consumedProtein += protein
        consumedCarbs += carbs
        consumedFat += fat
        
        // Сохраняем обновленные данные
        saveProfile()
    }
    
    // Добавление еды и учет её питательной ценности
    func addFoodConsumption(calories: Double, protein: Double, carbs: Double, fat: Double, name: String) {
        // Добавляем потребленные нутриенты
        consumedCalories += calories
        consumedProtein += protein
        consumedCarbs += carbs
        consumedFat += fat
        
        print("Добавлено потребление \(name): калории \(calories), белки \(protein), углеводы \(carbs), жиры \(fat)")
        print("Текущее потребление: калории \(consumedCalories), белки \(consumedProtein), углеводы \(consumedCarbs), жиры \(consumedFat)")
        
        // Сохраняем обновленные данные
        saveProfile()
        
        // Отправляем уведомление об обновлении показателей питания
        NotificationCenter.default.post(
            name: .nutritionValuesUpdated,
            object: nil,
            userInfo: nil
        )
    }
    
    // Удаление еды и корректировка питательной ценности
    func removeFoodConsumption(calories: Double, protein: Double, carbs: Double, fat: Double, name: String) {
        // Вычитаем нутриенты удаленной еды
        consumedCalories -= calories
        consumedProtein -= protein
        consumedCarbs -= carbs
        consumedFat -= fat
        
        // Проверяем, чтобы значения не стали отрицательными
        consumedCalories = max(0, consumedCalories)
        consumedProtein = max(0, consumedProtein)
        consumedCarbs = max(0, consumedCarbs)
        consumedFat = max(0, consumedFat)
        
        print("Удалено потребление \(name): калории \(calories), белки \(protein), углеводы \(carbs), жиры \(fat)")
        print("Обновленное потребление: калории \(consumedCalories), белки \(consumedProtein), углеводы \(consumedCarbs), жиры \(consumedFat)")
        
        // Сохраняем обновленные данные
        saveProfile()
        
        // Отправляем уведомление об обновлении показателей питания
        NotificationCenter.default.post(
            name: .nutritionValuesUpdated,
            object: nil,
            userInfo: nil
        )
    }
}



