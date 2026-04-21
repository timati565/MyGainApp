import SwiftUI
import SwiftData

enum Gender: String, Codable, CaseIterable {
    case male = "Мужской"
    case female = "Женский"
    case other = "Другое"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary = "Сидячий"
    case light = "Умеренный"
    case moderate = "Активный"
    case heavy = "Очень активный"
    
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .heavy: return 1.725
        }
    }
}

@Model
final class UserProfile {
    var id: UUID
    var appleUserID: String?
    var email: String?
    var passwordHash: String?
    
    var firstName: String
    var lastName: String
    var birthDate: Date
    var genderRaw: String
    var heightCm: Double
    var currentWeightKg: Double
    var targetWeightKg: Double
    var activityLevelRaw: String
    var workoutsPerWeek: Int
    
    var bmr: Double
    var targetCalories: Double
    var targetProtein: Double
    
    var avatarData: Data?
    var hapticsEnabled: Bool = true
    var soundsEnabled: Bool = true
    
    @Relationship(deleteRule: .cascade) var foodEntries: [FoodEntry]?
    @Relationship(deleteRule: .cascade) var workoutEntries: [WorkoutEntry]?
    @Relationship(deleteRule: .cascade) var weightEntries: [WeightEntry]?
    @Relationship(deleteRule: .cascade) var streak: Streak?
    @Relationship(deleteRule: .cascade) var achievements: [Achievement]?
    
    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .male }
        set { genderRaw = newValue.rawValue }
    }
    
    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }
    
    init(
        firstName: String,
        lastName: String,
        birthDate: Date,
        gender: Gender,
        heightCm: Double,
        currentWeightKg: Double,
        targetWeightKg: Double,
        activityLevel: ActivityLevel,
        workoutsPerWeek: Int,
        bmr: Double,
        targetCalories: Double,
        targetProtein: Double,
        avatarData: Data? = nil,
        hapticsEnabled: Bool = true,
        soundsEnabled: Bool = true,
        streak: Streak? = nil,
        achievements: [Achievement]? = nil
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.birthDate = birthDate
        self.genderRaw = gender.rawValue
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.activityLevelRaw = activityLevel.rawValue
        self.workoutsPerWeek = workoutsPerWeek
        self.bmr = bmr
        self.targetCalories = targetCalories
        self.targetProtein = targetProtein
        self.avatarData = avatarData
        self.hapticsEnabled = hapticsEnabled
        self.soundsEnabled = soundsEnabled
        self.streak = streak
        self.achievements = achievements
    }
    
    func calculateBMR() -> Double {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        if gender == .male {
            return 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) + 5
        } else {
            return 10 * currentWeightKg + 6.25 * heightCm - 5 * Double(age) - 161
        }
    }
    
    func calculateTargetCalories() -> Double {
        return bmr * activityLevel.factor + 400
    }
    
    func calculateTargetProtein() -> Double {
        return currentWeightKg * 2.0
    }
}
