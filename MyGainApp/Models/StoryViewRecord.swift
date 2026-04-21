import SwiftData
import Foundation

@Model
final class StoryViewRecord {
    var id: UUID
    var viewerUserID: UUID?   // кто посмотрел
    var storyOwnerUserID: UUID? // чей сторис
    var viewedAt: Date
    
    init(viewerUserID: UUID?, storyOwnerUserID: UUID?) {
        self.id = UUID()
        self.viewerUserID = viewerUserID
        self.storyOwnerUserID = storyOwnerUserID
        self.viewedAt = Date()
    }
}
