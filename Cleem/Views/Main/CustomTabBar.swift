import SwiftUI
import CoreHaptics
import UIKit

// Расширение для создания цвета из hex-кода
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var engine: CHHapticEngine?
    
    // State for showing the popup menu
    @State private var isShowingAddSheet = false
    @State private var isShowingQuickMenu = false
    
    enum Tab: CaseIterable {
        case home, progress, friends, cleem, chats, profile, settings
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .progress: return "Progress"
            case .friends: return "Friends" 
            case .cleem: return "Cleem"
            case .profile: return "Profile"
            case .chats: return "Chats"
            case .settings: return "Settings"
            }
        }
        
        var imageName: String {
            switch self {
            case .home: return "Home"
            case .progress: return "Progress"
            case .friends: return "Friends"
            case .cleem: return "Cleem"
            case .profile: return "Profile"
            case .chats: return "Chats"
            case .settings: return "Settings"
            }
        }
        
        // Custom size for each icon
        func iconSize(isSelected: Bool) -> CGFloat {
            let baseSize: CGFloat = isSelected ? 30 : 26
            
            switch self {
            case .cleem: return 80 // Larger Cleem icon (увеличено с 70 до 80)
            case .chats: return baseSize + 4 // Larger chat icon
            case .settings: return baseSize - 2 // Smaller settings icon
            default: return baseSize
            }
        }
        
        // Custom text offsets to fine-tune label positions
        var textOffset: CGFloat {
            switch self {
            case .profile, .settings: return 2 // Lower profile and settings text slightly
            default: return 0
            }
        }
        
        // Цвет для иконки Cleem
        var iconColor: Color {
            switch self {
            case .cleem: return Color(hex: "AE956D") // Золотисто-бежевый цвет для Cleem
            default: return .white
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer() // Push tab bar to bottom
            
            // Tab bar background
            ZStack {
                // Blue background panel
                Rectangle()
                    .fill(Color(red: 0, green: 0.27, blue: 0.24))
                    .frame(height: 90)
                    .cornerRadius(25, corners: [.topLeft, .topRight])
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                            .cornerRadius(25, corners: [.topLeft, .topRight])
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: -1)
                    .edgesIgnoringSafeArea(.bottom)
                
                // Tab icons
                HStack(spacing: 0) {
                    // First group: home, progress, friends
                    ForEach([Tab.home, Tab.progress, Tab.friends], id: \.self) { tab in
                        tabButton(for: tab)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8) // Reduced from 15 to move icons higher
                    }
                    
                    // Middle - special Cleem tab
                    tabButton(for: .cleem)
                        .frame(maxWidth: .infinity)
                        .offset(y: -5) // Reduced from -10 to -5 to position Cleem lower
                    
                    // Last group: chats, profile, settings
                    ForEach([Tab.chats, Tab.profile, Tab.settings], id: \.self) { tab in
                        tabButton(for: tab)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8) // Reduced from 15 to move icons higher
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        // Изменяем fullScreenCover на обычный popup, но сохраняем его для использования в HomeView
        .overlay(
            ZStack {
                if isShowingQuickMenu {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            isShowingQuickMenu = false
                        }
                    
                    // Позиционируем меню над кнопкой "+"
                    VStack {
                        Spacer()
                        QuickMenuPopup(isPresented: $isShowingQuickMenu)
                            .environmentObject(navigationCoordinator)
                            .padding(.bottom, 100) // Отступ от нижней части экрана
                    }
                }
            }
        )
        // Keep the original sheet for backward compatibility
        .sheet(isPresented: $isShowingAddSheet) {
            QuickActionsView()
                .environmentObject(navigationCoordinator)
        }
        .onAppear(perform: prepareHaptics)
    }
    
    // Tab button for each icon
    private func tabButton(for tab: Tab) -> some View {
        VStack(spacing: 4) {
            // Icon - Cleem icon stays original, others turn white
            if tab == .cleem {
                Image(tab.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tab.iconSize(isSelected: selectedTab == tab), 
                           height: tab.iconSize(isSelected: selectedTab == tab))
                    .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                    .onTapGesture {
                        // Change tab to Cleem instead of showing popup
                        selectedTab = tab
                        playHapticFeedback()
                    }
            } else {
                Image(tab.imageName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tab.iconSize(isSelected: selectedTab == tab), 
                          height: tab.iconSize(isSelected: selectedTab == tab))
                    .scaleEffect(selectedTab == tab ? 1.05 : 1.0)
                    .onTapGesture {
                        selectedTab = tab
                        playHapticFeedback()
                    }
            }
            
            // Removed text labels completely
        }
        .contentShape(Rectangle())
        // We removed the tap gesture here since it's now handled differently for Cleem icon
        .animation(.spring(response: 0.3), value: selectedTab == tab)
    }
    
    // Haptic feedback functions
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the haptic engine: \(error.localizedDescription)")
        }
    }
    
    private func playHapticFeedback() {
        // Only use simple haptic feedback to avoid double vibration
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// Preview for testing changes
struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        CustomTabBar(selectedTab: .constant(.home))
            .environmentObject(NavigationCoordinator.shared)
    }
} 