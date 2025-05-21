import SwiftUI
import CoreHaptics

struct HeightWeightSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.presentationMode) var presentationMode
    @State private var height: Double = 170.0  // Default height in cm
    @State private var weight: Double = 70.0   // Default weight in kg
    @State private var animateItems = false
    @State private var hapticEngine: CHHapticEngine?
    @State private var isNavigating = false // Флаг для предотвращения повторных нажатий
    
    // Добавляем колбэки для навигации
    var onContinue: (() -> Void)?
    var onBack: (() -> Void)?
    
    // Метрики пользователя
    private var bmi: Double {
        let heightInMeters = height / 100.0
        return weight / (heightInMeters * heightInMeters)
    }
    
    // Оптимизируем массивы значений - ограничиваем диапазон для более легкой загрузки
    private let heightValues: [Int] = Array(100...250) // Более реалистичный диапазон для роста
    private let weightValues: [Int] = Array(30...250)  // Более реалистичный диапазон для веса
    
    var body: some View {
        ZStack {
            // Фон экрана - светло-голубой
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад и индикатором прогресса
                HStack(spacing: 0) {
                    // Кнопка "Назад" - стандартная серая как на предыдущих экранах
                    Button(action: {
                        if isNavigating { return } // Предотвращаем повторные нажатия
                        isNavigating = true
                        
                        // Сохраняем данные перед переходом
                        saveData()
                        
                        // Отключаем анимации элементов для более гладкого перехода
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        // Короткая вибрация без предварительной подготовки
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Небольшая задержка перед переходом для завершения анимации исчезновения
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            // Используем прямую навигацию вместо колбэка
                            navigationCoordinator.navigateTo(.ageSelection)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .scaleEffect(animateItems ? 1.0 : 0.1)
                                .opacity(animateItems ? 1.0 : 0)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .medium))
                                .opacity(animateItems ? 1.0 : 0)
                                .scaleEffect(animateItems ? 1.0 : 0.5)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: animateItems)
                    }
                    .padding(.leading, 20)
                    .disabled(isNavigating) // Блокируем кнопку во время перехода
                    
                    // Стандартный индикатор прогресса (ProgressBarView)
                    ProgressBarView(currentStep: 3, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                }
                .padding(.top, 16)
                
                // Заголовок и подзаголовок - центрированные по горизонтали с уменьшенным шрифтом
                VStack(alignment: .center, spacing: 0) {
                    Text("Height & Weight")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 32)
                        .multilineTextAlignment(.center)
                    
                    Text("This helps to calculate your energy and calorie needs")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                // Пространство перед компонентом - гибкое, чтобы выровнять по центру
                Spacer()
                
                // Wheel Picker для роста и веса - центрирован по экрану
                ZStack {
                    // Белый фон
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    
                    // Контейнер с двумя пикерами
                    HStack(spacing: 0) {
                        // Height Picker
                        VStack {
                            Text("Height")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.bottom, 5)
                                
                            // Wheel Picker для роста - оптимизированный
                            Picker("Height", selection: $height) {
                                ForEach(heightValues, id: \.self) { value in
                                    Text("\(value) cm")
                                        .font(.system(size: 20, weight: .medium))
                                        .tag(Double(value))
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 150)
                            .clipped()
                            .onChange(of: height) { _, _ in
                                // Используем более легкую вибрацию
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred(intensity: 0.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Вертикальный разделитель
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1, height: 150)
                        
                        // Weight Picker
                        VStack {
                            Text("Weight")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.bottom, 5)
                                
                            // Wheel Picker для веса - оптимизированный
                            Picker("Weight", selection: $weight) {
                                ForEach(weightValues, id: \.self) { value in
                                    Text("\(value) kg")
                                        .font(.system(size: 20, weight: .medium))
                                        .tag(Double(value))
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 150)
                            .clipped()
                            .onChange(of: weight) { _, _ in
                                // Используем более легкую вибрацию
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred(intensity: 0.5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 10)
                }
                .frame(height: 190)
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                
                // Такой же Spacer после компонента для центрирования по вертикали
                Spacer()
                
                // Кнопка "Продолжить"
                Button(action: {
                    if isNavigating { return } // Предотвращаем повторные нажатия
                    isNavigating = true
                    
                    // Сохраняем данные перед переходом
                    saveData()
                    
                    // Отключаем анимации элементов для более гладкого перехода
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                    }
                    
                    // Короткая вибрация без предварительной подготовки
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Небольшая задержка перед переходом для завершения анимации исчезновения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        // Используем прямую навигацию вместо колбэка
                        navigationCoordinator.navigateTo(.goalSelection)
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                .disabled(isNavigating) // Блокируем кнопку во время перехода
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Сбрасываем флаг навигации при появлении экрана
            isNavigating = false
            
            // Инициализируем значения из профиля пользователя
            initializeValues()
            
            // Запускаем анимацию появления элементов с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
    }
    
    // Выносим инициализацию значений в отдельный метод для оптимизации
    private func initializeValues() {
        // Initialize with the current user profile data if available
        if navigationCoordinator.userProfile.heightInCm > 0 {
            height = Double(navigationCoordinator.userProfile.heightInCm)
        }
        
        if navigationCoordinator.userProfile.weightInKg > 0 {
            weight = navigationCoordinator.userProfile.weightInKg
        }
    }
    
    // Выносим сохранение данных в отдельный метод
    private func saveData() {
        // Сохраняем данные в профиле пользователя
        navigationCoordinator.userProfile.heightInCm = Int(height)
        navigationCoordinator.userProfile.weightInKg = weight
        navigationCoordinator.userProfile.bmi = bmi
    }
    
    // Функция для создания тактильной обратной связи (вибрации)
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.7)
    }
}

struct HeightWeightSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HeightWeightSelectionView(
                onContinue: {},
                onBack: {}
            )
            .environmentObject(NavigationCoordinator.shared)
        }
    }
} 