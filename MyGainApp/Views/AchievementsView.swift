import SwiftUI
import SwiftData

struct AchievementsView: View {
    let user: UserProfile
    @Environment(\.modelContext) private var modelContext
    @State private var selectedAchievement: Achievement?
    
    private var achievements: [Achievement] {
        user.achievements ?? []
    }
    
    let columns = [GridItem(.adaptive(minimum: 100))]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(achievements) { ach in
                    AchievementCell(achievement: ach)
                        .onTapGesture {
                            selectedAchievement = ach
                        }
                }
            }
            .padding()
        }
        .navigationTitle("Достижения")
        .sheet(item: $selectedAchievement) { ach in
            AchievementDetailView(achievement: ach)
        }
        .onAppear {
            AchievementManager.shared.checkAndUnlock(for: user, context: modelContext)
        }
    }
}

struct AchievementCell: View {
    let achievement: Achievement
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: achievement.icon)
                    .font(.largeTitle)
                    .foregroundColor(achievement.isUnlocked ? .accentColor : .gray)
                if !achievement.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .offset(y: 30)
                }
            }
            Text(achievement.title)
                .font(.caption)
                .multilineTextAlignment(.center)
            Text(achievement.subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .opacity(achievement.isUnlocked ? 1 : 0.6)
    }
}

struct AchievementDetailView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 80))
                    .foregroundColor(achievement.isUnlocked ? .accentColor : .gray)
                
                Text(achievement.title).font(.largeTitle.bold())
                Text(achievement.subtitle).font(.headline).foregroundColor(.secondary)
                
                if !achievement.isUnlocked {
                    Text("Чтобы получить это достижение, выполните условие:\n\(achievement.subtitle)")
                        .multilineTextAlignment(.center)
                        .padding()
                } else if let date = achievement.unlockDate {
                    Text("Получено \(date.formatted(date: .long, time: .omitted))").foregroundColor(.green)
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
