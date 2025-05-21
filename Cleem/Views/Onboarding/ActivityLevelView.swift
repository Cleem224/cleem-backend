import SwiftUI
import CoreHaptics

struct ActivityOption: Identifiable {
    let title: String
    let description: String
    let level: UserProfile.ActivityLevel
    var id: String { title }
}

struct ActivityLevelView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @ObservedObject var userProfile: UserProfile
    @State private var selectedActivity: UserProfile.ActivityLevel? = nil // Changed to optional
    @State private var animateItems = false
    @State private var isNavigating = false
    @AppStorage("hasVisitedActivityScreen") private var hasVisitedActivityScreen = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    private let activityOptions: [ActivityOption] = [
        ActivityOption(title: "Sedentary", description: "Little to no exercise", level: .sedentary),
        ActivityOption(title: "Lightly active", description: "Light exercise 1-3 days/week", level: .lightlyActive),
        ActivityOption(title: "Moderately active", description: "Moderate exercise 3-5 days/week", level: .moderatelyActive),
        ActivityOption(title: "Active", description: "Hard exercise 6-7 days/week", level: .active),
        ActivityOption(title: "Very active", description: "Very hard exercise & physical job", level: .veryActive)
    ]
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top panel with back button and progress indicator
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
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
                    
                    // Progress indicator
                    ProgressBarView(currentStep: 6, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                .padding(.top, 16)
                
                // Header
                VStack(alignment: .center, spacing: 0) {
                    Text("How active are you?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 28)
                        .multilineTextAlignment(.center)
                    
                    Text("Your activity level helps determine your daily calorie needs")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.6))
                        .padding(.top, 6)
                        .padding(.horizontal, 20)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer()
                    .frame(height: 80)
                
                // Activity level options
                VStack(spacing: 12) {
                    ForEach(Array(activityOptions.enumerated()), id: \.element.id) { index, option in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred(intensity: 0.6)
                            
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedActivity = option.level
                            }
                        }) {
                            VStack(alignment: .center, spacing: 6) {
                                Text(option.title)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(selectedActivity == option.level ? .white : .black)
                                
                                Text(option.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedActivity == option.level ? .white.opacity(0.8) : .black.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 64)
                            .padding(.horizontal, 20)
                            .background(selectedActivity == option.level ? Color.black : Color.white)
                            .cornerRadius(16)
                            .animation(.easeOut(duration: 0.2), value: selectedActivity)
                        }
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.4 + min(0.05 * Double(index), 0.15)), value: animateItems)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if isNavigating || selectedActivity == nil { return }
                    isNavigating = true
                    
                    // Save selected activity
                    if let activity = selectedActivity {
                        userProfile.activityLevel = activity
                        
                        // Save to UserDefaults
                        UserDefaults.standard.set(activity.rawValue, forKey: "selectedActivity")
                        hasVisitedActivityScreen = true
                    }
                    
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                    }
                    
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onContinue()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedActivity == nil ? Color.gray.opacity(0.5) : Color.black)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                .disabled(isNavigating || selectedActivity == nil)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            isNavigating = false
            
            // Check if we're returning to this screen
            if hasVisitedActivityScreen {
                // Try to get the saved activity from UserDefaults
                if let savedActivityString = UserDefaults.standard.string(forKey: "selectedActivity") {
                    // Convert the string to the activity level enum
                    for option in activityOptions {
                        if option.level.rawValue == savedActivityString {
                            selectedActivity = option.level
                            break
                        }
                    }
                } else if userProfile.activityLevel != .sedentary {
                    // Fallback to the profile setting if it's not the default value
                    selectedActivity = userProfile.activityLevel
                }
            } else {
                // First visit - no default selection
                selectedActivity = nil
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
    }
}

struct ActivityLevelView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityLevelView(
            userProfile: UserProfile(),
            onContinue: {},
            onBack: {}
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 