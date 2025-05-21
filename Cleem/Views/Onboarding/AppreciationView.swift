import SwiftUI
import CoreHaptics
import Foundation

// Подключаем ProgressBarView

struct AppreciationView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Callback functions
    var onContinue: () -> Void
    var onBack: () -> Void
    
    // Состояния для анимации
    @State private var animateItems = false
    @State private var showPrivacyInfo = false
    @State private var isNavigating = false
    @State private var handshakeCount = 0  // Счетчик для анимации рукопожатия
    
    // Для вибрации
    @State private var engine: CHHapticEngine?
    
    var body: some View {
        ZStack {
            // Светло-голубой фон
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад и индикатором прогресса
                HStack(spacing: 0) {
                    // Кнопка "Назад"
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        // Вибрация при нажатии
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Анимация исчезновения и переход назад
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onBack()
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
                    
                    // Индикатор прогресса
                    ProgressBarView(currentStep: 8, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                // Добавляем дополнительное пространство сверху
                Spacer().frame(height: 40)
                
                // Основное содержимое с анимацией движения
                VStack(spacing: 0) {
                    // Секция благодарности (всегда видима)
                    VStack(spacing: 24) {
                        // Иконка рукопожатия из Assets с анимацией
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.92, green: 0.94, blue: 0.99))
                                .frame(width: 160, height: 160)
                            
                            Image("Appreciation") // Изображение рукопожатия
                                .resizable()
                                .scaledToFit()
                                .frame(width: 85, height: 85)
                                .rotationEffect(Angle(degrees: handshakeCount % 2 == 0 ? -5 : 5))
                                .scaleEffect(handshakeCount % 2 == 0 ? 0.95 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: handshakeCount)
                        }
                        .opacity(animateItems ? 1 : 0)
                        .scaleEffect(animateItems ? 1 : 0.8)
                        
                        // Основной текст благодарности
                        Text("Thank you for trusting us")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .opacity(animateItems ? 1 : 0)
                        
                        Text("it means a lot to our team")
                            .font(.system(size: 20, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.black.opacity(0.7))
                            .padding(.horizontal, 20)
                            .opacity(animateItems ? 1 : 0)
                    }
                    .offset(y: showPrivacyInfo ? -30 : 0) // Небольшое смещение вверх при появлении приватности
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showPrivacyInfo)
                    
                    Spacer()
                        .frame(height: showPrivacyInfo ? 30 : 180) // Уменьшаем высоту спейсера
                    
                    // Секция приватности (появляется с анимацией)
                    if showPrivacyInfo {
                        VStack(spacing: 24) {
                            // Иконка приватности
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.92, green: 0.94, blue: 0.99))
                                    .frame(width: 180, height: 180)
                                
                                ZStack {
                                    Image(systemName: "shield.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.8))
                                    
                                    Image(systemName: "lock.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.white)
                                        .offset(y: -3)
                                }
                            }
                            .opacity(showPrivacyInfo ? 1 : 0)
                            .scaleEffect(showPrivacyInfo ? 1 : 0.8)
                            .padding(.top, -10) // Немного поднимаем иконку вверх
                            
                            // Заголовок приватности
                            Text("Privacy is our priority")
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .opacity(showPrivacyInfo ? 1 : 0)
                            
                            // Описание приватности
                            Text("All your conversations\nare secure, private and\nnot shared with anyone")
                                .font(.system(size: 18, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .foregroundColor(Color.black.opacity(0.7))
                                .padding(.horizontal, 30)
                                .opacity(showPrivacyInfo ? 1 : 0)
                        }
                        .transition(.opacity)
                        .animation(.easeIn(duration: 0.5), value: showPrivacyInfo)
                        .padding(.top, -10) // Добавляем отрицательный отступ всей секции
                    }
                }
                
                Spacer()
                
                // Кнопка продолжить
                Button(action: {
                    if isNavigating { return } // Предотвращаем повторные нажатия
                    isNavigating = true
                    
                    // Короткая вибрация
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Анимация исчезновения элементов
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                        showPrivacyInfo = false
                    }
                    
                    // Небольшая задержка перед переходом
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onContinue()
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
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                .disabled(isNavigating)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Сбрасываем флаг навигации
            isNavigating = false
            
            // Анимация появления элементов
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateItems = true
                }
            }
            
            // Запускаем анимацию рукопожатия
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startHandshakeAnimation()
            }
            
            // Через 2 секунды показываем информацию о конфиденциальности с гладкой анимацией
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Вибрация при появлении информации о конфиденциальности
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                generator.impactOccurred(intensity: 0.7)
                
                // Анимация с пружинным эффектом для большей живости
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showPrivacyInfo = true
                }
            }
            
            // Подготавливаем haptic engine
            prepareHaptics()
        }
        .onDisappear {
            // Остановка engine при исчезновении экрана
            engine?.stop()
        }
    }
    
    // Метод для анимации рукопожатия
    private func startHandshakeAnimation() {
        // Имитируем движение рукопожатия 4 раза
        for i in 1...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(i)) {
                handshakeCount += 1
                
                // Добавляем тактильную обратную связь при каждом "пожатии"
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.4)
            }
        }
    }
    
    // Подготовка haptic engine
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
}

struct AppreciationView_Previews: PreviewProvider {
    static var previews: some View {
        AppreciationView(
            onContinue: {},
            onBack: {}
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 