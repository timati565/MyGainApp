import SwiftUI
import SwiftData

@Model
final class FoodEntry {
    var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var grams: Double?
    var mealType: String
    var timestamp: Date
    
    var userID: UUID?
    @Relationship(inverse: \UserProfile.foodEntries) var user: UserProfile?
    
    init(name: String, calories: Double, protein: Double, fat: Double, carbs: Double, grams: Double? = nil, mealType: String) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.grams = grams
        self.mealType = mealType
        self.timestamp = Date()
    }
}
