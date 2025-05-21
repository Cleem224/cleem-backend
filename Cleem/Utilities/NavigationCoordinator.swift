import Foundation
import SwiftUI
import Combine
import UIKit
import CoreData

class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()
    
    // MARK: - Notification Names
    static let didCompleteFoodAnalysis = Notification.Name("didCompleteFoodAnalysis")
    static let navigateToHomeScreen = Notification.Name("navigateToHomeScreen")
    
    @Published var activeScreen: Screen? = nil {
        willSet {
            // When screen changes, set the isTransitioning flag
            if newValue != activeScreen {
                isTransitioning = true
                
                // Add a small delay before changing screens to allow for animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.isTransitioning = false
                }
            }
        }
    }
    
    // Add a flag to track transitions
    @Published var isTransitioning: Bool = false
    
    @Published var foodAnalysisImage: UIImage?
    @Published var foodDetailItem: FoodItem?
    @Published var foodNutrition: FoodNutrition?
    @Published var isShowingNoResultsFound = false
    @Published var userProfile = UserProfile()
    @Published var isOnboarding = false
    
    // Food analysis state
    @Published var isAnalyzing = false
    @Published var scanSuccess = false
    
    // Food scanning results tracking properties
    @Published var lastScannedFoodID: String? {
        didSet {
            if let id = lastScannedFoodID {
                print("NavigationCoordinator: Устанавливаем lastScannedFoodID = \(id)")
                UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
                UserDefaults.standard.synchronize()
            }
        }
    }
    @Published var recentlyScannedFood: Food? {
        didSet {
            if let newFood = recentlyScannedFood, oldValue?.id != newFood.id {
                print("NavigationCoordinator: Установлен recentlyScannedFood, id: \(newFood.id?.uuidString ?? "nil"), name: \(newFood.name ?? "Unknown")")
                
                // Сохраняем ID последнего отсканированного продукта
                if let foodId = newFood.id {
                    lastScannedFoodID = foodId.uuidString
                    print("NavigationCoordinator: Сохранен lastScannedFoodID = \(foodId.uuidString)")
                    
                    // Также сохраняем в UserDefaults напрямую
                    CoreDataManager.shared.saveFoodToUserDefaults(food: newFood)
                }
                
                // Отправляем уведомление об обновлении еды
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
        }
    }
    @Published var isFoodScanning = false
    @Published var isFoodAnalyzing = false
    @Published var notFoodDetected = false
    
    // Navigation flags
    @Published var showScanCamera = false {
        didSet {
            if showScanCamera {
                // Когда камера открыта, проверяем, должны ли мы использовать новую версию
                shouldUseNewScanCameraView = UserDefaults.standard.bool(forKey: "use_new_recognition")
                print("🔄 Открытие камеры сканирования, режим shouldUseNewScanCameraView: \(shouldUseNewScanCameraView)")
            }
        }
    }
    @Published var shouldUseNewScanCameraView = false
    @Published var showBarcodeScannerView = false
    @Published var showFoodLabelView = false
    @Published var showImagePicker = false
    
    // Manual food entry
    @Published var isShowingFoodSearch = false
    @Published var currentMealType = ""
    
    // Training monitor
    @Published var showTrainingMonitorView = false
    
    // Food database selection callback
    private var foodSelectionCallback: ((Any) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationListeners()
        initUserProfile()
        
        // Инициализация shouldUseNewScanCameraView из настроек
        shouldUseNewScanCameraView = UserDefaults.standard.bool(forKey: "use_new_recognition")
        print("🔄 Инициализация NavigationCoordinator, режим shouldUseNewScanCameraView: \(shouldUseNewScanCameraView)")
    }
    
    // Method to change screens with proper transition
    func navigateTo(_ screen: Screen?) {
        // Only proceed if not already transitioning
        guard !isTransitioning else { return }
        
        withAnimation(.easeOut(duration: 0.3)) {
            self.activeScreen = screen
        }
    }
    
    // Метод для проверки использования новой системы распознавания
    func shouldUseNewRecognitionSystem() -> Bool {
        return UserDefaults.standard.bool(forKey: "use_new_recognition")
    }
    
    private func setupNotificationListeners() {
        // Add notification observers
        NotificationCenter.default.publisher(for: NavigationCoordinator.didCompleteFoodAnalysis)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                if let foodItem = notification.object as? FoodItem {
                    self.foodDetailItem = foodItem
                    self.navigateTo(.foodDetails(foodItem: foodItem))
                    self.isAnalyzing = false
                    self.scanSuccess = true
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NavigationCoordinator.navigateToHomeScreen)
            .sink { [weak self] _ in
                self?.navigateTo(nil)
            }
            .store(in: &cancellables)
        
        // Register for app termination notification to save the context
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveContextOnTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Register for app entering background notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveContextOnBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Наблюдение за изменениями в использовании новой системы распознавания
        UserDefaults.standard.publisher(for: \.use_new_recognition)
            .sink { [weak self] newValue in
                self?.shouldUseNewScanCameraView = newValue
            }
            .store(in: &cancellables)
    }
    
    @objc func saveContextOnTerminate() {
        print("NavigationCoordinator: Saving context on app termination")
        // Save last scanned food ID to UserDefaults
        if let food = recentlyScannedFood, let id = food.id?.uuidString {
            UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
            UserDefaults.standard.synchronize()
        }
        
        // Save context
        CoreDataManager.shared.saveContext()
    }
    
    @objc func saveContextOnBackground() {
        print("NavigationCoordinator: Saving context when app enters background")
        // Save last scanned food ID to UserDefaults
        if let food = recentlyScannedFood, let id = food.id?.uuidString {
            UserDefaults.standard.set(id, forKey: "lastScannedFoodID")
            UserDefaults.standard.synchronize()
        }
        
        // Save context
        CoreDataManager.shared.saveContext()
    }
    
    private func initUserProfile() {
        // Устанавливаем API ключи по умолчанию для нового менеджера
        FoodRecognitionManagerV2().setDefaultApiKeys()
        
        // Загрузка последней отсканированной еды при запуске приложения
        loadLastScannedFood()
        
        // Пытаемся загрузить сохраненный профиль
        if let savedProfileData = UserDefaults.standard.data(forKey: "userProfile"),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: savedProfileData) {
            userProfile = savedProfile
            
            // Обновляем только BMI, но не пересчитываем калории
            userProfile.bmi = userProfile.calculateBMI()
            // Не пересчитываем калории, чтобы сохранить редактируемые значения
            // userProfile.dailyCalories = userProfile.calculateDailyCalories()
        } else {
            // Создаем новый профиль с дефолтными значениями
            userProfile = UserProfile()
        }
    }
    
    // Метод для загрузки последней отсканированной еды из CoreData при запуске приложения
    private func loadLastScannedFood() {
        if let lastFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID"),
           let uuid = UUID(uuidString: lastFoodID) {
            
            // Получаем контекст CoreData
            let context = CoreDataManager.shared.context
            let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
            
            // Ищем продукт по ID
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let lastFood = results.first {
                    print("Загружена последняя отсканированная еда: \(lastFood.name ?? "Unknown"), ID: \(lastFood.id?.uuidString ?? "nil")")
                    
                    // Устанавливаем еду без отправки уведомления (будет отправлено didSet)
                    self.recentlyScannedFood = lastFood
                } else {
                    print("Последняя отсканированная еда с ID \(lastFoodID) не найдена в базе данных")
                    
                    // Если продукт с таким ID не найден, загружаем самый последний продукт
                    loadMostRecentFood()
                }
            } catch {
                print("Ошибка при загрузке последней отсканированной еды: \(error)")
                
                // При ошибке загружаем самый последний продукт
                loadMostRecentFood()
            }
        } else {
            print("ID последней отсканированной еды не найден в UserDefaults")
            
            // Если нет сохраненного ID, загружаем самый последний продукт
            loadMostRecentFood()
        }
    }
    
    // Метод для загрузки самого последнего добавленного продукта
    private func loadMostRecentFood() {
        let context = CoreDataManager.shared.context
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        // Сортируем по дате создания (сначала новые)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        // Ограничиваем до 1 записи (самый последний продукт)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let lastFood = results.first {
                print("Загружен самый последний продукт: \(lastFood.name ?? "Unknown"), ID: \(lastFood.id?.uuidString ?? "nil")")
                
                // Устанавливаем еду
                self.recentlyScannedFood = lastFood
                
                // Сохраняем ID в UserDefaults
                if let foodId = lastFood.id?.uuidString {
                    UserDefaults.standard.set(foodId, forKey: "lastScannedFoodID")
                    UserDefaults.standard.synchronize()
                }
            } else {
                print("В базе данных нет продуктов")
            }
        } catch {
            print("Ошибка при загрузке самого последнего продукта: \(error)")
        }
    }
    
    func showNutritionDetails(for food: FoodItem, nutrition: FoodNutrition) {
        self.foodDetailItem = food
        self.foodNutrition = nutrition
        self.navigateTo(.nutritionDetails(foodItem: food))
    }
    
    func dismissActiveScreen() {
        // Capture current screen for logging
        let currentScreen = self.activeScreen
        print("Dismissing screen: \(String(describing: currentScreen?.id))")
        
        // Сначала сбрасываем переменные, связанные с текущим экраном
        self.foodDetailItem = nil
        self.foodNutrition = nil
        
        // Затем устанавливаем activeScreen в nil с анимацией
        withAnimation(.easeInOut(duration: 0.2)) {
            self.activeScreen = nil
        }
        
        // Отправляем уведомление о возврате на главный экран для дополнительной надежности
        NotificationCenter.default.post(name: NavigationCoordinator.navigateToHomeScreen, object: nil)
        
        // Используем небольшую задержку, чтобы дать UI время обновиться
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Дополнительно проверяем, что экран закрылся
            if self.activeScreen != nil {
                print("Screen didn't close properly. Forcing dismiss.")
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.activeScreen = nil
                }
                
                // Force screen dismissal through UIKit if needed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        if let presentedVC = rootViewController.presentedViewController {
                            presentedVC.dismiss(animated: true)
                        }
                    }
                }
            }
        }
    }
    
    // Переработанный метод для запуска процесса настройки профиля
    func showProfileSetup() {
        // Запускаем онбординг с нуля
        startOnboarding()
    }
    
    // Add this method to handle manual food entry
    func showManualFoodEntry(for mealType: String) {
        // Implementation to show food search page for manual entry
        // This will be called from QuickActionsView
        self.currentMealType = mealType
        self.isShowingFoodSearch = true
    }
    
    // Method to show food database with a callback for ingredient selection
    func showFoodDatabase(onFoodSelected: @escaping (Any) -> Void) {
        self.foodSelectionCallback = onFoodSelected
        navigateTo(.foodDatabase)
    }
    
    // Method to handle food selection from the database
    func selectFoodFromDatabase(_ food: Any) {
        if let callback = foodSelectionCallback {
            callback(food)
            foodSelectionCallback = nil
            navigateTo(nil) // Return to previous screen
        }
    }
    
    // Вызывается при завершении профиля или онбординга
    func completeProfileSetup() {
        // Обновляем профиль и сохраняем все значения
        userProfile.updateProfile()
        
        // Закрываем все модальные окна с плавным переходом
        withAnimation(.easeInOut(duration: 0.3)) {
            self.isOnboarding = false
            self.navigateTo(nil)
        }
    }
    
    // Метод для запуска онбординга
    func startOnboarding() {
        // Убедимся, что интерфейс готов
        DispatchQueue.main.async {
            // Сначала устанавливаем режим онбординга
            self.isOnboarding = true
            
            // Затем переходим на экран приветствия с малой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.navigateTo(.welcome)
            }
        }
    }
    
    // Метод для закрытия настройки профиля
    func dismissProfileSetup() {
        // Завершаем онбординг
        withAnimation(.easeOut(duration: 0.3)) {
            isOnboarding = false
            navigateTo(nil)
        }
    }
    
    // Метод для открытия экрана редактирования параметров питания
    func showNutritionParameterEditView(parameterType: NutritionParameterType, value: Binding<Int>) {
        // Создаем экран редактирования параметра питания через родной NavigationView
        let editView = NavigationView {
            NutritionParameterEditView(
                parameterType: parameterType,
                value: value
            )
            .environmentObject(self)
        }
        
        // Используем UIKit для представления SwiftUI view в полноэкранном режиме
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            let hostingController = UIHostingController(rootView: editView)
            hostingController.modalPresentationStyle = .fullScreen
            
            // Показываем контроллер
            rootViewController.present(hostingController, animated: true)
        }
    }
    
    // Show training monitor sheet
    func showTrainingMonitor() {
        withAnimation {
            self.showTrainingMonitorView = true
        }
    }
    
    // Add method to show combined food details
    func showCombinedFoodDetails(for combinedFood: CombinedFoodItem) {
        self.navigateTo(.combinedFoodDetails(combinedFood: combinedFood))
    }
    
    // Показать детали пищи
    func showFoodDetail(for food: FoodDisplayable) {
        print("NavigationCoordinator: showFoodDetail вызван")
        if let food = food as? Food {
            activeScreen = .foodDetail(food)
        } else {
            print("⚠️ Неизвестный тип FoodDisplayable")
        }
    }
    
    // Show the detailed view for food with ingredients
    func showFoodIngredientDetail(for food: Food) {
        print("NavigationCoordinator: showFoodIngredientDetail called")
        if food.isComposed && (food.ingredients?.count ?? 0) > 0 {
            // Use dedicated ingredient detail view for composed foods
            activeScreen = .foodIngredientDetail(food)
        } else {
            // Fallback to regular food detail for non-composed foods
            activeScreen = .foodDetail(food)
        }
    }
}

extension NavigationCoordinator {
    enum Screen: Identifiable, Equatable {
        case foodDetails(foodItem: FoodItem)
        case nutritionDetails(foodItem: FoodItem)
        case combinedFoodDetails(combinedFood: CombinedFoodItem)
        case profileSetup
        // Добавляем экраны онбординга
        case welcome
        case genderSelection
        case ageSelection
        // case heightSelection  // Закомментировали отдельные экраны
        // case weightSelection  // Закомментировали отдельные экраны
        case heightWeightSelection  // Добавили комбинированный экран
        case goalSelection
        case targetWeight
        case activitySelection
        case dietSelection
        case appreciation // Экран благодарности
        case planBuild // Новый экран с изображением рук держащих сердце
        case recommendationLoading // Экран загрузки рекомендаций
        case summary
        case foodDatabase
        case foodDetail(Food)
        case foodIngredientDetail(Food)
        
        var id: String {
            switch self {
            case .foodDetails(let foodItem):
                return "foodDetails-\(foodItem.id)"
            case .nutritionDetails(let foodItem):
                return "nutritionDetails-\(foodItem.id)"
            case .combinedFoodDetails(let combinedFood):
                return "combinedFoodDetails-\(combinedFood.id.uuidString)"
            case .profileSetup:
                return "profileSetup"
            case .welcome:
                return "welcome"
            case .genderSelection:
                return "genderSelection"
            case .ageSelection:
                return "ageSelection"
            // case .heightSelection:
            //     return "heightSelection"
            // case .weightSelection:
            //     return "weightSelection"
            case .heightWeightSelection:
                return "heightWeightSelection"
            case .goalSelection:
                return "goalSelection"
            case .targetWeight:
                return "targetWeight"
            case .activitySelection:
                return "activitySelection"
            case .dietSelection:
                return "dietSelection"
            case .appreciation:
                return "appreciation"
            case .planBuild:
                return "planBuild"
            case .recommendationLoading:
                return "recommendationLoading"
            case .summary:
                return "summary"
            case .foodDatabase:
                return "foodDatabase"
            case .foodDetail(let food):
                return "foodDetail-\(food.id?.uuidString ?? "nil")"
            case .foodIngredientDetail(let food):
                return "foodIngredientDetail-\(food.id?.uuidString ?? "nil")"
            }
        }
        
        // Реализация протокола Equatable
        static func == (lhs: Screen, rhs: Screen) -> Bool {
            return lhs.id == rhs.id
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    @objc var use_new_recognition: Bool {
        return bool(forKey: "use_new_recognition")
    }
}





