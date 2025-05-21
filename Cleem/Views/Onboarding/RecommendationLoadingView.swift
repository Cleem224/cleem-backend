import SwiftUI
import CoreHaptics

// Структура для более плавной анимации текста статуса
struct AnimatedStatusText: View {
    let text: String
    @State private var isVisible = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 20))
            .foregroundColor(.black)
            .opacity(isVisible ? 1 : 0)
            .id(text) // Добавляем уникальный id для обновления View при смене текста
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .top))
            ))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4)) {
                    isVisible = true
                }
            }
    }
}

struct RecommendationLoadingView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var progress: Double = 0.0
    @State private var dotsCount = 0
    @State private var engine: CHHapticEngine?
    @State private var showCheckmarks = [false, false, false, false]
    @State private var statusText = "Personalizing health plan"
    @Environment(\.presentationMode) var presentationMode
    
    // Анимация элементов
    @State private var animateItems = false
    @State private var isNavigating = false // Защита от множественных нажатий
    
    // Callback functions
    var onComplete: (() -> Void)?
    var onBackToDietSelection: (() -> Void)?
    
    // Timer for progress animation - 6 seconds to 100%
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    // Timer for dots animation
    let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    init(onComplete: (() -> Void)? = nil, onBackToDietSelection: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBackToDietSelection = onBackToDietSelection
    }
    
    var body: some View {
        ZStack {
            // Light blue background
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header
                Text("Building recommendations\nbased on the data provided")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 100)
                    .padding(.horizontal, 20)
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: animateItems)
                
                Spacer()
                    .frame(height: 80)
                
                // Progress ring with percentage in center
                ZStack {
                    // Background circle (white with opacity)
                    Circle()
                        .stroke(Color.white, lineWidth: 10)
                        .opacity(0.2)
                        .frame(width: 200, height: 200)
                    
                    // Gradient progress circle
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.0, green: 0.7, blue: 1.0),   // яркий голубой
                                    Color(red: 0.2, green: 0.5, blue: 0.95),  // синий
                                    Color(red: 0.5, green: 0.2, blue: 0.9)    // фиолетовый
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear(duration: 0.1), value: progress)
                        .frame(width: 200, height: 200)
                    
                    // Percentage in center with gradient
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.0, green: 0.7, blue: 1.0),   // яркий голубой
                                    Color(red: 0.2, green: 0.5, blue: 0.95),  // синий
                                    Color(red: 0.5, green: 0.2, blue: 0.9)    // фиолетовый
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .opacity(animateItems ? 1 : 0)
                .scaleEffect(animateItems ? 1 : 0.8)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer()
                    .frame(height: 30)
                
                // Status text with dots animation - разделяем текст и точки
                HStack(spacing: 0) {
                    // Статический текст
                    AnimatedStatusText(text: statusText)
                    
                    // Отдельно анимированные точки
                    Text(self.progress >= 0.99 ? "." : String(repeating: ".", count: dotsCount))
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.4), value: animateItems)
                        .id("dots\(dotsCount)") // Для более гладкой анимации смены точек
                }
                .animation(.none, value: statusText) // Отключаем анимацию HStack при смене текста
                .frame(height: 30) // Фиксированная высота для предотвращения смещения
                
                Spacer()
                    .frame(height: 70)
                
                // White card with recommendations
                VStack(spacing: 16) {
                    Text("Recommendation for")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 24)
                    
                    VStack(spacing: 16) {
                        RecommendationRow(text: "Calories", isComplete: showCheckmarks[0])
                        
                        RecommendationRow(text: "Protein", isComplete: showCheckmarks[1])
                        
                        RecommendationRow(text: "Carbs", isComplete: showCheckmarks[2])
                        
                        RecommendationRow(text: "Fats", isComplete: showCheckmarks[3])
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 16)
                }
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 30)
                .frame(maxWidth: 400)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Сбрасываем флаг навигации при появлении экрана
            isNavigating = false
            
            prepareHaptics()
            
            // Запускаем анимацию появления элементов с более короткой длительностью
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
            
            // Calculate user metrics when screen loads
            let _ = navigationCoordinator.userProfile.calculateDailyTargets()
        }
        .onReceive(timer) { _ in
            // Increase progress to reach 100% in 6 seconds
            if progress < 1.0 {
                progress += 0.00333 // 0.00333 * 0.05s * 6000 = 1.0 (100% in 6 seconds)
                
                // Calculate calories when progress reaches 25%
                if progress >= 0.25 && !showCheckmarks[0] {
                    showCheckmarks[0] = true
                    // Calculate daily calories
                    let _ = navigationCoordinator.userProfile.calculateDailyCalories()
                    // Более легкая вибрация
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.7)
                    
                    // Смена текста на второй этап с более плавной анимацией
                    withAnimation(.easeInOut(duration: 0.4)) {
                        statusText = "Applying BMR formula"
                    }
                }
                
                // Calculate protein when progress reaches 50%
                if progress >= 0.5 && !showCheckmarks[1] {
                    showCheckmarks[1] = true
                    // Calculate protein target
                    let _ = navigationCoordinator.userProfile.calculateProteinTarget()
                    // Более легкая вибрация
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.7)
                    
                    // Смена текста на третий этап с более плавной анимацией
                    withAnimation(.easeInOut(duration: 0.4)) {
                        statusText = "Calculating your metabolic age"
                    }
                }
                
                // Calculate carbs when progress reaches 75%
                if progress >= 0.75 && !showCheckmarks[2] {
                    showCheckmarks[2] = true
                    // Calculate carbs target
                    let _ = navigationCoordinator.userProfile.calculateCarbsTarget()
                    // Более легкая вибрация
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.7)
                    
                    // Смена текста на финальный этап с более плавной анимацией
                    withAnimation(.easeInOut(duration: 0.4)) {
                        statusText = "Processing final results"
                    }
                }
                
                // Calculate fats when progress reaches 99%
                if progress >= 0.99 && !showCheckmarks[3] {
                    if isNavigating { return } // Предотвращаем повторные переходы
                    isNavigating = true
                    
                    showCheckmarks[3] = true
                    // Calculate fats target
                    let _ = navigationCoordinator.userProfile.calculateFatsTarget()
                    
                    // Final calculation for all values
                    let _ = navigationCoordinator.userProfile.calculateDailyTargets()
                    
                    // Вибрация завершения с более низкой интенсивностью
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    // Анимация исчезновения элементов для более гладкого перехода
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                    }
                    
                    // Navigate to results screen after 1 second (with additional buffer for animation)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        // Call provided callback for additional actions
                        onComplete?()
                        
                        // Programmatically navigate to summary screen
                        navigationCoordinator.navigateTo(.summary)
                    }
                }
            }
        }
        .onReceive(dotsTimer) { _ in
            dotsCount = (dotsCount + 1) % 4
        }
    }
    
    // Method to prepare haptic feedback
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
    
    // Method to play haptic feedback on successful completion
    private func complexSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else { return }
        
        var events = [CHHapticEvent]()
        
        // Используем меньшую интенсивность для снижения нагрузки на устройство
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
        
        let start = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(start)
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }
}

// Recommendation row component with checkmark
struct RecommendationRow: View {
    let text: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Black bullet point
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
            
            // Recommendation text
            Text(text)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            // Checkmark (if needed)
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isComplete)
            }
        }
        .padding(.horizontal, 24)
    }
}

struct RecommendationLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationLoadingView()
            .environmentObject(NavigationCoordinator.shared)
    }
} 