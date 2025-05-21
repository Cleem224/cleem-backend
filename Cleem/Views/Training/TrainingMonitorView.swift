import SwiftUI

struct TrainingMonitorView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var healthManager: HealthKitManager
    @Binding var isPresented: Bool
    @State private var selectedTraining: TrainingType?
    
    enum TrainingType: String, Identifiable {
        case run = "Run"
        case strength = "Strength training"
        case manual = "Manual"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .run:
                return "Running, sprinting, jogging, etc."
            case .strength:
                return "Exercise equipment, free weight, etc."
            case .manual:
                return "Enter calories burned manually"
            }
        }
        
        var iconName: String {
            switch self {
            case .run:
                return "figure.run"
            case .strength:
                return "dumbbell.fill"
            case .manual:
                return "pencil"
            }
        }
    }
    
    var body: some View {
        // Убираем основной ZStack и фоновое затемнение
        VStack(spacing: 0) {
            // Заголовок с кнопкой закрытия
            HStack {
                // Кнопка X для закрытия
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Circle().fill(Color.gray.opacity(0.2)))
                }
                
                Spacer()
                
                // Заголовок сдвинут вправо
                Text("Monitor training")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.trailing, 35)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            .padding(.bottom, 25)
            
            // Опции тренировок
            VStack(spacing: 15) {
                TrainingOptionView(
                    trainingType: .run,
                    isSelected: selectedTraining == .run,
                    action: { selectTraining(.run) }
                )
                
                TrainingOptionView(
                    trainingType: .strength,
                    isSelected: selectedTraining == .strength,
                    action: { selectTraining(.strength) }
                )
                
                TrainingOptionView(
                    trainingType: .manual,
                    isSelected: selectedTraining == .manual,
                    action: { selectTraining(.manual) }
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Навигационные ссылки для перехода на экраны тренировок
            NavigationLink(
                destination: RunTrainingView(isPresented: $isPresented)
                    .environmentObject(navigationCoordinator)
                    .environmentObject(healthManager),
                isActive: Binding<Bool>(
                    get: { selectedTraining == .run },
                    set: { if !$0 { selectedTraining = nil } }
                ),
                label: { EmptyView() }
            )
            
            NavigationLink(
                destination: StrengthTrainingView(isPresented: $isPresented)
                    .environmentObject(navigationCoordinator)
                    .environmentObject(healthManager),
                isActive: Binding<Bool>(
                    get: { selectedTraining == .strength },
                    set: { if !$0 { selectedTraining = nil } }
                ),
                label: { EmptyView() }
            )
            
            NavigationLink(
                destination: ManualCaloriesEntryView(isPresented: $isPresented)
                    .environmentObject(navigationCoordinator)
                    .environmentObject(healthManager),
                isActive: Binding<Bool>(
                    get: { selectedTraining == .manual },
                    set: { if !$0 { selectedTraining = nil } }
                ),
                label: { EmptyView() }
            )
        }
        .padding(.bottom, 20)
        .navigationBarHidden(true) // Сохраняем скрытие панели навигации
    }
    
    func selectTraining(_ type: TrainingType) {
        withAnimation {
            selectedTraining = type
        }
    }
}

struct TrainingOptionView: View {
    let trainingType: TrainingMonitorView.TrainingType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // Icon
                Image(systemName: trainingType.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                
                // Text content
                VStack(alignment: .leading, spacing: 3) {
                    Text(trainingType.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(trainingType.description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(15)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// Preview
struct TrainingMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        TrainingMonitorView(isPresented: .constant(true))
            .environmentObject(NavigationCoordinator.shared)
            .environmentObject(HealthKitManager.shared)
    }
} 