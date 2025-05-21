import Foundation
import SwiftUI
import CoreData

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Food] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String? = nil
    @Published var recentSearches: [String] = []
    
    private var context: NSManagedObjectContext
    private var foodDataService: FoodDataService
    
    init(context: NSManagedObjectContext = CoreDataManager.shared.context) {
        self.context = context
        self.foodDataService = FoodDataService.shared
        
        // Load recent searches from UserDefaults
        loadRecentSearches()
    }
    
    func search() {
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        errorMessage = nil
        
        // Add to recent searches
        addToRecentSearches(searchText)
        
        // Search using FoodDataService
        foodDataService.searchByName(query: searchText) { [weak self] foods in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.searchResults = foods
                self.isSearching = false
                
                if foods.isEmpty {
                    self.errorMessage = "No foods found for '\(self.searchText)'"
                }
            }
        }
    }
    
    // Add to recent searches and save to UserDefaults
    private func addToRecentSearches(_ query: String) {
        // Only add if not already in the list
        if !recentSearches.contains(query) {
            recentSearches.insert(query, at: 0)
            
            // Limit to 10 recent searches
            if recentSearches.count > 10 {
                recentSearches = Array(recentSearches.prefix(10))
            }
            
            // Save to UserDefaults
            saveRecentSearches()
        }
    }
    
    // Load recent searches from UserDefaults
    private func loadRecentSearches() {
        if let savedSearches = UserDefaults.standard.stringArray(forKey: "recentFoodSearches") {
            recentSearches = savedSearches
        }
    }
    
    // Save recent searches to UserDefaults
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentFoodSearches")
    }
    
    // Clear recent searches
    func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "recentFoodSearches")
    }
    
    // Get a food by ID from Core Data
    func getFood(byId id: UUID) -> Food? {
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let results = try context.fetch(request)
            return results.first
        } catch {
            print("Error fetching food by ID: \(error)")
            return nil
        }
    }
} 