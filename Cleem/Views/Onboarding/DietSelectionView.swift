import SwiftUI
import CoreHaptics

struct DietOption: Identifiable {
    let id = UUID()
    let title: String
    let diet: UserProfile.Diet
}

struct DietSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @ObservedObject var userProfile = UserProfile.shared
    @State private var selectedDiet: UserProfile.Diet? = nil // Changed to optional
    @State private var animateItems = false
    @State private var isNavigating = false
    @AppStorage("hasVisitedDietScreen") private var hasVisitedDietScreen = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
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
                    ProgressBarView(currentStep: 7, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                .padding(.top, 16)
                
                // Header with center alignment
                VStack(alignment: .center, spacing: 0) {
                    Text("Do you follow a certain diet?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 28)
                        .multilineTextAlignment(.center)
                    
                    Text("This will be used to create your individual plan")
                        .font(.system(size: 15))
                        .foregroundColor(Color.black.opacity(0.6))
                        .padding(.top, 6)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer()
                    .frame(height: 80)
                
                // Diet options centered on screen
                VStack(spacing: 14) {
                    ForEach(Array(dietOptions.enumerated()), id: \.element.id) { index, option in
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred(intensity: 0.6)
                            
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedDiet = option.diet
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedDiet == option.diet ? Color.black : Color.white)
                                
                                Text(option.title)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(selectedDiet == option.diet ? .white : .black)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .frame(height: 64)
                            .animation(.easeOut(duration: 0.2), value: selectedDiet)
                        }
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 40)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.1), value: animateItems)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if isNavigating || selectedDiet == nil { return }
                    isNavigating = true
                    
                    // Save the selected diet
                    if let diet = selectedDiet {
                        userProfile.diet = diet
                        
                        // Save to UserDefaults
                        UserDefaults.standard.set(diet.rawValue, forKey: "selectedDiet")
                        hasVisitedDietScreen = true
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
                        .background(selectedDiet == nil ? Color.gray.opacity(0.5) : Color.black)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                .disabled(isNavigating || selectedDiet == nil)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            isNavigating = false
            
            // Check if returning to this screen
            if hasVisitedDietScreen {
                // Try to get the saved diet from UserDefaults
                if let savedDietString = UserDefaults.standard.string(forKey: "selectedDiet") {
                    // Convert the string to the diet enum
                    for option in dietOptions {
                        if option.diet.rawValue == savedDietString {
                            selectedDiet = option.diet
                            break
                        }
                    }
                } else if userProfile.diet != .none {
                    // If UserDefaults is empty but profile has a diet, use that
                    selectedDiet = userProfile.diet
                }
            } else {
                // First visit - no default selection
                selectedDiet = nil
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
    }
    
    // Diet options with "No specific diet" moved after "Dukan"
    private var dietOptions: [DietOption] {
        [
            DietOption(title: "Keto", diet: .keto),
            DietOption(title: "Mediterranean", diet: .mediterranean),
            DietOption(title: "Intermittent Fasting", diet: .intermittentFasting),
            DietOption(title: "Dukan", diet: .dukan),
            DietOption(title: "No specific diet", diet: .none)
        ]
    }
}

struct DietSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        DietSelectionView(
            onContinue: {},
            onBack: {}
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 