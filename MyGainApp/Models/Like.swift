import SwiftData
import Foundation

@Model
final class Like {
    var id: UUID
    var userID: UUID?         // кто лайкнул
    var activityID: UUID      // ID записи (ActivityItem.id)
    var createdAt: Date
    
    init(userID: UUID?, activityID: UUID) {
        self.id = UUID()
        self.userID = userID
        self.activityID = activityID
        self.createdAt = Date()
    }
}
