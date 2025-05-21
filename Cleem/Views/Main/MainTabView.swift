import SwiftUI

struct MainTabView: View {
    @ObservedObject var navigationCoordinator = NavigationCoordinator.shared
    @State private var selectedTab: CustomTabBar.Tab = .home
    
    // Явно определенная привязка
    private var foodSearchBinding: Binding<Bool> {
        Binding<Bool>(
            get: { self.navigationCoordinator.isShowingFoodSearch },
            set: { self.navigationCoordinator.isShowingFoodSearch = $0 }
        )
    }
    
    var body: some View {
        contentBody
    }
    
    private var contentBody: some View {
        var mainContent: some View {
            // Main content
            ZStack {
                if selectedTab == .home {
                    HomeView()
                        .environmentObject(navigationCoordinator)
                } else if selectedTab == .progress {
                    NutritionProgressView()
                        .environmentObject(navigationCoordinator)
                } else if selectedTab == .cleem {
                    ScanPlaceholderView()
                        .environmentObject(navigationCoordinator)
                } else if selectedTab == .friends {
                    Text("Friends View")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.gray)
                } else if selectedTab == .profile {
                    ProfileView(coordinator: navigationCoordinator)
                } else if selectedTab == .chats {
                    Text("Chats View")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.gray)
                } else if selectedTab == .settings {
                    Text("Settings View")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.gray)
                }
            }
            .background(Color.appBackground)
        }
        
        var tabBar: some View {
            CustomTabBar(selectedTab: $selectedTab)
        }
        
        var modalContent: some View {
            modalOverlayContent
        }
        
        return ZStack {
            // Main content shows only when not in onboarding
            if !navigationCoordinator.isOnboarding {
                VStack(spacing: 0) {
                    mainContent
                }
            }
            
            // Food search modal
            if navigationCoordinator.isShowingFoodSearch {
                foodSearchOverlay
            }
            
            // Tab bar shows only when not in onboarding
            if !navigationCoordinator.isOnboarding {
                tabBar
            }
            
            // Modal content (including onboarding screens)
            modalContent
        }
        .preferredColorScheme(.light) // Force light theme
        .fullScreenCover(isPresented: $navigationCoordinator.showScanCamera) {
            if navigationCoordinator.shouldUseNewScanCameraView {
                ScanCameraViewV2()
                    .environmentObject(navigationCoordinator)
            } else {
                ScanCameraView()
                    .environmentObject(navigationCoordinator)
            }
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showBarcodeScannerView) {
            BarcodeScannerView(
                isPresented: $navigationCoordinator.showBarcodeScannerView,
                onBarcodeScan: { barcode in
                    // Handle barcode scanning result
                    print("Scanned barcode: \(barcode)")
                    // Process barcode and show food details
                },
                onClose: {
                    navigationCoordinator.showBarcodeScannerView = false
                }
            )
            .environmentObject(navigationCoordinator)
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showFoodLabelView) {
            FoodLabelScannerView()
                .environmentObject(navigationCoordinator)
        }
        .fullScreenCover(isPresented: $navigationCoordinator.showImagePicker) {
            ImagePickerView(
                isPresented: $navigationCoordinator.showImagePicker,
                onImagePicked: { image in
                    // Handle selected image
                    navigationCoordinator.foodAnalysisImage = image
                    // Process the image for food analysis
                }
            )
            .environmentObject(navigationCoordinator)
        }
    }
    
    // MARK: - Вспомогательные методы для упрощения кода
    
    // Метод для отображения модального окна поиска еды
    private var foodSearchOverlay: some View {
        ZStack {
            // Затемненный фон
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    navigationCoordinator.isShowingFoodSearch = false
                }
            
            // Содержимое модального окна
            FoodSearchView(
                mealType: navigationCoordinator.currentMealType,
                onFoodSelected: { foodItem, nutrition in
                    // Ensure the foodItem has a non-nil servingUnit
                    let sanitizedFoodItem = FoodItem(
                        id: foodItem.id,
                        name: foodItem.name,
                        category: foodItem.category,
                        servingSize: foodItem.servingSize,
                        servingUnit: foodItem.servingUnit ?? "g",  // Default to "g" if nil
                        description: foodItem.description,
                        image: foodItem.image
                    )
                    
                    // Handle adding the food to log
                    let mealType = navigationCoordinator.currentMealType.isEmpty ? "Snacks" : navigationCoordinator.currentMealType
                    // TODO: Save food to food log
                    print("Added \(sanitizedFoodItem.name) to \(mealType)")
                    
                    // Close the view when done
                    navigationCoordinator.isShowingFoodSearch = false
                }
            )
            .environmentObject(navigationCoordinator)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
        }
        .transition(.opacity)
        .zIndex(100) // Убедимся, что модальное окно отображается поверх всего
    }
    
    // Метод для отображения экранов из NavigationCoordinator.activeScreen
    private var modalOverlayContent: some View {
        Group {
            if navigationCoordinator.activeScreen == nil {
                EmptyView()
            } else if case .profileSetup = navigationCoordinator.activeScreen {
                ProfileSetupView(isFirstLaunch: false)
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case let .foodDetails(foodItem) = navigationCoordinator.activeScreen {
                FoodDetailsView(foodItem: foodItem)
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case let .nutritionDetails(foodItem) = navigationCoordinator.activeScreen,
                    let nutrition = navigationCoordinator.foodNutrition {
                NutritionDetailsView(foodItem: foodItem, nutrition: nutrition)
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case let .combinedFoodDetails(combinedFood) = navigationCoordinator.activeScreen {
                CombinedFoodDetailsView(combinedFood: combinedFood)
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case .welcome = navigationCoordinator.activeScreen {
                WelcomeView(
                    onContinue: { navigationCoordinator.navigateTo(.genderSelection) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .genderSelection = navigationCoordinator.activeScreen {
                GenderSelectionView(
                    onContinue: { navigationCoordinator.navigateTo(.ageSelection) },
                    onBack: { navigationCoordinator.navigateTo(.welcome) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .ageSelection = navigationCoordinator.activeScreen {
                DateOfBirthView(
                    onContinue: { navigationCoordinator.navigateTo(.heightWeightSelection) },
                    onBack: { navigationCoordinator.navigateTo(.genderSelection) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .heightWeightSelection = navigationCoordinator.activeScreen {
                HeightWeightSelectionView(
                    onContinue: { navigationCoordinator.navigateTo(.goalSelection) },
                    onBack: { navigationCoordinator.navigateTo(.ageSelection) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .goalSelection = navigationCoordinator.activeScreen {
                GoalSelectionView(
                    onContinue: { navigationCoordinator.navigateTo(.targetWeight) },
                    onBack: { navigationCoordinator.navigateTo(.heightWeightSelection) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .targetWeight = navigationCoordinator.activeScreen {
                TargetWeightView(
                    onContinue: { navigationCoordinator.navigateTo(.activitySelection) },
                    onBack: { navigationCoordinator.navigateTo(.goalSelection) }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .activitySelection = navigationCoordinator.activeScreen {
                ActivityLevelView(
                    userProfile: navigationCoordinator.userProfile,
                    onContinue: {
                        navigationCoordinator.navigateTo(.dietSelection)
                    },
                    onBack: {
                        navigationCoordinator.navigateTo(.targetWeight)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .dietSelection = navigationCoordinator.activeScreen {
                DietSelectionView(
                    onContinue: {
                        navigationCoordinator.navigateTo(.appreciation)
                    },
                    onBack: {
                        navigationCoordinator.navigateTo(.activitySelection)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .appreciation = navigationCoordinator.activeScreen {
                AppreciationView(
                    onContinue: {
                        navigationCoordinator.navigateTo(.planBuild)
                    },
                    onBack: {
                        navigationCoordinator.navigateTo(.dietSelection)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .planBuild = navigationCoordinator.activeScreen {
                PlanBuildView(
                    onContinue: {
                        navigationCoordinator.navigateTo(.recommendationLoading)
                    },
                    onBack: {
                        navigationCoordinator.navigateTo(.appreciation)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .recommendationLoading = navigationCoordinator.activeScreen {
                RecommendationLoadingView(
                    onComplete: {
                        navigationCoordinator.navigateTo(.summary)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .summary = navigationCoordinator.activeScreen {
                ProfileSummaryView(
                    onComplete: {
                        navigationCoordinator.navigateTo(nil)
                        navigationCoordinator.isOnboarding = false
                    },
                    onBackToDietSelection: {
                        navigationCoordinator.navigateTo(.dietSelection)
                    }
                )
                .environmentObject(navigationCoordinator)
                .transition(.smoothTransition)
            } else if case .foodDatabase = navigationCoordinator.activeScreen {
                FoodDatabaseView()
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case let .foodIngredientDetail(food) = navigationCoordinator.activeScreen {
                FoodIngredientDetailView(food: food)
                    .environmentObject(navigationCoordinator)
                    .transition(.smoothTransition)
            } else if case let .foodDetail(food) = navigationCoordinator.activeScreen {
                if let food = food as? Food {
                    FoodDetailView(food: food)
                        .environmentObject(navigationCoordinator)
                        .transition(.smoothTransition)
                }
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - Helper Views and Components

struct ScanOptionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(NavigationCoordinator.shared)
    }
}

// Создаем единый стиль анимации перехода для всех экранов
extension AnyTransition {
    static var smoothTransition: AnyTransition {
        let insertion = AnyTransition.opacity
            .combined(with: .move(edge: .trailing))
            .animation(.easeOut(duration: 0.3))
        
        let removal = AnyTransition.opacity
            .combined(with: .move(edge: .leading))
            .animation(.easeIn(duration: 0.25))
        
        return .asymmetric(insertion: insertion, removal: removal)
    }
}


