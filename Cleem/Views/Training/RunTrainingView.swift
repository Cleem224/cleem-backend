import SwiftUI

struct RunTrainingView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var healthManager: HealthKitManager
    @Binding var isPresented: Bool
    
    @State private var duration: Int = 30
    @State private var showNumericKeyboard: Bool = false
    @State private var showResults: Bool = false
    @State private var caloriesBurned: Int = 0
    @State private var isEditing: Bool = false
    
    // Предустановленные значения для быстрого выбора
    private let presetDurations = [15, 30, 60]
    
    // Расчет калорий в зависимости от времени бега (примерная формула)
    private func calculateCalories(duration: Int) -> Int {
        // Средний расход калорий при беге: примерно 7-10 ккал в минуту
        // Используем упрощенную формулу: 7.5 ккал * минуты
        let averageCaloriesPerMinute: Double = 7.5
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
                    
                    // Заголовок "Run"
                    Text("Run")
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
                    
                    // Кнопка "Go" внизу экрана (показываем всегда, но с разными размерами)
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
                // Экран результатов
                CompletionResultView(
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

// Представление для отображения результатов
struct CompletionResultView: View {
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
                    // Иконка огня (возвращаем пламя вместо бегущего человека)
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
        healthManager.addBurnedCalories(calories: Double(caloriesBurned), activity: "Run", duration: duration)
        
        // Обновляем историю тренировок (можно реализовать в будущем)
        
        // Генерируем тактильный отклик
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// Пользовательская цифровая клавиатура
struct NumericKeyboard: View {
    @Binding var value: Int
    @Binding var isActive: Bool
    
    // Преобразование числа в строку для редактирования
    @State private var inputText: String = ""
    
    // Инициализация текстового поля при появлении клавиатуры
    init(value: Binding<Int>, isActive: Binding<Bool>) {
        self._value = value
        self._isActive = isActive
        self._inputText = State(initialValue: String(value.wrappedValue))
    }
    
    var body: some View {
        VStack(spacing: 5) {
            // Ряды клавиатуры
            HStack(spacing: 5) {
                numericButton("1")
                numericButton("2")
                numericButton("3")
            }
            
            HStack(spacing: 5) {
                numericButton("4")
                numericButton("5")
                numericButton("6")
            }
            
            HStack(spacing: 5) {
                numericButton("7")
                numericButton("8")
                numericButton("9")
            }
            
            HStack(spacing: 5) {
                // Пустое место вместо точки для целочисленного ввода
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                
                numericButton("0")
                
                // Кнопка удаления
                Button(action: {
                    if inputText.count > 0 {
                        inputText.removeLast()
                        updateValue()
                        
                        // Добавляем тактильный отклик
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                }
            }
        }
        .padding(.horizontal, 5)
        .onChange(of: value) { newValue in
            inputText = String(newValue)
        }
    }
    
    // Кнопка с цифрой
    private func numericButton(_ digit: String) -> some View {
        Button(action: {
            appendDigit(digit)
            
            // Добавляем тактильный отклик при нажатии на цифру
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            VStack {
                Text(digit)
                    .font(.system(size: 26, weight: .medium))
                
                // Добавляем буквы под цифрами как в iPhone клавиатуре
                if digit != "1" && digit != "0" {
                    let letters = lettersForDigit(digit)
                    Text(letters)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.black)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
    }
    
    // Добавление цифры к вводимому значению
    private func appendDigit(_ digit: String) {
        // Проверяем, чтобы не было слишком длинных чисел
        if inputText.count < 5 {
            // Если текущее значение 0, заменяем его
            if inputText == "0" {
                inputText = digit
            } else {
                inputText += digit
            }
            updateValue()
        }
    }
    
    // Обновление числового значения
    private func updateValue() {
        // Преобразуем строку в число
        if let newValue = Int(inputText) {
            // Ограничиваем значение разумным пределом для минут (10000 минут = около 7 дней)
            value = min(newValue, 10000)
        } else {
            // Если строка пуста или некорректна, устанавливаем значение 0
            value = 0
        }
    }
    
    // Получение букв для цифровой клавиатуры
    private func lettersForDigit(_ digit: String) -> String {
        switch digit {
        case "2": return "A B C"
        case "3": return "D E F"
        case "4": return "G H I"
        case "5": return "J K L"
        case "6": return "M N O"
        case "7": return "P Q R S"
        case "8": return "T U V"
        case "9": return "W X Y Z"
        default: return ""
        }
    }
}

// Preview
struct RunTrainingView_Previews: PreviewProvider {
    static var previews: some View {
        RunTrainingView(isPresented: .constant(true))
            .environmentObject(NavigationCoordinator.shared)
            .environmentObject(HealthKitManager.shared)
    }
} 