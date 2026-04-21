import SwiftUI
import SwiftData
import UserNotifications
import HealthKit

@main
struct MyGainApp: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                FoodEntry.self,
                WorkoutEntry.self,
                ExerciseLog.self,
                WeightEntry.self,
                Streak.self,
                Achievement.self,
                StoryViewRecord.self,
                Like.self
            ])
            
            #if DEBUG
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            #else
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            #endif
            
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        HealthKitManager.shared.requestAuthorization { _ in }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
