import SwiftUI
import SwiftData

@Model
final class ExerciseLog {
    var id: UUID
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    @Relationship(inverse: \WorkoutEntry.exercises) var workout: WorkoutEntry?
    
    init(name: String, sets: Int = 3, reps: Int = 10, weight: Double = 20.0) {
        self.id = UUID()
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
    }
}
