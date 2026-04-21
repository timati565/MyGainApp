import SwiftData
import Foundation

@Model
final class Streak {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: Date?
    var userID: UUID?
    @Relationship(inverse: \UserProfile.streak) var user: UserProfile?
    
    init() {
        self.currentStreak = 0
        self.longestStreak = 0
    }
}
