import UserNotifications

struct NotificationManager {
    static func scheduleWorkoutReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Время тренировки!"
        content.body = "Не забудьте выполнить сегодняшнюю тренировку, чтобы достичь цели."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "workoutReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
