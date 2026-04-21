import SwiftUI
import SwiftData

struct SocialStoryView: View {
    let user: UserProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @State private var likes: [Like] = []
    @State private var currentStoryIndex = 0
    @State private var progress: CGFloat = 0.0
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0
    
    private let storyDuration: TimeInterval = 10.0
    private let timerInterval: TimeInterval = 0.05
    
    private var stories: [StoryItem] {
        [StoryItem(user: user)]
    }
    
    private var currentUserUUID: UUID? {
        guard let id = currentUserID else { return nil }
        return UUID(uuidString: id)
    }
    
    private var isLiked: Bool {
        guard let uuid = currentUserUUID else { return false }
        return likes.contains { $0.userID == uuid && $0.activityID == stories[currentStoryIndex].id }
    }
    
    private var likeCount: Int {
        likes.filter { $0.activityID == stories[currentStoryIndex].id }.count
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Прогресс-бары
                    HStack(spacing: 4) {
                        ForEach(0..<stories.count, id: \.self) { index in
                            ProgressBar(progress: index < currentStoryIndex ? 1.0 : (index == currentStoryIndex ? progress : 0.0))
                                .frame(height: 2)
                                .animation(.linear(duration: timerInterval), value: progress)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    
                    // Контент сторис
                    StoryContent(story: stories[currentStoryIndex], user: user)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let width = geometry.size.width
                            if location.x < width * 0.25 {
                                previousStory()
                            } else if location.x > width * 0.75 {
                                nextStory()
                            } else {
                                isPaused.toggle()
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                            isPaused = pressing
                        }, perform: {})
                    
                    // Нижняя панель с лайком и закрытием
                    HStack {
                        Button {
                            toggleLike()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(isLiked ? .red : .white)
                                if likeCount > 0 {
                                    Text("\(likeCount)").foregroundColor(.white)
                                }
                            }
                            .font(.title2)
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            backgroundOpacity = 1.0 - Double(min(abs(dragOffset.height) / 300, 0.7))
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 150 {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                    backgroundOpacity = 1.0
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            fetchLikes()
            startTimer()
        }
        .onDisappear { stopTimer() }
        .onChange(of: currentStoryIndex) { _ in
            progress = 0.0
            startTimer()
        }
        .onChange(of: isPaused) { paused in
            if paused { stopTimer() } else { startTimer() }
        }
    }
    
    private func fetchLikes() {
        let descriptor = FetchDescriptor<Like>()
        likes = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            if !isPaused {
                if progress < 1.0 {
                    progress += CGFloat(timerInterval / storyDuration)
                } else {
                    nextStory()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextStory() {
        if currentStoryIndex < stories.count - 1 {
            currentStoryIndex += 1
            progress = 0.0
        } else {
            dismiss()
        }
    }
    
    private func previousStory() {
        if currentStoryIndex > 0 {
            currentStoryIndex -= 1
            progress = 0.0
        }
    }
    
    private func toggleLike() {
        guard let currentUUID = currentUserUUID else { return }
        let activityID = stories[currentStoryIndex].id
        if let existing = likes.first(where: { $0.userID == currentUUID && $0.activityID == activityID }) {
            modelContext.delete(existing)
        } else {
            let like = Like(userID: currentUUID, activityID: activityID)
            modelContext.insert(like)
        }
        try? modelContext.save()
        fetchLikes()
    }
}

// MARK: - Вспомогательные структуры
struct StoryItem: Identifiable {
    let id = UUID()
    let user: UserProfile
}

struct ProgressBar: View {
    let progress: CGFloat
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.3))
                Rectangle().fill(Color.white)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .cornerRadius(1)
    }
}

struct StoryContent: View {
    let story: StoryItem
    let user: UserProfile
    
    var body: some View {
        VStack(spacing: 20) {
            if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage).resizable().scaledToFill()
                    .frame(width: 150, height: 150).clipShape(Circle())
            } else {
                Circle().fill(Color.accentColor.opacity(0.3)).frame(width: 150, height: 150)
                    .overlay(Text(user.firstName.prefix(1).uppercased()).font(.largeTitle.bold()).foregroundColor(.accentColor))
            }
            Text(user.firstName).font(.largeTitle.bold()).foregroundColor(.white)
            
            if let streak = user.streak, streak.currentStreak > 0 {
                Label("\(streak.currentStreak) дней в ударе", systemImage: "flame.fill").font(.title2).foregroundColor(.orange)
            }
            
            if let latestWorkout = user.workoutEntries?.max(by: { $0.date < $1.date }) {
                VStack {
                    Text("Последняя тренировка:").foregroundColor(.white.opacity(0.7))
                    if let steps = latestWorkout.steps {
                        Text("🏃 \(steps) шагов").foregroundColor(.white).font(.headline)
                    } else if let exercises = latestWorkout.exercises {
                        ForEach(exercises.prefix(3)) { ex in
                            Text("\(ex.name) \(ex.sets)×\(ex.reps)").foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
