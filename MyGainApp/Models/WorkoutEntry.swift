import SwiftUI
import SwiftData

@Model
final class WorkoutEntry {
    var id: UUID
    var date: Date
    var isCompleted: Bool
    var userID: UUID?
    
    var steps: Int?
    var distance: Double?
    var caloriesBurned: Double?
    
    @Relationship(deleteRule: .cascade) var exercises: [ExerciseLog]?
    @Relationship(inverse: \UserProfile.workoutEntries) var user: UserProfile?
    
    init(date: Date, steps: Int? = nil, distance: Double? = nil, caloriesBurned: Double? = nil) {
        self.id = UUID()
        self.date = date
        self.isCompleted = false
        self.steps = steps
        self.distance = distance
        self.caloriesBurned = caloriesBurned
    }
}
