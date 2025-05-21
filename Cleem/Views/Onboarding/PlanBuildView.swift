import SwiftUI
import CoreHaptics

struct PlanBuildView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Callback functions
    var onContinue: () -> Void
    var onBack: () -> Void
    
    // Состояния для анимации
    @State private var animateItems = false
    @State private var isNavigating = false
    @State private var heartScale = 1.0
    @State private var heartRotation = 0.0
    @State private var glowOpacity = 0.0
    @State private var heartAppeared = false
    
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
                
                Spacer()
                
                // Изображение из Board.imageset - еще больший размер
                ZStack {
                    // Светящийся эффект
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 320, height: 320)
                        .opacity(glowOpacity)
                    
                    Circle()
                        .fill(Color(red: 0.91, green: 0.97, blue: 1.0)) // Цвет фона приложения
                        .frame(width: 280, height: 280)
                    
                    // Эффект яркого блика
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.7), Color.white.opacity(0)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 280, height: 280)
                        .opacity(heartScale > 1.0 ? 0.5 : 0.2)
                        .blur(radius: 10)
                    
                    Image("Board")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280) // Заполняет весь круг
                        .scaleEffect(heartScale)
                        .rotationEffect(Angle(degrees: heartRotation))
                }
                .opacity(animateItems ? 1 : 0)
                .scaleEffect(animateItems ? 1 : 0.8)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateItems)
                .padding(.bottom, 20)
                
                // Зеленая галочка "Welcome aboard!" - перемещена под изображение
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Welcome aboard!")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                .opacity(heartAppeared ? 1 : 0)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                .padding(.bottom, 20)
                
                // Заголовок
                Text("Time to build your\nunique plan!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .padding(.horizontal, 40)
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                
                Spacer()
                
                // Кнопка продолжить - стандартный стиль как на других экранах
                Button(action: {
                    if isNavigating { return } // Предотвращаем повторные нажатия
                    isNavigating = true
                    
                    // Короткая вибрация
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Анимация исчезновения элементов
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
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
                .animation(.easeOut(duration: 0.5).delay(0.7), value: animateItems)
                .disabled(isNavigating)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Сбрасываем флаг навигации
            isNavigating = false
            heartAppeared = false
            
            // Анимация появления элементов
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateItems = true
                }
            }
            
            // Запускаем анимацию сердца с руками
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                startHeartAnimation()
            }
            
            // Подготавливаем haptic engine
            prepareHaptics()
        }
        .onDisappear {
            // Для очистки ресурсов при исчезновении экрана
            engine?.stop()
        }
    }
    
    // Функция для анимации сердца
    private func startHeartAnimation() {
        // Сначала появление сердца с небольшим увеличением
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            heartScale = 1.1
        }
        
        // Через небольшую задержку - эффектный поворот сердца с руками
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Вибрация для ощущения движения
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred(intensity: 0.7)
            
            // Поворот в одну сторону
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                heartRotation = 8.0
            }
            
            // Затем в другую с более интенсивной вибрацией
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred(intensity: 0.8)
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    heartRotation = -8.0
                }
                
                // И наконец возвращаем в нормальное положение с легким увеличением
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.5)
                    
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                        heartRotation = 0.0
                        heartScale = 1.15
                        // Добавляем свечение
                        glowOpacity = 0.7
                    }
                    
                    // Финальное уменьшение до нормального размера и мягкое свечение
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            heartScale = 1.0
                            glowOpacity = 0.3
                        }
                        
                        // Показываем галочку "Welcome aboard!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                heartAppeared = true
                            }
                            
                            // Финальная вибрация для ощущения завершенности
                            let generator = UIImpactFeedbackGenerator(style: .soft)
                            generator.impactOccurred(intensity: 0.4)
                        }
                    }
                }
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

struct PlanBuildView_Previews: PreviewProvider {
    static var previews: some View {
        PlanBuildView(
            onContinue: {},
            onBack: {}
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 