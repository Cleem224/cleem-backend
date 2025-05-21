import SwiftUI
import CoreHaptics
import UIKit
// Константы уведомлений определены в NotificationConstants.swift
// и доступны глобально через расширение Notification.Name

struct NutritionParameterEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Входящие параметры
    var parameterType: NutritionParameterType
    @Binding var value: Int
    var onDismiss: (() -> Void)? // Добавляем опциональный обработчик для закрытия
    
    // Состояние
    @State private var localValue: Int
    @State private var inputValue: String = ""
    @State private var initialValue: Int
    @State private var displayValue: Int // Значение для отображения в верхнем индикаторе
    @State private var animateItems = false
    @State private var isNavigating = false
    @FocusState private var isInputFocused: Bool // Состояние фокуса для TextField
    
    // Цвет для индикатора прогресса
    private var progressColor: Color {
        switch parameterType {
        case .calories:
            return Color.black
        case .protein:
            return Color.red
        case .carbs:
            return Color.blue
        case .fats:
            return Color.orange
        }
    }
    
    // Вычисляем относительный прогресс для визуализации
    private var relativeProgress: CGFloat {
        let min = minValue
        let max = maxValue
        
        // Вычисляем прогресс в диапазоне от 0.1 до 1.0 (никогда не пустой круг)
        let progress = CGFloat(displayValue - min) / CGFloat(max - min)
        return 0.1 + (progress * 0.9) // Минимум 10% круга всегда заполнено
    }
    
    // Минимальное значение для каждого параметра
    private var minValue: Int {
        switch parameterType {
        case .calories: return 500
        case .protein: return 20
        case .carbs: return 20
        case .fats: return 10
        }
    }
    
    // Максимальное значение для каждого параметра
    private var maxValue: Int {
        switch parameterType {
        case .calories: return 4000
        case .protein: return 300
        case .carbs: return 500
        case .fats: return 200
        }
    }
    
    // Инициализатор
    init(parameterType: NutritionParameterType, value: Binding<Int>, onDismiss: (() -> Void)? = nil) {
        self.parameterType = parameterType
        self._value = value
        self.onDismiss = onDismiss
        self._localValue = State(initialValue: value.wrappedValue)
        self._initialValue = State(initialValue: value.wrappedValue)
        self._displayValue = State(initialValue: value.wrappedValue) // Начальное значение для отображения
        self._inputValue = State(initialValue: String(value.wrappedValue))
    }
    
    var body: some View {
        ZStack {
            // Фон экрана - белый
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад
                HStack(spacing: 0) {
                    // Кнопка "Назад"
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        // Вибрация при нажатии
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Сохраняем значение перед закрытием
                        saveToUserProfile()
                        
                        // Закрываем представление и возвращаемся
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(.leading, 20)
                    .disabled(isNavigating)
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                // Заголовок
                Text("Edit \(parameterType.title) Goal")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer().frame(height: 50)
                
                // Контейнер для отображения значения и индикатора
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    
                    HStack {
                        // Индикатор прогресса
                        ZStack {
                            // Серый фоновый круг
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                .frame(width: 70, height: 70)
                            
                            // Прогресс в зависимости от выбранного значения
                            Circle()
                                .trim(from: 0, to: relativeProgress)
                                .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .foregroundColor(progressColor)
                                .frame(width: 70, height: 70)
                                .rotationEffect(Angle(degrees: -90))
                                .animation(.easeInOut(duration: 0.3), value: displayValue)
                            
                            // Иконка внутри (например, пламя для калорий)
                            if parameterType.useCustomSquareBackground {
                                // Custom square background for all nutrients
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Group {
                                            if parameterType == .calories {
                                                Image(systemName: "flame.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            } else if parameterType == .protein {
                                                Text("P")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            } else if parameterType == .carbs {
                                                Text("C")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            } else if parameterType == .fats {
                                                Text("F")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    )
                            } else {
                                Image(systemName: parameterType.iconName)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(progressColor)
                            }
                        }
                        .padding(.leading, 25)
                        .padding(.vertical, 20)
                        
                        Spacer()
                        
                        // Значение (показываем текущее выбранное значение)
                        Text(displayValue.description)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.trailing)
                            .padding(.trailing, 30)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayValue)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 20)
                
                // Текстовое поле с выбранным значением
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                    
                    HStack {
                        Text(parameterType.label)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color.gray.opacity(0.8))
                            .padding(.leading, 25)
                        
                        Spacer()
                        
                        // Текстовое поле для ввода с системной клавиатурой
                        TextField("", text: $inputValue)
                            .keyboardType(.numberPad) // Цифровая клавиатура
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .padding(.trailing, 30)
                            .focused($isInputFocused) // Связываем с состоянием фокуса
                            .onChange(of: inputValue) { newValue in
                                handleInputChange(newValue)
                            }
                            // Добавляем тонкую анимацию при фокусе
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isInputFocused ? Color.gray.opacity(0.1) : Color.clear)
                                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                            )
                            // Добавляем тактильный отклик при редактировании
                            .onChange(of: isInputFocused) { focused in
                                if focused {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred(intensity: 0.4)
                                }
                            }
                    }
                }
                .frame(height: 80)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .onTapGesture {
                    // Активируем фокус на текстовое поле
                    isInputFocused = true
                }
                
                Spacer()
                
                // Кнопки Revert и Done
                HStack(spacing: 15) {
                    // Кнопка Revert
                    Button(action: {
                        // Более явная и заметная вибрация для Revert
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare() // Подготавливаем генератор
                        generator.impactOccurred(intensity: 0.8)
                        
                        // Возвращаем начальное значение
                        localValue = initialValue
                        inputValue = String(initialValue)
                        // displayValue остается неизменным до нажатия Done
                    }) {
                        Text("Revert")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .background(Capsule().fill(Color.white))
                            )
                    }
                    .buttonStyle(ScaleButtonStyle()) // Добавляем анимацию нажатия
                    
                    // Кнопка Done
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        // Скрываем клавиатуру
                        isInputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
                        // Сохраняем выбранное значение
                        if let newValue = Int(inputValue), newValue >= minValue, newValue <= maxValue {
                            localValue = newValue
                            // Обновляем привязанное значение
                            value = newValue
                            
                            // Обновляем отображаемое значение верхнего индикатора
                            displayValue = newValue
                            
                            // Сохраняем в профиль пользователя
                            saveToUserProfile()
                        }
                        
                        // Вибрация успеха
                        let generator = UINotificationFeedbackGenerator()
                        generator.prepare() // Подготавливаем генератор
                        generator.notificationOccurred(.success)
                        
                        // Закрываем представление
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.black)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle()) // Добавляем анимацию нажатия
                    .disabled(isNavigating)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onAppear {
                isNavigating = false
                
                // Автоматически фокусируемся на поле ввода и показываем клавиатуру
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
                
                // Установка начальных значений
                displayValue = localValue
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // Обработка изменения ввода
    private func handleInputChange(_ newValue: String) {
        // Проверяем, что введенное значение является числом
        if newValue.isEmpty {
            // Если поле пустое, оставляем его пустым
            inputValue = ""
            return
        }
        
        // Убираем все нецифровые символы
        let filtered = newValue.filter { "0123456789".contains($0) }
        
        // Если что-то изменилось после фильтрации, обновляем текст
        if filtered != newValue {
            inputValue = filtered
            return
        }
        
        // Если значение слишком большое, ограничиваем максимумом
        if let intValue = Int(filtered), intValue > maxValue {
            inputValue = String(maxValue)
            
            // Легкая вибрация при превышении максимума
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.5)
            
            return
        }
        
        // Сохраняем введенное значение
        if let intValue = Int(filtered) {
            localValue = intValue
        }
    }
    
    // Сохранение значения в профиль пользователя
    private func saveToUserProfile() {
        switch parameterType {
        case .calories:
            // Если меняются калории, пересчитываем все макронутриенты с сохранением пропорций
            navigationCoordinator.userProfile.recalculateNutrientsFromCalories(newCalories: Double(localValue))
            // Обновляем привязанное значение
            value = localValue
        case .protein:
            // При изменении белка пересчитываем остальные макроэлементы
            navigationCoordinator.userProfile.recalculateFromProtein(newProtein: Double(localValue))
            // Обновляем привязанное значение
            value = localValue
        case .carbs:
            // При изменении углеводов пересчитываем остальные макроэлементы
            navigationCoordinator.userProfile.recalculateFromCarbs(newCarbs: Double(localValue))
            // Обновляем привязанное значение
            value = localValue
        case .fats:
            // При изменении жиров пересчитываем остальные макроэлементы
            navigationCoordinator.userProfile.recalculateFromFats(newFats: Double(localValue))
            // Обновляем привязанное значение
            value = localValue
        }
        
        // Отправляем уведомление о том, что значения питания обновились
        NotificationCenter.default.post(
            name: .nutritionValuesUpdated,
            object: nil,
            userInfo: [
                "calories": navigationCoordinator.userProfile.dailyCalories,
                "protein": navigationCoordinator.userProfile.proteinInGrams,
                "carbs": navigationCoordinator.userProfile.carbsInGrams,
                "fats": navigationCoordinator.userProfile.fatsInGrams
            ]
        )
        
        // Вызываем обработчик закрытия, если он есть
        if let onDismiss = onDismiss {
            onDismiss()
        }
    }
}

// Превью
struct NutritionParameterEditView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionParameterEditView(
            parameterType: .calories,
            value: .constant(1700)
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 