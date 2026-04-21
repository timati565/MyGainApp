import SwiftUI
import SwiftData

@Model
final class WeightEntry {
    var id: UUID
    var weight: Double
    var date: Date
    var userID: UUID?
    @Relationship(inverse: \UserProfile.weightEntries) var user: UserProfile?
    
    init(weight: Double, date: Date = Date()) {
        self.id = UUID()
        self.weight = weight
        self.date = date
    }
}
