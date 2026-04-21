import SwiftData
import Foundation

@Model
final class Achievement {
    var id: UUID
    var title: String
    var subtitle: String
    var icon: String
    var isUnlocked: Bool
    var unlockDate: Date?
    var userID: UUID?
    @Relationship(inverse: \UserProfile.achievements) var user: UserProfile?
    
    init(title: String, subtitle: String, icon: String) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isUnlocked = false
    }
}
