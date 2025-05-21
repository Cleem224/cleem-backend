import SwiftUI
import HealthKit
import Combine

struct StepsPanel: View {
    @ObservedObject private var healthManager = HealthKitManager.shared
    @ObservedObject private var userProfile = UserProfile.shared
    @State private var isRequestingAuthorization = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var refreshTrigger = UUID()
    
    // Для отслеживания времени последней проверки авторизации
    @State private var lastAuthCheckTime: Date = Date(timeIntervalSince1970: 0)
    // Минимальный интервал между проверками (1 минута)
    private let minAuthCheckInterval: TimeInterval = 60
    
    // Computed property for the step count
    var stepCount: Int {
        return healthManager.isAuthorized ? healthManager.steps : 0
    }
    
    // Computed property for the calories burned
    var caloriesBurned: Int {
        if healthManager.isAuthorized {
            return Int(healthManager.caloriesBurned)
        } else {
            // Return 0 calories if not connected
            return 0
        }
    }
    
    // Computed property for the daily goal
    var dailyGoal: Double {
        return 10000.0
    }
    
    // Computed property for the progress
    var progress: Double {
        return min(Double(stepCount) / dailyGoal, 1.0)
    }
    
    var body: some View {
        Group {
            if !healthManager.isAuthorized {
                // Not connected view - Show heart and Connect+ button
                notConnectedView
            } else {
                // Connected view - Show step count
                connectedView
            }
        }
        .animation(.easeInOut, value: healthManager.isAuthorized)
        .id("steps-panel-\(healthManager.isAuthorized)-\(refreshTrigger)")
        .onAppear {
            // Log the current authorization status
            print("StepsPanel appeared, HealthKit authorized: \(healthManager.isAuthorized)")
            
            // Always check authorization status on appear, with a slight delay
            // to ensure the UI is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkHealthKitStatus()
            }
        }
        .onChange(of: healthManager.isAuthorized) { newValue in
            print("HealthKit authorization changed: \(newValue)")
            refreshTrigger = UUID() // Force UI refresh
        }
    }
    
    private func checkHealthKitStatus() {
        print("Refreshing StepsPanel UI based on current HealthKit status")
        
        // Просто обновляем UI, не делая дополнительных запросов к HealthKit
        refreshTrigger = UUID()
        
        // Если авторизован, убедимся, что данные начали загружаться
        if healthManager.isAuthorized {
            // Этот вызов теперь безопасен, так как внутри него стоит проверка на одноразовость
            healthManager.startFetchingHealthData()
        }
    }
    
    // Not connected view with heart icon and Connect+ button
    private var notConnectedView: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Progress circle with heart icon
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // White background for icon
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Heart icon with gradient
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.pink, Color.red]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 8)
            .padding(.top, 16)
            
            // Connect button
            Button(action: {
                print("Connect+ button tapped")
                // Добавляем одинарную вибрацию при нажатии
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                requestHealthKitAuthorization()
            }) {
                Text("Connect+")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0, green: 0.27, blue: 0.24))
                    .cornerRadius(30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .disabled(isRequestingAuthorization)
            .opacity(isRequestingAuthorization ? 0.7 : 1.0)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(UIColor.systemGray4))
        .cornerRadius(20)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("HealthKit Access"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Connected view showing step count and progress
    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(stepCount)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
            
            Text("/10,000")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
            
            Text("Steps today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .padding(.top, 2)
            
            // Step progress circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                
                // Progress arc (hidden as there are no steps)
                // Will show progress when steps > 0
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.black, lineWidth: 6)
                    .rotationEffect(Angle(degrees: -90))
                
                // Walking figure
                Image(systemName: "figure.walk")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.black)
            }
            .frame(width: 60, height: 60)
            .padding(.top, 10)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .onAppear {
            // Refresh health data when connected view appears
            if healthManager.isAuthorized {
                healthManager.startFetchingHealthData()
            }
        }
    }
    
    // Request authorization for HealthKit
    private func requestHealthKitAuthorization() {
        isRequestingAuthorization = true
        print("Requesting HealthKit authorization")
        
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            alertMessage = "HealthKit is not available on this device."
            showAlert = true
            isRequestingAuthorization = false
            print("HealthKit is not available on this device")
            return
        }
        
        // Request authorization
        healthManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                self.isRequestingAuthorization = false
                
                if success {
                    print("HealthKit authorization successful")
                    
                    // Wait a moment for the system to properly register the authorization
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Force refresh of authorization status
                        self.healthManager.forceCheckAuthorization()
                        
                        // Force a UI refresh
                        self.refreshTrigger = UUID()
                        
                        // Start fetching data immediately
                        self.healthManager.startFetchingHealthData()
                        
                        // Add additional refresh after more time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.refreshTrigger = UUID()
                        }
                    }
                } else {
                    if let error = error {
                        print("HealthKit authorization failed: \(error.localizedDescription)")
                        self.alertMessage = "Failed to get permission: \(error.localizedDescription)"
                    } else {
                        print("HealthKit authorization denied by user")
                        self.alertMessage = "Permission denied. Please enable Health access in Settings."
                    }
                    self.showAlert = true
                }
            }
        }
    }
}

struct StepsPanel_Previews: PreviewProvider {
    static var previews: some View {
        StepsPanel()
            .frame(width: 300, height: 400)
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 