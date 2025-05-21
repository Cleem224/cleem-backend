import Foundation

class WaterSettings: ObservableObject {
    // Singleton instance for app-wide access
    static let shared = WaterSettings()
    
    // Available serving sizes
    static let availableServingSizes = [250, 500, 750, 1000]
    
    // Use UserDefaults to persist water settings
    @Published var servingSize: Int
    @Published var totalWaterIntake: Int
    
    init() {
        // Load saved values or use defaults
        let savedServingSize = UserDefaults.standard.integer(forKey: "waterServingSize")
        self.servingSize = savedServingSize > 0 ? savedServingSize : 250
        self.totalWaterIntake = UserDefaults.standard.integer(forKey: "totalWaterIntake")
        
        // If servingSize was 0, save the default value
        if savedServingSize == 0 {
            UserDefaults.standard.set(self.servingSize, forKey: "waterServingSize")
        }
    }
    
    // Add water based on the serving size
    func addWater() {
        totalWaterIntake += servingSize
        UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
    }
    
    // Remove water based on the serving size
    func removeWater() {
        if totalWaterIntake >= servingSize {
            totalWaterIntake -= servingSize
        } else {
            totalWaterIntake = 0
        }
        UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
    }
    
    // Reset water intake (e.g., for daily reset)
    func resetWaterIntake() {
        totalWaterIntake = 0
        UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
    }
    
    // Update serving size
    func updateServingSize(_ newSize: Int) {
        servingSize = newSize
        UserDefaults.standard.set(servingSize, forKey: "waterServingSize")
    }
}

