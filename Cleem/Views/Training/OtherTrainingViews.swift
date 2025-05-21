import SwiftUI

// Представление для силовых тренировок
struct StrengthTrainingView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var healthManager: HealthKitManager
    @Binding var isPresented: Bool
    
    @State private var duration: Int = 30
    @State private var showNumericKeyboard: Bool = false
    @State private var showResults: Bool = false
    @State private var caloriesBurned: Int = 0
    @State private var isEditing: Bool = false
    
    // Предустановленные значения для быстрого выбора
    private let presetDurations = [20, 30, 45]
    
    // Расчет калорий в зависимости от времени силовой тренировки
    private func calculateCalories(duration: Int) -> Int {
        // Средний расход калорий при силовой тренировке: примерно 4-6 ккал в минуту
        // Используем упрощенную формулу: 5 ккал * минуты
        let averageCaloriesPerMinute: Double = 5.0
        return Int(Double(duration) * averageCaloriesPerMinute)
    }
    
    var body: some View {
        ZStack {
            // Фон отображается только если не показываем результаты
            if !showResults {
                VStack(spacing: showNumericKeyboard ? 5 : 15) {
                    // Заголовок с кнопками назад и Done
                    HStack {
                        // Кнопка назад
                        Button(action: {
                            if showNumericKeyboard {
                                showNumericKeyboard = false
                            } else {
                                isPresented = false
                            }
                            
                            // Добавляем тактильный отклик при нажатии кнопки назад
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: showNumericKeyboard ? 16 : 20))
                                .foregroundColor(.black)
                                .padding(showNumericKeyboard ? 8 : 12)
                                .background(Circle().fill(Color.gray.opacity(0.2)))
                        }
                        
                        Spacer()
                        
                        // Кнопка Done (видна только при открытой клавиатуре)
                        if showNumericKeyboard {
                            Button(action: {
                                showNumericKeyboard = false
                                isEditing = false
                                
                                // Добавляем тактильный отклик
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }) {
                                Text("Done")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black)
                                    .cornerRadius(18)
                            }
                        }
                    }
                    .padding([.top, .leading, .trailing], showNumericKeyboard ? 10 : 20)
                    
                    // Заголовок "Strength training"
                    Text("Strength training")
                        .font(.system(size: showNumericKeyboard ? 24 : 30, weight: .bold))
                        .padding(.top, showNumericKeyboard ? 2 : 10)
                    
                    // Блок выбора продолжительности
                    VStack(alignment: .leading, spacing: showNumericKeyboard ? 8 : 20) {
                        // Заголовок с иконкой
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: showNumericKeyboard ? 18 : 24))
                            Text("Duration")
                                .font(.system(size: showNumericKeyboard ? 18 : 24, weight: .bold))
                        }
                        .padding(.top, showNumericKeyboard ? 5 : 30)
                        
                        // Быстрый выбор продолжительности
                        HStack(spacing: showNumericKeyboard ? 8 : 15) {
                            ForEach(presetDurations, id: \.self) { preset in
                                Button(action: {
                                    duration = preset
                                    isEditing = false
                                }) {
                                    Text("\(preset) mins")
                                        .font(.system(size: showNumericKeyboard ? 14 : 16, weight: .medium))
                                        .foregroundColor(duration == preset ? .white : .black)
                                        .padding(.vertical, showNumericKeyboard ? 4 : 8)
                                        .padding(.horizontal, showNumericKeyboard ? 10 : 16)
                                        .background(
                                            Capsule()
                                                .fill(duration == preset ? Color.black : Color.gray.opacity(0.2))
                                        )
                                }
                            }
                        }
                        
                        // Поле для ввода продолжительности
                        Button(action: {
                            isEditing = true
                            showNumericKeyboard = true
                        }) {
                            Text("\(duration)")
                                .font(.system(size: showNumericKeyboard ? 20 : 24, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, showNumericKeyboard ? 8 : 15)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Кнопка "Go" внизу экрана
                    Button(action: {
                        if showNumericKeyboard {
                            // Если клавиатура открыта, сначала закрываем её
                            showNumericKeyboard = false
                            isEditing = false
                        }
                        
                        // Рассчитываем сожженные калории
                        caloriesBurned = calculateCalories(duration: duration)
                        
                        // Показываем экран с результатами
                        withAnimation {
                            showResults = true
                        }
                    }) {
                        Text("Go")
                            .font(.system(size: showNumericKeyboard ? 16 : 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(showNumericKeyboard ? 10 : 16)
                            .background(Color.black)
                            .cornerRadius(30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, showNumericKeyboard ? 10 : 40)
                }
                .background(Color.white)
                .edgesIgnoringSafeArea(.bottom)
                
                // Цифровая клавиатура, если она активна
                if showNumericKeyboard {
                    VStack {
                        Spacer()
                        
                        // Пользовательская клавиатура без панели сверху
                        NumericKeyboard(value: $duration, isActive: $showNumericKeyboard)
                            .frame(height: 280)
                            .background(Color(UIColor.systemGray6))
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
            } else {
                // Экран результатов для силовой тренировки
                StrengthCompletionResultView(
                    isPresented: $isPresented,
                    showResults: $showResults,
                    duration: duration,
                    caloriesBurned: $caloriesBurned
                )
                .environmentObject(healthManager)
            }
        }
        .navigationBarHidden(true)
    }
}

// Представление для отображения результатов силовой тренировки
struct StrengthCompletionResultView: View {
    @EnvironmentObject var healthManager: HealthKitManager
    @Binding var isPresented: Bool
    @Binding var showResults: Bool
    let duration: Int
    @Binding var caloriesBurned: Int
    @State private var showNumericKeyboard: Bool = false
    
    var body: some View {
        ZStack {
            // Белый фон на весь экран
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: showNumericKeyboard ? 5 : 15) {
                // Заголовок с кнопками назад и Done
                HStack {
                    // Кнопка назад
                    Button(action: {
                        if showNumericKeyboard {
                            showNumericKeyboard = false
                        } else {
                            withAnimation {
                                showResults = false
                            }
                        }
                        
                        // Добавляем тактильный отклик при нажатии кнопки назад
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: showNumericKeyboard ? 16 : 20))
                            .foregroundColor(.black)
                            .padding(showNumericKeyboard ? 8 : 12)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .padding(.top, showNumericKeyboard ? 0 : 5) // Немного смещаем кнопку вниз
                    
                    Spacer()
                    
                    // Кнопка Done (видна только при открытой клавиатуре)
                    if showNumericKeyboard {
                        Button(action: {
                            showNumericKeyboard = false
                            
                            // Добавляем тактильный отклик
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black)
                                .cornerRadius(18)
                        }
                    }
                }
                .padding([.top, .leading, .trailing], showNumericKeyboard ? 10 : 20)
                
                VStack(spacing: showNumericKeyboard ? 8 : 20) {
                    // Иконка гантели
                    Image(systemName: "flame.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: showNumericKeyboard ? 40 : 60, height: showNumericKeyboard ? 40 : 60)
                        .foregroundColor(.black)
                        .padding(showNumericKeyboard ? 8 : 20)
                    
                    // Сообщение об успехе (уменьшаем шрифт при открытой клавиатуре)
                    Text("Great job!")
                        .font(.system(size: showNumericKeyboard ? 22 : 30, weight: .bold))
                        .padding(.top, showNumericKeyboard ? 0 : 10)
                    
                    // Отображение и редактирование калорий
                    HStack {
                        Text("\(caloriesBurned)")
                            .font(.system(size: showNumericKeyboard ? 26 : 40, weight: .bold))
                        
                        // Иконка карандаша для редактирования
                        Button(action: {
                            showNumericKeyboard = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: showNumericKeyboard ? 16 : 18))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, showNumericKeyboard ? 2 : 5)
                    
                    Text("Calories burned")
                        .font(.system(size: showNumericKeyboard ? 16 : 18))
                        .foregroundColor(.black)
                }
                .frame(maxHeight: showNumericKeyboard ? nil : .infinity)
                
                Spacer()
                
                // Кнопка подтверждения (уменьшаем размеры при открытой клавиатуре)
                Button(action: {
                    if showNumericKeyboard {
                        // Если клавиатура открыта, сначала закрываем её
                        showNumericKeyboard = false
                    } else {
                        // Сохраняем тренировку и обновляем сожженные калории
                        saveTraining()
                        
                        // Закрываем все представления
                        isPresented = false
                    }
                }) {
                    Text("Done")
                        .font(.system(size: showNumericKeyboard ? 16 : 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(showNumericKeyboard ? 10 : 16)
                        .background(Color.black)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, showNumericKeyboard ? 10 : 40)
            }
            
            // Цифровая клавиатура для редактирования калорий
            if showNumericKeyboard {
                VStack {
                    Spacer()
                    
                    // Пользовательская клавиатура
                    NumericKeyboard(value: $caloriesBurned, isActive: $showNumericKeyboard)
                        .frame(height: 280)
                        .background(Color(UIColor.systemGray6))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .navigationBarHidden(true)
    }
    
    // Функция для сохранения тренировки
    private func saveTraining() {
        // Обновляем сожженные калории в HealthKitManager
        healthManager.addBurnedCalories(calories: Double(caloriesBurned), activity: "Strength training", duration: duration)
        
        // Генерируем тактильный отклик
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// Представление для ручного ввода калорий
struct ManualCaloriesEntryView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var healthManager: HealthKitManager
    @Binding var isPresented: Bool
    
    @State private var calories: Int = 100
    @State private var showNumericKeyboard: Bool = false
    
    var body: some View {
        ZStack {
            // Белый фон на весь экран
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: showNumericKeyboard ? 5 : 15) {
                // Заголовок с кнопками назад и Done
                HStack {
                    // Кнопка назад
                    Button(action: {
                        if showNumericKeyboard {
                            showNumericKeyboard = false
                        } else {
                            isPresented = false
                        }
                        
                        // Добавляем тактильный отклик при нажатии кнопки назад
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: showNumericKeyboard ? 16 : 20))
                            .foregroundColor(.black)
                            .padding(showNumericKeyboard ? 8 : 12)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .padding(.top, showNumericKeyboard ? 0 : 5)
                    
                    Spacer()
                    
                    // Кнопка Done (видна только при открытой клавиатуре)
                    if showNumericKeyboard {
                        Button(action: {
                            showNumericKeyboard = false
                            
                            // Добавляем тактильный отклик
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                        }) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black)
                                .cornerRadius(18)
                        }
                    }
                }
                .padding([.top, .leading, .trailing], showNumericKeyboard ? 10 : 20)
                
                VStack(spacing: showNumericKeyboard ? 8 : 20) {
                    // Иконка огня
                    Image(systemName: "flame.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: showNumericKeyboard ? 40 : 60, height: showNumericKeyboard ? 40 : 60)
                        .foregroundColor(.black)
                        .padding(showNumericKeyboard ? 8 : 20)
                    
                    // Сообщение об успехе
                    Text("Great job!")
                        .font(.system(size: showNumericKeyboard ? 22 : 30, weight: .bold))
                        .padding(.top, showNumericKeyboard ? 0 : 10)
                    
                    // Отображение и редактирование калорий
                    HStack {
                        Text("\(calories)")
                            .font(.system(size: showNumericKeyboard ? 26 : 40, weight: .bold))
                        
                        // Иконка карандаша для редактирования
                        Button(action: {
                            showNumericKeyboard = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: showNumericKeyboard ? 16 : 18))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, showNumericKeyboard ? 2 : 5)
                    
                    Text("Calories burned")
                        .font(.system(size: showNumericKeyboard ? 16 : 18))
                        .foregroundColor(.black)
                }
                .frame(maxHeight: showNumericKeyboard ? nil : .infinity)
                
                Spacer()
                
                // Кнопка "Done"
                Button(action: {
                    if showNumericKeyboard {
                        // Если клавиатура открыта, сначала закрываем её
                        showNumericKeyboard = false
                    } else {
                        // Обновляем сожженные калории в HealthKitManager
                        healthManager.addBurnedCalories(calories: Double(calories), activity: "Manual", duration: 0)
                        
                        // Генерируем тактильный отклик
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Закрываем представление
                        isPresented = false
                    }
                }) {
                    Text("Done")
                        .font(.system(size: showNumericKeyboard ? 16 : 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(showNumericKeyboard ? 10 : 16)
                        .background(Color.black)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, showNumericKeyboard ? 10 : 40)
            }
            
            // Цифровая клавиатура для редактирования калорий
            if showNumericKeyboard {
                VStack {
                    Spacer()
                    
                    // Пользовательская клавиатура
                    NumericKeyboard(value: $calories, isActive: $showNumericKeyboard)
                        .frame(height: 280)
                        .background(Color(UIColor.systemGray6))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .navigationBarHidden(true)
    }
}

// Preview
struct OtherTrainingViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StrengthTrainingView(isPresented: .constant(true))
                .environmentObject(NavigationCoordinator.shared)
                .environmentObject(HealthKitManager.shared)
            
            ManualCaloriesEntryView(isPresented: .constant(true))
                .environmentObject(NavigationCoordinator.shared)
                .environmentObject(HealthKitManager.shared)
        }
    }
} 