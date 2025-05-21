import SwiftUI
import UIKit
import CoreData
import Cleem

struct RecentlyLoggedView: View {
    var hasLoggedFood: Bool
    var isScanning: Bool
    var isAnalyzing: Bool
    @State var analyzedFood: Food?
    
    // Форматтер для времени
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Эффект появления для нового продукта
    @State private var animateNewFood: Bool = false
    
    // Состояние активностей и еды
    @State private var trainingsHistory: [[String: Any]] = []
    @State private var recentFoods: [Food] = []
    @State private var combinedFoods: [CombinedFoodItem] = []
    @State private var refreshID = UUID()
    @State private var swipeOffsets: [String: CGFloat] = [:]
    @State private var foodSwipeOffsets: [UUID: CGFloat] = [:]
    @State private var combinedFoodSwipeOffsets: [UUID: CGFloat] = [:]
    
    // Состояние для определения порядка отображения
    @State private var showFoodFirst: Bool = true
    
    // HealthKitManager для удаления активностей
    @StateObject private var healthManager = HealthKitManager.shared
    
    // NavigationCoordinator для взаимодействия с приложением
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    
    // Для управления обновлениями
    @State private var notificationObserver: [Any]? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently logged")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Определяем порядок отображения блоков
            if showFoodFirst && (!recentFoods.isEmpty || !combinedFoods.isEmpty) {
                // Сначала Food, потом Activities
                foodSection
                if !trainingsHistory.isEmpty {
                    activitiesSection
                }
            } else {
                // Сначала Activities, потом Food
                if !trainingsHistory.isEmpty {
                    activitiesSection
                }
                if !recentFoods.isEmpty || !combinedFoods.isEmpty {
                    foodSection
                }
            }
            
            // Отображение пустого состояния, если нет ни еды, ни активностей
            if recentFoods.isEmpty && combinedFoods.isEmpty && trainingsHistory.isEmpty && !navigationCoordinator.notFoodDetected {
                emptyStateView
            } else if navigationCoordinator.notFoodDetected {
                notFoodDetectedView
            }
        }
        .animation(.easeInOut, value: hasLoggedFood)
        .onAppear {
            // Удаляем lastAppleImage из UserDefaults, чтобы предотвратить появление яблока по умолчанию
            UserDefaults.standard.removeObject(forKey: "lastAppleImage")
            UserDefaults.standard.synchronize()
            
            // First, synchronize all ingredient statuses for consistency
            DispatchQueue.main.async {
                print("\n===== STARTING SYNCHRONIZATION =====")
                // Force re-sync all combined foods first
                let combinedFoodsItems = CombinedFoodManager.shared.getAllCombinedFoods()
                var allIngredientIds = Set<String>()
                
                // Process all combined foods to mark their ingredients
                for combinedFood in combinedFoodsItems {
                    for ingredient in combinedFood.ingredients {
                        if let id = ingredient.id {
                            let idString = id.uuidString
                            allIngredientIds.insert(idString)
                            
                            // Explicitly mark as ingredient
                            UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                            UserDefaults.standard.set(false, forKey: "single_food_\(idString)")
                            UserDefaults.standard.set(true, forKey: "force_hide_\(idString)")
                            ingredient.isIngredient = true
                        }
                    }
                    
                    // Mark the combined food itself as NOT an ingredient
                    let dishId = combinedFood.id.uuidString
                    UserDefaults.standard.set(false, forKey: "food_ingredient_\(dishId)")
                    UserDefaults.standard.set(true, forKey: "single_food_\(dishId)")
                    UserDefaults.standard.set(false, forKey: "force_hide_\(dishId)")
                }
                
                // Save all ingredient IDs for fast lookup
                if !allIngredientIds.isEmpty {
                    UserDefaults.standard.set(Array(allIngredientIds), forKey: "all_ingredient_ids")
                }
                
                // Save changes in CoreData
                do {
                    try CoreDataManager.shared.context.save()
                    UserDefaults.standard.synchronize()
                    print("✅ Successfully synchronized all ingredient statuses")
                } catch {
                    print("❌ Error saving synchronized data: \(error)")
                }
                print("===== SYNCHRONIZATION COMPLETE =====\n")
            }
            
            // Загружаем историю тренировок при появлении
            loadTrainingsHistory()
            
            // Загружаем недавние продукты из CoreData и UserDefaults
            loadAllFoodData()
            
            // Загружаем комбинированные блюда
            loadCombinedFoods()
            
            // Подписываемся на уведомления об изменении тренировок
            setupNotificationObservers()
            
            // Определяем, что показывать первым
            updateDisplayOrder()
        }
        .onDisappear {
            // Отписываемся от уведомлений при исчезновении
            if let observers = notificationObserver {
                for observer in observers {
                    NotificationCenter.default.removeObserver(observer)
                }
                notificationObserver = nil
            }
        }
        .onChange(of: analyzedFood) { _, _ in
            loadAllFoodData()
            loadCombinedFoods()
            updateDisplayOrder()
        }
        .onChange(of: trainingsHistory.count) { _, _ in
            updateDisplayOrder()
        }
    }
    
    // MARK: - View Components
    
    /// Секция с едой
    private var foodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Food")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 5)
            
            // Combined Food Items section
            if !combinedFoods.isEmpty {
                ForEach(combinedFoods) { combinedFood in
                    CombinedFoodItemView(
                        combinedFood: combinedFood,
                        offset: combinedFoodSwipeOffsets[combinedFood.id] ?? 0,
                        onDelete: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                // Убрана тактильная вибрация при удалении
                                
                                // Delete the combined food
                                deleteCombinedFood(combinedFood: combinedFood)
                            }
                        },
                        onTap: {
                            // Открываем детали только при прямом нажатии, не при свайпе
                            navigationCoordinator.showCombinedFoodDetails(for: combinedFood)
                        },
                        onDragChanged: { translation in
                            // Allow only left swipe (negative translation)
                            if translation < 0 {
                                // Плавное изменение смещения при свайпе
                                let newOffset = min(0, translation)
                                combinedFoodSwipeOffsets[combinedFood.id] = newOffset
                            }
                        },
                        onDragEnded: { translation in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if translation < -80 { // Уменьшенный порог для более отзывчивого свайпа
                                    // If swipe is large enough, show delete button
                                    combinedFoodSwipeOffsets[combinedFood.id] = -70 // Увеличенное значение для лучшей видимости кнопки
                                } else {
                                    // Otherwise reset position
                                    combinedFoodSwipeOffsets[combinedFood.id] = 0
                                }
                            }
                        },
                        getFormattedTime: getFormattedTime
                    )
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: combinedFood.id)
                }
            }
            
            // Individual Food Items
            ForEach(recentFoods) { food in
                FoodItemView(
                    food: food,
                    offset: foodSwipeOffsets[food.id ?? UUID()] ?? 0,
                    analyzedFood: analyzedFood,
                    animateNewFood: animateNewFood,
                    onDelete: {
                        withAnimation {
                            deleteFood(food: food)
                        }
                    },
                    onDragChanged: { translation in
                        if translation < 0 {
                            foodSwipeOffsets[food.id ?? UUID()] = translation
                        }
                    },
                    onDragEnded: { translation in
                        withAnimation {
                            if translation < -100 {
                                foodSwipeOffsets[food.id ?? UUID()] = -60
                            } else {
                                foodSwipeOffsets[food.id ?? UUID()] = 0
                            }
                        }
                    },
                    getFormattedTime: getFormattedTime
                )
                .padding(.horizontal)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: food.id)
                .onAppear {
                    // Запускаем анимацию при появлении нового продукта
                    if food.id == analyzedFood?.id {
                        animateNewFood = true
                        // Сбрасываем анимацию через 3 секунды
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                animateNewFood = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Секция с активностями
    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activities")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(trainingsHistory.indices, id: \.self) { index in
                if index < min(10, trainingsHistory.count) {
                    let activityDict = trainingsHistory[index]
                    if let activity = activityDict["activity"] as? String,
                       let calories = activityDict["calories"] as? Double,
                       let duration = activityDict["duration"] as? Int,
                       let timeString = activityDict["time"] as? String,
                       let activityId = activityDict["id"] as? String {
                        
                        let key = activityId
                        let offset = swipeOffsets[key] ?? 0
                        
                        ZStack {
                            // Кнопка удаления (слева)
                            HStack {
                                Spacer()
                                Button(action: {
                                    // Удаляем активность
                                    withAnimation {
                                        deleteActivity(activityId: activityId)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 80)
                                        .background(Color.red)
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Основная карточка активности
                            ActivityItemView(
                                activity: activity,
                                calories: calories,
                                duration: duration,
                                timeString: timeString
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                            )
                            .offset(x: offset)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        // Свайп только влево
                                        if gesture.translation.width < 0 {
                                            swipeOffsets[key] = gesture.translation.width
                                        }
                                    }
                                    .onEnded { gesture in
                                        withAnimation {
                                            // Определяем, нужно ли фиксировать свайп или вернуть в исходное положение
                                            if gesture.translation.width < -100 {
                                                // Фиксируем свайп влево для отображения кнопки удаления
                                                swipeOffsets[key] = -60
                                            } else {
                                                // Возвращаем в исходное положение
                                                swipeOffsets[key] = 0
                                            }
                                        }
                                    }
                            )
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: activityId)
                    }
                }
            }
        }
        .id(refreshID) // Force refresh when activities change
    }
    
    /// Отображение сообщения о том, что еда не распознана
    private var notFoodDetectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            Text("Not a food detected")
                .font(.headline)
            
            Text("Try scanning a food item again")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            Button(action: {
                // Сбрасываем флаг и открываем камеру снова
                navigationCoordinator.notFoodDetected = false
                navigationCoordinator.showScanCamera = true
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
        .transition(.opacity)
    }
    
    /// Отображение пустого состояния
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding(.bottom, 5)
            
            Text("No recently logged activities")
                .font(.headline)
            
            Text("Start tracking today's meals and workouts by pressing the + button.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .padding(.horizontal)
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
    private func updateDisplayOrder() {
        // Проверяем, что у нас есть данные для обоих блоков
        guard (!recentFoods.isEmpty || !combinedFoods.isEmpty) && !trainingsHistory.isEmpty else {
            // Если есть только еда, показываем ее сверху
            showFoodFirst = !recentFoods.isEmpty || !combinedFoods.isEmpty
            return
        }
        
        // Находим самую свежую запись о еде (включая комбинированные блюда)
        var latestFoodTime: Date?
        
        if let lastFood = recentFoods.first, let foodTime = lastFood.createdAt {
            latestFoodTime = foodTime
        }
        
        if let lastCombinedFood = combinedFoods.first {
            if latestFoodTime == nil || lastCombinedFood.createdAt > latestFoodTime! {
                latestFoodTime = lastCombinedFood.createdAt
            }
        }
        
        // Получаем последнюю активность
        if let lastFoodTime = latestFoodTime,
           let firstActivity = trainingsHistory.first,
           let activityTimeString = firstActivity["timeRaw"] as? Double {
            let activityTime = Date(timeIntervalSince1970: activityTimeString)
            
            // Сравниваем даты для определения порядка
            showFoodFirst = lastFoodTime > activityTime
        } else {
            // Если нет информации о времени активности, показываем еду сверху
            showFoodFirst = true
        }
    }
    
    // Настройка наблюдателей уведомлений
    private func setupNotificationObservers() {
        // Удаляем предыдущие обработчики, если они существуют
        if let observer = notificationObserver {
            for obs in observer {
                NotificationCenter.default.removeObserver(obs)
            }
        }
        
        var observers: [Any] = []
        
        // Создаем новый обработчик для обновления активностей
        let trainingObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TrainingHistoryUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            // Принудительно загружаем тренировки и обновляем интерфейс
            self.loadTrainingsHistory()
            self.updateDisplayOrder()
        }
        observers.append(trainingObserver)
        
        // Создаем новый обработчик для обновления еды
        let foodObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FoodUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            // Обновляем порядок отображения при обновлении еды
            self.loadAllFoodData()
            self.loadCombinedFoods()
            self.updateDisplayOrder()
        }
        observers.append(foodObserver)
        
        // Создаем обработчик для удаления комбинированных блюд
        let combinedFoodDeletedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CombinedFoodDeleted"),
            object: nil,
            queue: .main
        ) { notification in
            if let idString = notification.userInfo?["id"] as? String,
               let id = UUID(uuidString: idString) {
                print("RecentlyLoggedView: Получено уведомление об удалении комбинированного блюда \(idString)")
                
                // Удаляем из локального массива
                self.combinedFoods.removeAll(where: { $0.id == id })
                
                // Удаляем смещения свайпа
                self.combinedFoodSwipeOffsets.removeValue(forKey: id)
                
                // Обновляем интерфейс путем обновления refreshID
                self.refreshID = UUID()
            }
        }
        observers.append(combinedFoodDeletedObserver)
        
        // Храним ссылки на все обработчики (для возможности удаления в будущем)
        notificationObserver = observers
    }
    
    // Загрузка истории тренировок
    private func loadTrainingsHistory() {
        if let history = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] {
            // Берем только последние тренировки
            self.trainingsHistory = Array(history.prefix(10))
            
            // Обновляем ID для обновления интерфейса
            self.refreshID = UUID()
            
            // Сбрасываем смещения свайпов
            self.swipeOffsets.removeAll()
            
            // Выводим для отладки
            print("RecentlyLoggedView: Загружено \(self.trainingsHistory.count) активностей")
        } else {
            print("RecentlyLoggedView: История тренировок пуста")
            self.trainingsHistory = []
        }
    }
    
    // Загрузка всех продуктов из CoreData и UserDefaults
    private func loadAllFoodData() {
        // Получаем контекст CoreData
        let context = CoreDataManager.shared.context
        
        // Создаем запрос для получения всех объектов Food
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        // Дополнительно загружаем связанные ингредиенты
        fetchRequest.relationshipKeyPathsForPrefetching = ["ingredients"]
        
        // Сортируем по дате создания (сначала новые)
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Загружаем продукты из CoreData
        do {
            let allFoods = try context.fetch(fetchRequest)
            print("\n===== ЗАГРУЗКА ПРОДУКТОВ В RECENTLY LOGGED =====")
            print("Загружено всего продуктов: \(allFoods.count)")
            
            // Get a list of all combined foods first to check ingredients against
            let combinedFoodsItems = CombinedFoodManager.shared.getAllCombinedFoods()
            print("Найдено комбинированных блюд: \(combinedFoodsItems.count)")
            
            // Build a set of IDs for foods that are used as ingredients in combined dishes
            var combinedDishIngredientIds = Set<UUID>()
            
            // Pre-process: Force mark all ingredients of combined dishes as ingredients
            for combinedFood in combinedFoodsItems {
                print("🍱 Блюдо: \(combinedFood.name) содержит \(combinedFood.ingredients.count) ингредиентов")
                
                for ingredient in combinedFood.ingredients {
                    if let id = ingredient.id {
                        combinedDishIngredientIds.insert(id)
                        // Явно помечаем как ингредиент в CoreData
                        ingredient.isIngredient = true
                        // Также помечаем в UserDefaults
                        let idString = id.uuidString
                        UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                        UserDefaults.standard.set(false, forKey: "single_food_\(idString)")
                        print("  ✅ Ингредиент: \(ingredient.name ?? "Unknown") с ID \(idString)")
                    } else {
                        print("  ⚠️ Ингредиент без ID: \(ingredient.name ?? "Unknown")")
                    }
                }
            }
            
            // Save changes made to ingredients
            try context.save()
            UserDefaults.standard.synchronize()
            
            print("RecentlyLoggedView: Найдено \(combinedDishIngredientIds.count) ингредиентов в комбинированных блюдах")
            
            // Фильтруем, исключая ингредиенты, но включая блюда с ингредиентами
            let filteredFoods = allFoods.filter { food in
                guard let id = food.id else {
                    print("⚠️ Продукт без ID: \(food.name ?? "Unknown")")
                    return false
                }
                
                // FORCE CHECK: Directly look up if this food is in any combined dish's ingredients list
                let isIngredientOfCombinedDish = combinedDishIngredientIds.contains(id)
                
                if isIngredientOfCombinedDish {
                    // Explicitly mark as ingredient in all places for consistency
                    food.isIngredient = true
                    let idString = id.uuidString
                    UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                    UserDefaults.standard.set(false, forKey: "single_food_\(idString)")
                    UserDefaults.standard.set(true, forKey: "force_hide_\(idString)")
                    print("📋 СКРЫВАЕМ из Recently Logged: \(food.name ?? "Unknown") (ID: \(idString)) - это ингредиент комбинированного блюда")
                    return false // Always hide ingredients of combined dishes
                }
                
                // Проверяем, имеет ли продукт собственные ингредиенты (комбинированное блюдо)
                let hasIngredients = (food.ingredients?.count ?? 0) > 0
                
                if hasIngredients {
                    // Комбинированные блюда всегда показываем
                    food.isIngredient = false
                    let idString = id.uuidString
                    UserDefaults.standard.set(false, forKey: "food_ingredient_\(idString)")
                    UserDefaults.standard.set(true, forKey: "single_food_\(idString)")
                    print("🍲 ПОКАЗЫВАЕМ комбинированное блюдо: \(food.name ?? "Unknown") с \(food.ingredients?.count ?? 0) ингредиентами")
                    return true
                }
                
                // Дополнительная проверка с использованием полной логики
                let isIngredientFood = isIngredient(food: food)
                
                // Дополнительная проверка: принудительно скрытые ингредиенты
                let forceHide = UserDefaults.standard.bool(forKey: "force_hide_\(id.uuidString)")
                
                if forceHide || isIngredientFood {
                    print("📋 СКРЫВАЕМ продукт \(food.name ?? "Unknown") (isIngredient: \(isIngredientFood), forceHide: \(forceHide))")
                    return false
                }
                
                print("✅ ПОКАЗЫВАЕМ продукт: \(food.name ?? "Unknown")")
                return true
            }
            
            // Выводим информацию о найденных продуктах
            print("🧾 Загружено \(allFoods.count) продуктов из CoreData, после фильтрации: \(filteredFoods.count)")
            
            // Сохраняем отфильтрованные продукты
            recentFoods = filteredFoods
            
            // After filtering, save any changes to markings
            try context.save()
            UserDefaults.standard.synchronize()
            
            print("===== ЗАГРУЗКА ПРОДУКТОВ ЗАВЕРШЕНА =====\n")
        } catch {
            print("🚫 Ошибка при загрузке продуктов из CoreData: \(error)")
        }
    }
    
    // Load combined foods
    private func loadCombinedFoods() {
        print("\n===== ЗАГРУЗКА КОМБИНИРОВАННЫХ БЛЮД =====")
        
        // Получаем данные из CombinedFoodManager
        let combinedFoods = CombinedFoodManager.shared.getAllCombinedFoods()
        
        // Получаем список удаленных блюд из UserDefaults
        let deletedIds = UserDefaults.standard.array(forKey: "deletedCombinedFoods") as? [String] ?? []
        print("RecentlyLoggedView: Найдено \(deletedIds.count) ID удаленных комбинированных блюд")
        
        // Фильтруем, исключая удаленные
        let filteredFoods = combinedFoods.filter { combinedFood in
            // Check if this food ID is in the deleted list
            let isDeleted = deletedIds.contains(combinedFood.id.uuidString)
            if isDeleted {
                print("RecentlyLoggedView: Скрыто удаленное комбинированное блюдо: \(combinedFood.name)")
            }
            return !isDeleted
        }
        
        // Check if all foods were properly filtered
        if filteredFoods.count < combinedFoods.count {
            print("RecentlyLoggedView: Отфильтровано \(combinedFoods.count - filteredFoods.count) удаленных блюд")
        }
        
        // Update our local array with the filtered list
        self.combinedFoods = filteredFoods
        print("RecentlyLoggedView: Загружено \(self.combinedFoods.count) комбинированных блюд")
        
        // Track all ingredient IDs for faster lookups
        var allIngredientIds = Set<String>()
        
        // Make sure all ingredients are properly marked as ingredients in both UserDefaults and CoreData
        for combinedFood in self.combinedFoods {
            print("🍱 Обработка блюда: \(combinedFood.name) (\(combinedFood.ingredients.count) ингредиентов)")
            
            // Mark this combined food as NOT an ingredient
            let combinedFoodId = combinedFood.id.uuidString
            UserDefaults.standard.set(false, forKey: "food_ingredient_\(combinedFoodId)")
            UserDefaults.standard.set(true, forKey: "single_food_\(combinedFoodId)")
            UserDefaults.standard.set(false, forKey: "force_hide_\(combinedFoodId)")
            
            for ingredient in combinedFood.ingredients {
                if let id = ingredient.id {
                    let idString = id.uuidString
                    allIngredientIds.insert(idString)
                    
                    // Mark as ingredient in UserDefaults with multiple keys for redundancy
                    UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                    UserDefaults.standard.set(false, forKey: "single_food_\(idString)")
                    UserDefaults.standard.set(true, forKey: "force_hide_\(idString)")
                    
                    // Also mark as ingredient in CoreData
                    ingredient.isIngredient = true
                    print("  ✅ Маркирован как ингредиент: \(ingredient.name ?? "Unknown") (ID: \(idString))")
                } else {
                    print("  ⚠️ Ингредиент без ID: \(ingredient.name ?? "Unknown")")
                }
            }
        }
        
        // Save all ingredient IDs for fast lookup
        if !allIngredientIds.isEmpty {
            UserDefaults.standard.set(Array(allIngredientIds), forKey: "all_ingredient_ids")
            print("📝 Сохранено \(allIngredientIds.count) ID ингредиентов")
        }
        
        // Ensure changes are persistent
        do {
            try CoreDataManager.shared.context.save()
            UserDefaults.standard.synchronize()
        } catch {
            print("⚠️ Error saving ingredient status changes: \(error)")
        }
        
        // Reset swipe offsets for clean UI
        self.combinedFoodSwipeOffsets = [:]
        
        print("===== ЗАГРУЗКА КОМБИНИРОВАННЫХ БЛЮД ЗАВЕРШЕНА =====\n")
        
        // Force reload food data to ensure proper filtering
        DispatchQueue.main.async {
            self.loadAllFoodData()
        }
    }
    
    // Удаление активности по ID
    private func deleteActivity(activityId: String) {
        // Добавляем тактильный отклик
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Удаляем из смещений
        swipeOffsets.removeValue(forKey: activityId)
        
        // Вызываем метод удаления активности в HealthKitManager
        healthManager.deleteActivityById(activityId: activityId)
    }
    
    // Удаление еды
    private func deleteFood(food: Food) {
        // Добавляем тактильный отклик
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Сбрасываем смещение свайпа
        if let id = food.id {
            foodSwipeOffsets.removeValue(forKey: id)
            
            // Сохраняем имя для логирования
            let name = food.name ?? "Unknown Food"
            print("\n===== УДАЛЕНИЕ ПРОДУКТА: \(name) =====")
            
            // Вычитаем потребленные нутриенты из общего количества
            navigationCoordinator.userProfile.addConsumedFood(
                calories: -food.calories,
                protein: -food.protein,
                carbs: -food.carbs,
                fat: -food.fat
            )
            print("Обновлены данные о потреблении после удаления \(name)")
            
            // Сбрасываем analyzedFood, если мы удалили последний отсканированный продукт
            if food.id == analyzedFood?.id || food.id == navigationCoordinator.recentlyScannedFood?.id {
                navigationCoordinator.recentlyScannedFood = nil
                analyzedFood = nil
                print("Сброшен последний отсканированный продукт")
            }
            
            // Используем CoreDataManager для полного и надежного удаления продукта
            // Этот метод удаляет объект из CoreData и всех списков в UserDefaults
            CoreDataManager.shared.deleteFoodItem(id: id)
            
            // Обновляем список продуктов с обновленным методом
            DispatchQueue.main.async {
                self.loadAllFoodData()
                self.loadCombinedFoods()
                
                // Отправляем уведомление для обновления интерфейса
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
            }
            
            print("===== УДАЛЕНИЕ ПРОДУКТА ЗАВЕРШЕНО =====\n")
        }
    }
    
    // Delete a combined food item
    private func deleteCombinedFood(combinedFood: CombinedFoodItem) {
        print("\n===== УДАЛЕНИЕ КОМБИНИРОВАННОГО БЛЮДА =====")
        
        // Reset swipe offset
        combinedFoodSwipeOffsets.removeValue(forKey: combinedFood.id)
        
        print("DeleteCombinedFood: Удаление блюда \(combinedFood.name) с \(combinedFood.ingredients.count) ингредиентами")
        
        // Store the ID of this deleted food in UserDefaults to prevent reappearance
        let deletedIdsKey = "deletedCombinedFoods"
        var deletedIds = UserDefaults.standard.array(forKey: deletedIdsKey) as? [String] ?? []
        let idString = combinedFood.id.uuidString
        
        if !deletedIds.contains(idString) {
            deletedIds.append(idString)
            UserDefaults.standard.set(deletedIds, forKey: deletedIdsKey)
            print("✅ ID \(idString) добавлен в список удаленных блюд")
        }
        
        // Delete from CoreDataManager with ingredients
        CoreDataManager.shared.deleteCombinedFood(id: combinedFood.id, ingredients: combinedFood.ingredients)
        
        // Use the new purge method to completely remove all data
        CoreDataManager.shared.purgeAllDataForCombinedFood(id: combinedFood.id)
        
        // Delete from CombinedFoodManager
        CombinedFoodManager.shared.deleteCombinedFood(id: combinedFood.id)
        
        // Force synchronize UserDefaults to ensure persistence
        UserDefaults.standard.synchronize()
        
        // Remove from current display
        self.combinedFoods.removeAll(where: { $0.id == combinedFood.id })
        
        // Subtract nutrients from daily total
        navigationCoordinator.userProfile.addConsumedFood(
            calories: -combinedFood.calories,
            protein: -combinedFood.protein,
            carbs: -combinedFood.carbs,
            fat: -combinedFood.fat
        )
        
        print("DeleteCombinedFood: Обновлены данные о потреблении после удаления \(combinedFood.name)")
        
        // Update interface
        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        
        print("===== УДАЛЕНИЕ КОМБИНИРОВАННОГО БЛЮДА ЗАВЕРШЕНО =====\n")
    }
    
    // Функция для выбора иконки на основе типа продукта
    private func getIconForFood(_ foodName: String) -> String {
        let foodName = foodName.lowercased()
        
        if foodName.contains("apple") {
            return "apple.logo"
        } else if foodName.contains("banana") {
            return "leaf.fill"
        } else if foodName.contains("chicken") || foodName.contains("meat") || foodName.contains("beef") || foodName.contains("steak") {
            return "fork.knife"
        } else if foodName.contains("yogurt") || foodName.contains("milk") {
            return "cup.and.saucer.fill"
        } else if foodName.contains("bread") {
            return "square.grid.2x2.fill"
        } else if foodName.contains("cereal") || foodName.contains("rice") {
            return "dot.square.fill"
        } else if foodName.contains("juice") {
            return "drop.fill"
        } else if foodName.contains("broccoli") || foodName.contains("vegetable") {
            return "leaf.circle.fill"
        } else if foodName.contains("carrot") {
            return "triangle.fill"
        } else if foodName.contains("fish") || foodName.contains("salmon") || foodName.contains("seafood") {
            return "water.waves"
        } else if foodName.contains("coca-cola") || foodName.contains("cola") || foodName.contains("coke") {
            return "bubble.right.fill"
        } else if foodName.contains("water") {
            return "drop.fill"
        } else if foodName.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if foodName.contains("egg") {
            return "oval.fill"
        }
        
        return "circle.grid.2x2.fill" // Иконка по умолчанию
    }
    
    // Функция для выбора цвета на основе типа продукта
    private func getColorForFood(_ foodName: String) -> Color {
        let foodName = foodName.lowercased()
        
        if foodName.contains("apple") {
            return .red
        } else if foodName.contains("banana") {
            return .yellow
        } else if foodName.contains("chicken") || foodName.contains("meat") || foodName.contains("beef") || foodName.contains("steak") {
            return .brown
        } else if foodName.contains("yogurt") || foodName.contains("milk") {
            return .blue
        } else if foodName.contains("bread") {
            return .brown
        } else if foodName.contains("cereal") || foodName.contains("rice") {
            return .orange
        } else if foodName.contains("juice") {
            return .orange
        } else if foodName.contains("broccoli") || foodName.contains("vegetable") {
            return .green
        } else if foodName.contains("carrot") {
            return .orange
        } else if foodName.contains("fish") || foodName.contains("salmon") || foodName.contains("seafood") {
            return .blue
        } else if foodName.contains("coca-cola") || foodName.contains("cola") || foodName.contains("coke") {
            return .red
        } else if foodName.contains("water") {
            return .blue
        } else if foodName.contains("coffee") {
            return .brown
        } else if foodName.contains("egg") {
            return .yellow
        }
        
        return .green // Цвет по умолчанию
    }
    
    // Форматирование времени
    private func getFormattedTime(from date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    // Helper method to check if a food is an ingredient
    private func isIngredient(food: Food) -> Bool {
        if let id = food.id {
            let idString = id.uuidString
            
            // FIRST CHECK: Is this being forced to hide?
            let forceHide = UserDefaults.standard.bool(forKey: "force_hide_\(idString)")
            if forceHide {
                print("🚫 Продукт \(food.name ?? "Unknown") (ID: \(idString)) принудительно помечен как ингредиент")
                food.isIngredient = true
                return true
            }
            
            // SECOND CHECK: Is this in the all_ingredient_ids list?
            let allIngredientIds = UserDefaults.standard.array(forKey: "all_ingredient_ids") as? [String] ?? []
            if allIngredientIds.contains(idString) {
                print("🔍 Продукт \(food.name ?? "Unknown") (ID: \(idString)) найден в списке всех ингредиентов")
                food.isIngredient = true
                return true
            }
            
            // THIRD CHECK: Is this food in the deletion lists?
            let deletedFoodIds = UserDefaults.standard.array(forKey: "deletedFoodItems") as? [String] ?? []
            if deletedFoodIds.contains(idString) {
                // Используем только английское название
                let displayName = food.name ?? "Unknown"
                print("RecentlyLoggedView: ⚠️ Продукт \(displayName) (ID: \(idString)) находится в списке удаленных")
                return true // Treat deleted foods as ingredients (will hide them)
            }
            
            // FOURTH CHECK: if this is explicitly marked as single food, it's NOT an ingredient
            let isSingleFood = UserDefaults.standard.bool(forKey: "single_food_\(idString)")
            if isSingleFood {
                // If product was explicitly added as standalone, override other checks
                food.isIngredient = false
                UserDefaults.standard.set(false, forKey: "food_ingredient_\(idString)")
                UserDefaults.standard.synchronize()
                return false
            }
            
            // FIFTH CHECK: Check if this food is part of any dish (as an ingredient in a CombinedFoodItem)
            let combinedFoods = CombinedFoodManager.shared.getAllCombinedFoods()
            for combinedFood in combinedFoods {
                // Check if this food is an ingredient in the combined food
                if combinedFood.ingredients.contains(where: { $0.id == food.id }) {
                    // This food is part of a dish, so it's an ingredient and should be hidden
                    food.isIngredient = true
                    UserDefaults.standard.set(true, forKey: "food_ingredient_\(idString)")
                    UserDefaults.standard.set(false, forKey: "single_food_\(idString)")
                    UserDefaults.standard.set(true, forKey: "force_hide_\(idString)")
                    UserDefaults.standard.synchronize()
                    let displayName = food.name ?? "Unknown"
                    print("RecentlyLoggedView: ⭐️ Продукт \(displayName) является ингредиентом блюда \(combinedFood.name), скрываем из списка")
                    return true
                }
            }
            
            // SIXTH CHECK: Check for products with ingredients - they should always show
            if (food.ingredients?.count ?? 0) > 0 {
                // Используем только английское название
                let displayName = food.name ?? "Unknown"
                print("RecentlyLoggedView: Продукт \(displayName) имеет ингредиенты (\(food.ingredients?.count ?? 0)), показываем его")
                // Always show foods with ingredients (composite foods)
                food.isIngredient = false
                UserDefaults.standard.set(false, forKey: "food_ingredient_\(idString)")
                UserDefaults.standard.set(true, forKey: "single_food_\(idString)")
                UserDefaults.standard.synchronize()
                return false
            }
            
            // SEVENTH CHECK: Check if this is the last scanned food
            let lastScannedFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID")
            if lastScannedFoodID == idString {
                // Используем только английское название
                let displayName = food.name ?? "Unknown"
                print("RecentlyLoggedView: Продукт \(displayName) (ID: \(idString)) является последним отсканированным, НЕ ингредиент")
                
                // Force mark as NOT an ingredient in all places
                food.isIngredient = false
                UserDefaults.standard.set(false, forKey: "food_ingredient_\(idString)")
                UserDefaults.standard.set(true, forKey: "single_food_\(idString)")
                UserDefaults.standard.synchronize()
                return false
            }
            
            // FINAL CHECKS: User Defaults and CoreData flags
            let isMarkedInUserDefaults = UserDefaults.standard.bool(forKey: "food_ingredient_\(idString)")
            let isMarkedInCoreData = food.isIngredient
            
            // If marked as ingredient in either place, consider it an ingredient
            let result = isMarkedInUserDefaults || isMarkedInCoreData
            
            // If results don't match, synchronize
            if isMarkedInUserDefaults != isMarkedInCoreData {
                food.isIngredient = result
                UserDefaults.standard.set(result, forKey: "food_ingredient_\(idString)")
                UserDefaults.standard.synchronize()
                
                // Используем только английское название
                let displayName = food.name ?? "Unknown"
                
                if result {
                    print("🔄 Синхронизирован статус ингредиента для \(displayName) (ID: \(idString)): UserDefaults=\(isMarkedInUserDefaults), CoreData=\(isMarkedInCoreData) → true")
                } else {
                    print("🔄 Синхронизирован статус НЕингредиента для \(displayName) (ID: \(idString)): UserDefaults=\(isMarkedInUserDefaults), CoreData=\(isMarkedInCoreData) → false")
                }
            }
            
            if result {
                // Используем только английское название
                let displayName = food.name ?? "Unknown"
                print("RecentlyLoggedView: 🔍 Определен как ИНГРЕДИЕНТ: '\(displayName)' (ID: \(idString))")
            }
            
            return result
        }
        return false
    }
    
    // Called when user data has been updated
    private func onUserDataUpdated() {
        print("RecentlyLoggedView: Обновление данных пользователя")
        loadTrainingsHistory()
        loadAllFoodData()
        loadCombinedFoods()
        updateDisplayOrder()
    }
    
    // Синхронизация статуса ингредиентов между CoreData и UserDefaults
    private func syncIngredientsStatus() {
        print("Синхронизация статуса ингредиентов...")
        let context = CoreDataManager.shared.context
        
        // Получаем все продукты из CoreData
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        
        do {
            let allFoods = try context.fetch(fetchRequest)
            print("Найдено \(allFoods.count) продуктов в CoreData для синхронизации")
            
            var syncCount = 0
            
            for food in allFoods {
                if let id = food.id {
                    let idString = id.uuidString
                    let key = "food_ingredient_\(idString)"
                    let isMarkedInUserDefaults = UserDefaults.standard.bool(forKey: key)
                    
                    // Если продукт помечен как ингредиент в CoreData, но не в UserDefaults
                    if food.isIngredient && !isMarkedInUserDefaults {
                        UserDefaults.standard.set(true, forKey: key)
                        syncCount += 1
                        print("🔄 Синхронизирован ингредиент в UserDefaults: \(food.name ?? "Unknown") (ID: \(idString))")
                    }
                    // Если продукт помечен как ингредиент в UserDefaults, но не в CoreData
                    else if !food.isIngredient && isMarkedInUserDefaults {
                        food.isIngredient = true
                        syncCount += 1
                        print("🔄 Синхронизирован ингредиент в CoreData: \(food.name ?? "Unknown") (ID: \(idString))")
                    }
                }
            }
            
            // Сохраняем изменения в CoreData
            if syncCount > 0 {
                try context.save()
                UserDefaults.standard.synchronize()
                print("✅ Синхронизировано \(syncCount) ингредиентов")
            } else {
                print("✅ Все ингредиенты уже синхронизированы")
            }
            
        } catch {
            print("❌ Ошибка при синхронизации ингредиентов: \(error)")
        }
    }
}

// Компонент для отображения одной активности
struct ActivityItemView: View {
    let activity: String
    let calories: Double
    let duration: Int
    let timeString: String
    
    var body: some View {
        HStack(spacing: 15) {
            // Иконка активности
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: getIconForActivity(activity))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.black)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // Калории
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("\(Int(calories))")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    
                    // Длительность
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                        Text("\(duration) min")
                            .font(.subheadline)
                            .foregroundColor(.primary.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            // Время активности
            Text(timeString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // Функция для выбора иконки на основе типа активности
    private func getIconForActivity(_ activity: String) -> String {
        switch activity.lowercased() {
        case "run":
            return "figure.run"
        case "strength training":
            return "dumbbell.fill"
        case "cycling":
            return "bicycle"
        case "swimming":
            return "figure.pool.swim"
        case "walking":
            return "figure.walk"
        case "yoga":
            return "figure.mind.and.body"
        case "manual":
            return "hand.raised.fill"
        default:
            return "flame.fill"
        }
    }
}

// MARK: - Food Item Components

/// Представление элемента еды
private struct FoodItemView: View {
    let food: Food
    let offset: CGFloat
    let analyzedFood: Food?
    let animateNewFood: Bool
    let onDelete: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void
    let getFormattedTime: (Date) -> String
    
    var body: some View {
        ZStack {
            // Кнопка удаления (слева)
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .frame(width: 60, height: 80)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
        
            // Основная карточка еды
            HStack(spacing: 20) {
                // Изображение продукта
                FoodImageView(
                    food: food,
                    isHighlighted: food.id == analyzedFood?.id && animateNewFood
                )
                
                FoodNutritionView(food: food)
                
                Spacer()
                
                // Show ingredients count badge if this is a composed food with ingredients
                if food.isComposed && (food.ingredients?.count ?? 0) > 0 {
                    // Ingredient count badge
                    Text("\(food.ingredients?.count ?? 0)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Circle().fill(Color.green))
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .offset(x: -10, y: -20)
                }
                
                // Время добавления
                Text(getFormattedTime(food.createdAt ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .offset(x: offset)
            .onLongPressGesture {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                // Handle long press - open detail view
                if food.isComposed && (food.ingredients?.count ?? 0) > 0 {
                    NavigationCoordinator.shared.showFoodIngredientDetail(for: food)
                } else {
                    NavigationCoordinator.shared.showFoodDetail(for: food)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onDragChanged(value.translation.width)
                    }
                    .onEnded { value in
                        onDragEnded(value.translation.width)
                    }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if food.isComposed && (food.ingredients?.count ?? 0) > 0 {
                    NavigationCoordinator.shared.showFoodIngredientDetail(for: food)
                } else {
                    NavigationCoordinator.shared.showFoodDetail(for: food)
                }
            }
        }
    }
}

/// Представление изображения продукта
private struct FoodImageView: View {
    let food: Food
    let isHighlighted: Bool
    
    var body: some View {
        ZStack {
            // Проверяем наличие специального изображения для яблока в UserDefaults - ОТКЛЮЧЕНО
            // Предотвращаем появление яблок по умолчанию
            /*
            if food.name?.lowercased() == "apple",
               let appleImageData = UserDefaults.standard.data(forKey: "lastAppleImage"),
               let appleImage = UIImage(data: appleImageData) {
                
                Image(uiImage: appleImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .scaleEffect(isHighlighted ? 1.0 : 0.9)
                    .opacity(isHighlighted ? 1.0 : 0.95)
                    .onAppear {
                        print("🍎 ЯБЛОКО С ЗАПАСНЫМ ИЗОБРАЖЕНИЕМ: \(appleImageData.count) байт")
                    }
            }
            */
            // Улучшенная проверка наличия и валидности изображения - с более мягкими требованиями
            if let imageData = food.imageData,
                    // Более лояльные требования к изображению:
                    // 1. Даже небольшой размер данных приемлем - могут быть маленькие изображения
                    imageData.count >= 10,
                    // 2. Должно читаться как UIImage
                    let uiImage = UIImage(data: imageData) {
                
                // Добавляем отладочную информацию
                let imageSize = imageData.count
                
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .scaleEffect(isHighlighted ? 1.0 : 0.9)
                    .opacity(isHighlighted ? 1.0 : 0.95)
                    .onAppear {
                        print("✅ ИЗОБРАЖЕНИЕ ЗАГРУЖЕНО: \(food.name ?? "Unknown") (\(imageSize) байт, размер \(uiImage.size))")
                    }
            } else {
                // Выбираем иконку в зависимости от типа продукта
                let iconName = getIconForFood(food.name ?? "")
                
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(15)
                    .frame(width: 80, height: 80)
                    .foregroundColor(getColorForFood(food.name ?? ""))
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .scaleEffect(isHighlighted ? 1.0 : 0.9)
                    .opacity(isHighlighted ? 1.0 : 0.7)
                    .onAppear {
                        print("⚠️ ИСПОЛЬЗУЕМ ИКОНКУ для \(food.name ?? "Unknown") - иконка \(iconName)")
                        if let imgData = food.imageData {
                            print("❌ СБОЙ ЗАГРУЗКИ: Изображение существует размером \(imgData.count) байт, но не валидно")
                            
                            // Для любого продукта пробуем восстановить изображение
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                tryToRestoreImage(food: food)
                            }
                        } else {
                            print("❌ СБОЙ ЗАГРУЗКИ: Данные изображения отсутствуют полностью")
                        }
                    }
            }
            
            // Показываем индикатор для только что добавленного продукта
            if isHighlighted {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isHighlighted ? 1.1 : 1.0)
                    .opacity(isHighlighted ? 0 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.8)
                            .repeatCount(3, autoreverses: true),
                        value: isHighlighted
                    )
            }
        }
    }
    
    // Вспомогательная функция для восстановления изображения (для любого продукта)
    private func tryToRestoreImage(food: Food) {
        let context = CoreDataManager.shared.context
        
        // Для яблока есть особый путь восстановления - ОТКЛЮЧЕНО
        // Предотвращаем появление яблок по умолчанию
        /*
        if food.name?.lowercased() == "apple" {
            if let appleImageData = UserDefaults.standard.data(forKey: "lastAppleImage"),
               appleImageData.count >= 10 {
                updateFoodImage(food: food, imageData: appleImageData, context: context)
                return
            }
        }
        */
        
        // Для всех продуктов ищем бэкап по шаблону имени
        if let name = food.name, let id = food.id {
            // Поиск в бэкапах по имени
            let prefix = "imageBackup_\(name)_"
            let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
            
            for key in userDefaultsKeys where key.hasPrefix(prefix) {
                if let backupData = UserDefaults.standard.data(forKey: key),
                   backupData.count >= 10,
                   let _ = UIImage(data: backupData) {
                    print("🔄 ВОССТАНОВЛЕНИЕ: Найдено резервное изображение для \(name) по ключу \(key)")
                    updateFoodImage(food: food, imageData: backupData, context: context)
                    return
                }
            }
            
            // Если по имени не нашли, пробуем по ID
            if let improvedFood = CoreDataManager.shared.getFoodWithImage(id: id) {
                if let imageData = improvedFood.imageData, imageData.count >= 10 {
                    print("🔄 ВОССТАНОВЛЕНИЕ: Получено изображение через getFoodWithImage")
                    updateFoodImage(food: food, imageData: imageData, context: context)
                    return
                }
            }
        }
        
        print("❌ ВОССТАНОВЛЕНИЕ: Не найдено резервное изображение для \(food.name ?? "Unknown")")
    }
    
    // Общий метод для обновления изображения и сохранения изменений
    private func updateFoodImage(food: Food, imageData: Data, context: NSManagedObjectContext) {
        if let id = food.id {
            let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let foods = try context.fetch(fetchRequest)
                if let foodToUpdate = foods.first {
                    foodToUpdate.imageData = imageData
                    try context.save()
                    print("✅ ВОССТАНОВЛЕНИЕ: Обновлено изображение для \(food.name ?? "Unknown") в CoreData")
                    
                    // Уведомляем о необходимости обновить интерфейс
                    NotificationCenter.default.post(name: NSNotification.Name("FoodDataUpdated"), object: nil)
                }
            } catch {
                print("❌ ВОССТАНОВЛЕНИЕ: Ошибка при обновлении изображения: \(error)")
            }
        }
    }
    
    // Функция для выбора иконки на основе типа продукта
    private func getIconForFood(_ foodName: String) -> String {
        let foodName = foodName.lowercased()
        
        if foodName.contains("apple") {
            return "apple.logo"
        } else if foodName.contains("banana") {
            return "leaf.fill"
        } else if foodName.contains("chicken") || foodName.contains("meat") || foodName.contains("beef") || foodName.contains("steak") {
            return "fork.knife"
        } else if foodName.contains("yogurt") || foodName.contains("milk") {
            return "cup.and.saucer.fill"
        } else if foodName.contains("bread") {
            return "square.grid.2x2.fill"
        } else if foodName.contains("cereal") || foodName.contains("rice") {
            return "dot.square.fill"
        } else if foodName.contains("juice") {
            return "drop.fill"
        } else if foodName.contains("broccoli") || foodName.contains("vegetable") {
            return "leaf.circle.fill"
        } else if foodName.contains("carrot") {
            return "triangle.fill"
        } else if foodName.contains("fish") || foodName.contains("salmon") || foodName.contains("seafood") {
            return "water.waves"
        } else if foodName.contains("coca-cola") || foodName.contains("cola") || foodName.contains("coke") {
            return "bubble.right.fill"
        } else if foodName.contains("water") {
            return "drop.fill"
        } else if foodName.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if foodName.contains("egg") {
            return "oval.fill"
        }
        
        return "circle.grid.2x2.fill" // Иконка по умолчанию
    }
    
    // Функция для выбора цвета на основе типа продукта
    private func getColorForFood(_ foodName: String) -> Color {
        let foodName = foodName.lowercased()
        
        if foodName.contains("apple") {
            return .red
        } else if foodName.contains("banana") {
            return .yellow
        } else if foodName.contains("chicken") || foodName.contains("meat") || foodName.contains("beef") || foodName.contains("steak") {
            return .brown
        } else if foodName.contains("yogurt") || foodName.contains("milk") {
            return .blue
        } else if foodName.contains("bread") {
            return .brown
        } else if foodName.contains("cereal") || foodName.contains("rice") {
            return .orange
        } else if foodName.contains("juice") {
            return .orange
        } else if foodName.contains("broccoli") || foodName.contains("vegetable") {
            return .green
        } else if foodName.contains("carrot") {
            return .orange
        } else if foodName.contains("fish") || foodName.contains("salmon") || foodName.contains("seafood") {
            return .blue
        } else if foodName.contains("coca-cola") || foodName.contains("cola") || foodName.contains("coke") {
            return .red
        } else if foodName.contains("water") {
            return .blue
        } else if foodName.contains("coffee") {
            return .brown
        } else if foodName.contains("egg") {
            return .yellow
        }
        
        return .green // Цвет по умолчанию
    }
}

/// Представление деталей продукта
private struct FoodNutritionView: View {
    let food: Food
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Используем только английское название
            Text(food.name ?? "Unknown Food")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
            
            HStack {
                // Calories remain with flame icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    )
                Text("\(Int(food.calories)) calories")
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.8))
            }
            
            // Nutrient icons with values
            HStack(spacing: 12) {
                // Proteins - P in red square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("P")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(food.protein))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                
                // Carbs - C in blue square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("C")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(food.carbs))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
                
                // Fats - F in orange square
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("F")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(Int(food.fat))g")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                }
            }
        }
    }
}

struct RecentlyLoggedView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyLoggedView(
            hasLoggedFood: true,
            isScanning: false,
            isAnalyzing: false,
            analyzedFood: nil
        )
    }
}








