import SwiftData
import Foundation

class AchievementManager {
    static let shared = AchievementManager()
    
    let predefinedAchievements: [(title: String, subtitle: String, icon: String, condition: (UserProfile) -> Bool)] = [
        ("Первая тренировка", "Завершите одну тренировку", "1.circle.fill", { $0.workoutEntries?.count ?? 0 >= 1 }),
        ("Мастер спорта", "10 тренировок", "10.circle.fill", { $0.workoutEntries?.count ?? 0 >= 10 }),
        ("Неделя в ударе", "Стрик 7 дней", "7.circle.fill", { $0.streak?.longestStreak ?? 0 >= 7 }),
        ("Двухнедельный герой", "Стрик 14 дней", "14.circle.fill", { $0.streak?.longestStreak ?? 0 >= 14 }),
        ("Калорийный монстр", "Съесть 100 000 ккал", "fork.knife.circle.fill", { totalCaloriesEaten($0) >= 100_000 }),
        ("Белковый гигант", "Потребить 10 кг белка", "fish.circle.fill", { totalProteinEaten($0) >= 10_000 }),
        ("Железный человек", "Поднять 50 тонн суммарно", "scalemass.fill", { totalWeightLifted($0) >= 50_000 }),
    ]
    
    func initializeAchievements(for user: UserProfile, context: ModelContext) {
        if user.achievements == nil || user.achievements?.isEmpty == true {
            for def in predefinedAchievements {
                let ach = Achievement(title: def.title, subtitle: def.subtitle, icon: def.icon)
                ach.user = user
                ach.userID = user.id
                context.insert(ach)
            }
            try? context.save()
        }
    }
    
    func checkAndUnlock(for user: UserProfile, context: ModelContext) {
        guard let achievements = user.achievements else { return }
        for ach in achievements where !ach.isUnlocked {
            if let def = predefinedAchievements.first(where: { $0.title == ach.title }),
               def.condition(user) {
                ach.isUnlocked = true
                ach.unlockDate = Date()
            }
        }
        try? context.save()
    }
    
    private static func totalCaloriesEaten(_ user: UserProfile) -> Double {
        user.foodEntries?.reduce(0) { $0 + $1.calories } ?? 0
    }
    private static func totalProteinEaten(_ user: UserProfile) -> Double {
        user.foodEntries?.reduce(0) { $0 + $1.protein } ?? 0
    }
    private static func totalWeightLifted(_ user: UserProfile) -> Double {
        user.workoutEntries?.reduce(0) { total, workout in
            total + (workout.exercises?.reduce(0) { $0 + ($1.weight * Double($1.sets * $1.reps)) } ?? 0)
        } ?? 0
    }
}
