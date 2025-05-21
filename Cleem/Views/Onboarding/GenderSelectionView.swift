import SwiftUI
import CoreHaptics

struct GenderSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedGender: UserProfile.Gender? = nil
    @State private var animateItems = false
    @State private var isNavigating = false
    @AppStorage("hasVisitedGenderScreen") private var hasVisitedGenderScreen = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    var body: some View {
        ZStack {
            // Фон экрана - светло-голубой
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад и индикатором прогресса
                HStack(spacing: 0) {
                    // Кнопка назад
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            navigationCoordinator.navigateTo(.welcome)
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
                    .disabled(isNavigating)
                    
                    // Прогресс бар с анимацией из ProgressBarView
                    ProgressBarView(currentStep: 1, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                .padding(.top, 16)
                
                // Заголовок и подзаголовок
                VStack(alignment: .leading, spacing: 0) {
                    // Заголовок - расположен с левой стороны, как на фото 1
                    Text("Choose your Gender")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 32)
                        .padding(.leading, 20)
                    
                    // Подзаголовок - также слева, как на фото 1
                    Text("This will be used to create your individual plan")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.top, 8)
                        .padding(.leading, 20)
                }
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                // Добавляем Spacer перед кнопками, чтобы опустить их ниже
                Spacer()
                
                // Кнопки выбора пола в центре экрана
                VStack(spacing: 16) {
                    genderButton(gender: .male, title: "Male", index: 0)
                    genderButton(gender: .female, title: "Female", index: 1)
                    genderButton(gender: .other, title: "Other", index: 2)
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateItems)
                
                // Добавляем Spacer после кнопок
                Spacer()
                
                // Кнопка Continue - более округлая, как на фото 1
                Button(action: {
                    if isNavigating || selectedGender == nil { return }
                    isNavigating = true
                    
                    // Сохраняем выбранный пол
                    if let gender = selectedGender {
                        navigationCoordinator.userProfile.gender = gender
                        
                        // Сохраняем выбранный пол в UserDefaults для надежности
                        UserDefaults.standard.set(gender.rawValue, forKey: "selectedGender")
                        // Отмечаем, что пользователь уже посетил экран выбора пола
                        hasVisitedGenderScreen = true
                    }
                    
                    // Анимация исчезновения элементов для более гладкого перехода
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                    }
                    
                    // Короткая вибрация без предварительной подготовки
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Небольшая задержка перед переходом для завершения анимации исчезновения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onContinue()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedGender == nil ? Color.gray.opacity(0.5) : Color.black)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                .disabled(isNavigating || selectedGender == nil)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Сбрасываем флаг навигации при появлении экрана
            isNavigating = false
            
            // Проверяем был ли уже выбран пол (возвращаемся с другого экрана)
            if hasVisitedGenderScreen {
                // Проверяем сохраненный выбор в UserDefaults
                if let savedGenderString = UserDefaults.standard.string(forKey: "selectedGender") {
                    // Определяем пол на основе сохраненного значения
                    if savedGenderString == "Male" {
                        selectedGender = .male
                    } else if savedGenderString == "Female" {
                        selectedGender = .female
                    } else if savedGenderString == "Other" {
                        selectedGender = .other
                    }
                } else if navigationCoordinator.userProfile.gender != .other {
                    // Используем значение из профиля пользователя как запасной вариант
                    selectedGender = navigationCoordinator.userProfile.gender
                }
            } else {
                // Если первый визит, не выбираем пол по умолчанию
                selectedGender = nil
            }
            
            // Запускаем анимацию появления элементов с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
    }
    
    // Функция для создания кнопки выбора пола с оптимизированной анимацией
    private func genderButton(gender: UserProfile.Gender, title: String, index: Int) -> some View {
        Button(action: {
            if selectedGender != gender {
                // Используем более легкую вибрацию
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.6)
                
                // Используем более легкую анимацию
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedGender = gender
                }
            }
        }) {
            Text(title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(selectedGender == gender ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedGender == gender ? Color.black : Color.white)
                )
                .animation(.easeOut(duration: 0.2), value: selectedGender)
        }
        .opacity(animateItems ? 1 : 0)
        .offset(y: animateItems ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.4 + min(0.05 * Double(index), 0.15)), value: animateItems)
    }
    
    // Простая вибрация для выбора пола и нажатия кнопки назад
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }
}

// Расширение для перечисления Gender, чтобы добавить .none значение
extension UserProfile.Gender {
    static var none: UserProfile.Gender {
        return .other // Используем .other как значение "none" для совместимости
    }
}

struct GenderSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        GenderSelectionView(onContinue: {}, onBack: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 