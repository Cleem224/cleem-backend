//
//  Meal+CoreDataClass.swift
//  Cleem
//
//  Created by Faiq Novruzov on 23.04.25.
//
//

import Foundation
import CoreData


public class Meal: NSManagedObject {
    
    // Метод для расчета общей питательной ценности приема пищи
    public func calculateTotals() {
        guard let mealFoods = self.mealFoods as? Set<MealFood> else {
            return
        }
        
        // Сбрасываем значения
        self.totalCalories = 0
        self.totalProtein = 0
        self.totalCarbs = 0
        self.totalFat = 0
        
        // Суммируем значения по всем продуктам
        for mealFood in mealFoods {
            if let food = mealFood.food {
                let multiplier = mealFood.amount / (food.servingSize > 0 ? food.servingSize : 100)
                
                self.totalCalories += food.calories * multiplier
                self.totalProtein += food.protein * multiplier
                self.totalCarbs += food.carbs * multiplier
                self.totalFat += food.fat * multiplier
            }
        }
    }
}
