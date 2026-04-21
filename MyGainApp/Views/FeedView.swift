import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    @State private var users: [UserProfile] = []
    @State private var storyRecords: [StoryViewRecord] = []
    @State private var likes: [Like] = []
    @State private var selectedStoryUser: UserProfile?
    @State private var currentUser: UserProfile?
    @State private var storyOffset: CGSize = .zero
    @State private var storyBackgroundOpacity: Double = 1.0
    
    private var currentUserUUID: UUID? {
        guard let id = currentUserID else { return nil }
        return UUID(uuidString: id)
    }
    
    private var allActivities: [ActivityItem] {
        var items: [ActivityItem] = []
        for user in users {
            if let streak = user.streak, streak.currentStreak > 0 {
                items.append(ActivityItem(
                    id: UUID(), user: user, type: .streak,
                    streakCount: streak.currentStreak,
                    date: streak.lastActivityDate ?? Date()
                ))
            }
            if let achievements = user.achievements {
                for ach in achievements where ach.isUnlocked {
                    items.append(ActivityItem(
                        id: UUID(), user: user, type: .achievement,
                        achievementTitle: ach.title,
                        date: ach.unlockDate ?? Date()
                    ))
                }
            }
            if let userWorkouts = user.workoutEntries {
                for workout in userWorkouts.sorted(by: { $0.date > $1.date }).prefix(10) {
                    items.append(ActivityItem(
                        id: UUID(), user: user, type: .workout,
                        workout: workout, date: workout.date
                    ))
                }
            }
        }
        return items.sorted { $0.date > $1.date }
    }
    
    private var myStreakCount: Int {
        currentUser?.streak?.currentStreak ?? 0
    }
    
    private var activeUsers: [UserProfile] {
        users.filter { user in
            let today = Calendar.current.startOfDay(for: Date())
            let hasWorkout = user.workoutEntries?.contains { Calendar.current.isDate($0.date, inSameDayAs: today) } ?? false
            let hasAchievement = user.achievements?.contains {
                if let date = $0.unlockDate { return Calendar.current.isDate(date, inSameDayAs: today) }
                return false
            } ?? false
            let streakUpdated = user.streak?.lastActivityDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false
            return hasWorkout || hasAchievement || streakUpdated
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Огонёк стрика
                    HStack {
                        Spacer()
                        Label("\(myStreakCount)", systemImage: "flame.fill")
                            .font(.title2.bold())
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                            .padding(.trailing, 16)
                    }
                    .padding(.vertical, 8)
                    
                    // Горизонтальная лента историй (всегда видна)
                    if !activeUsers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(activeUsers) { user in
                                    StoryCircle(user: user, isViewed: isStoryViewed(for: user))
                                        .onTapGesture {
                                            selectedStoryUser = user
                                            markStoryAsViewed(user: user)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    Divider()
                    
                    // Лента активности
                    LazyVStack(spacing: 16) {
                        ForEach(allActivities) { item in
                            ActivityCard(
                                item: item,
                                likeCount: likeCount(for: item.id),
                                isLiked: isLiked(activityID: item.id),
                                onLikeToggle: {
                                    toggleLike(for: item.id)
                                }
                            )
                            .onTapGesture(count: 2) {
                                toggleLike(for: item.id)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Лента")
            .fullScreenCover(item: $selectedStoryUser) { user in
                SocialStoryView(user: user)
                    .offset(storyOffset)
                    .opacity(storyBackgroundOpacity)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                storyOffset = value.translation
                                storyBackgroundOpacity = 1.0 - Double(min(abs(storyOffset.height) / 300, 0.7))
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 150 {
                                    selectedStoryUser = nil
                                    storyOffset = .zero
                                    storyBackgroundOpacity = 1.0
                                } else {
                                    withAnimation(.spring()) {
                                        storyOffset = .zero
                                        storyBackgroundOpacity = 1.0
                                    }
                                }
                            }
                    )
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private func loadData() {
        loadCurrentUser()
        fetchUsers()
        fetchStoryRecords()
        fetchLikes()
    }
    
    private func loadCurrentUser() {
        guard let uuid = currentUserUUID else { return }
        var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        currentUser = try? modelContext.fetch(descriptor).first
    }
    
    private func fetchUsers() {
        users = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
    }
    
    private func fetchStoryRecords() {
        storyRecords = (try? modelContext.fetch(FetchDescriptor<StoryViewRecord>())) ?? []
    }
    
    private func fetchLikes() {
        likes = (try? modelContext.fetch(FetchDescriptor<Like>())) ?? []
    }
    
    private func isStoryViewed(for user: UserProfile) -> Bool {
        guard let currentUUID = currentUserUUID else { return false }
        return storyRecords.contains {
            $0.viewerUserID == currentUUID && $0.storyOwnerUserID == user.id
        }
    }
    
    private func markStoryAsViewed(user: UserProfile) {
        guard let currentUUID = currentUserUUID else { return }
        if !isStoryViewed(for: user) {
            let record = StoryViewRecord(viewerUserID: currentUUID, storyOwnerUserID: user.id)
            modelContext.insert(record)
            try? modelContext.save()
            fetchStoryRecords()
        }
    }
    
    private func likeCount(for activityID: UUID) -> Int {
        likes.filter { $0.activityID == activityID }.count
    }
    
    private func isLiked(activityID: UUID) -> Bool {
        guard let currentUUID = currentUserUUID else { return false }
        return likes.contains { $0.userID == currentUUID && $0.activityID == activityID }
    }
    
    private func toggleLike(for activityID: UUID) {
        guard let currentUUID = currentUserUUID else { return }
        if let existing = likes.first(where: { $0.userID == currentUUID && $0.activityID == activityID }) {
            modelContext.delete(existing)
        } else {
            let like = Like(userID: currentUUID, activityID: activityID)
            modelContext.insert(like)
        }
        try? modelContext.save()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            fetchLikes()
        }
    }
}

// MARK: - ActivityItem
struct ActivityItem: Identifiable {
    let id: UUID
    let user: UserProfile
    let type: ActivityType
    var streakCount: Int?
    var achievementTitle: String?
    var workout: WorkoutEntry?
    let date: Date
    
    enum ActivityType { case streak, achievement, workout }
}

// MARK: - StoryCircle
struct StoryCircle: View {
    let user: UserProfile
    let isViewed: Bool
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: isViewed ? [.gray.opacity(0.5)] : [.red, .orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 70, height: 70)
                
                if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 64, height: 64).clipShape(Circle())
                } else {
                    Circle().fill(Color.accentColor.opacity(0.3))
                        .frame(width: 64, height: 64)
                        .overlay(Text(user.firstName.prefix(1).uppercased()).font(.title2.bold()).foregroundColor(.accentColor))
                }
            }
            Text(user.firstName).font(.caption).lineLimit(1)
        }
        .frame(width: 74)
    }
}

// MARK: - ActivityCard
struct ActivityCard: View {
    let item: ActivityItem
    let likeCount: Int
    let isLiked: Bool
    let onLikeToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                if let avatarData = item.user.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 40, height: 40).clipShape(Circle())
                } else {
                    Circle().fill(Color.accentColor.opacity(0.2)).frame(width: 40, height: 40)
                        .overlay(Text(item.user.firstName.prefix(1).uppercased()).font(.headline).foregroundColor(.accentColor))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.user.firstName).font(.subheadline.bold()) + Text(" ") + Text(activityDescription).font(.subheadline)
                    Text(item.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if item.type == .workout, let workout = item.workout, let exercises = workout.exercises, !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(exercises) { ex in
                        HStack {
                            Text(ex.name).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("\(ex.sets)×\(ex.reps) \(String(format: "%.1f", ex.weight)) кг").font(.caption).bold()
                        }
                    }
                }
                .padding(.leading, 52)
            }
            
            HStack {
                Button(action: onLikeToggle) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .red : .secondary)
                        if likeCount > 0 {
                            Text("\(likeCount)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.leading, 52)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var activityDescription: String {
        switch item.type {
        case .streak: return "🔥 продлил(а) стрик до \(item.streakCount!) дней"
        case .achievement: return "🏅 получил(а) достижение «\(item.achievementTitle!)»"
        case .workout: return "💪 завершил(а) тренировку"
        }
    }
}
