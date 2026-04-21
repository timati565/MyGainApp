import SwiftUI
import SwiftData

class StreakManager: ObservableObject {
    @Published var showCelebration = false
    @Published var streakCount = 0
    
    private var lastCelebrationDate: Date?
    
    func checkAndUpdateStreak(for user: UserProfile, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Предотвращаем повторный показ в тот же день
        if let last = lastCelebrationDate, calendar.isDate(last, inSameDayAs: today) {
            return
        }
        
        if user.streak == nil {
            let streak = Streak()
            streak.user = user
            streak.userID = user.id
            user.streak = streak
        }
        
        guard let streak = user.streak else { return }
        
        if let lastDate = streak.lastActivityDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDifference = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                return
            } else if daysDifference == 1 {
                streak.currentStreak += 1
                streak.lastActivityDate = today
                streakCount = streak.currentStreak
                if streak.currentStreak > streak.longestStreak {
                    streak.longestStreak = streak.currentStreak
                }
                showCelebration = true
                lastCelebrationDate = today
            } else {
                streak.currentStreak = 1
                streak.lastActivityDate = today
            }
        } else {
            streak.currentStreak = 1
            streak.lastActivityDate = today
            streakCount = 1
            showCelebration = true
            lastCelebrationDate = today
        }
        try? context.save()
    }
    
    func recordActivity(for user: UserProfile, context: ModelContext) {
        checkAndUpdateStreak(for: user, context: context)
    }
}
