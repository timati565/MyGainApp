import SwiftUI
import SwiftData
import CoreMotion

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    @Query private var workouts: [WorkoutEntry]
    @State private var showingAddWorkout = false
    @State private var showingLiveWorkout = false
    @State private var expandedSections: Set<String> = []
    
    @StateObject private var pedometer = PedometerManager.shared
    @State private var storyWorkout: WorkoutEntry?
    @State private var showingStory = false
    @State private var showingStoryAlert = false
    
    private var userUUID: UUID? {
        guard let id = currentUserID else { return nil }
        return UUID(uuidString: id)
    }
    
    private var user: UserProfile? {
        guard let uuid = userUUID else { return nil }
        var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
    
    init() {
        let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
        let predicateUUID = UUID(uuidString: userID)
        _workouts = Query(
            filter: #Predicate { workout in
                workout.userID == predicateUUID
            },
            sort: \WorkoutEntry.date,
            order: .reverse
        )
    }
    
    private var groupedByDay: [(day: String, workouts: [WorkoutEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM"
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.startOfDay(for: workout.date)
        }
        return grouped.sorted { $0.key > $1.key }.map { (formatter.string(from: $0.key), $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        StepsWidget(steps: pedometer.stepsToday, distance: pedometer.distanceToday)
                            .padding(.horizontal)
                        
                        if let user {
                            NavigationLink {
                                ExerciseProgressView(user: user)
                            } label: {
                                Label("Прогресс весов", systemImage: "chart.line.uptrend.xyaxis")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal)
                        }
                        
                        if workouts.isEmpty {
                            ContentUnavailableView(
                                "Нет тренировок",
                                systemImage: "dumbbell.fill",
                                description: Text("Добавьте первую тренировку, нажав на +")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(groupedByDay, id: \.day) { section in
                                WorkoutSectionCard(
                                    day: section.day,
                                    workouts: section.workouts,
                                    expandedSections: $expandedSections,
                                    onDelete: { workout in
                                        modelContext.delete(workout)
                                        try? modelContext.save()
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Тренировки")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLiveWorkout = true
                    } label: {
                        Label("Бег", systemImage: "figure.run")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWorkout = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView(storyWorkout: $storyWorkout, showingStoryAlert: $showingStoryAlert)
            }
            .sheet(isPresented: $showingLiveWorkout) {
                LiveWorkoutView()
            }
            .fullScreenCover(isPresented: $showingStory) {
                if let workout = storyWorkout {
                    WorkoutStoryView(workout: workout) {
                        showingStory = false
                    }
                }
            }
            .alert("Поделиться тренировкой?", isPresented: $showingStoryAlert) {
                Button("Поделиться") {
                    showingStory = true
                }
                Button("Не сейчас", role: .cancel) { }
            } message: {
                Text("Ваши друзья увидят результат в ленте")
            }
            .onAppear {
                pedometer.refresh()
            }
        }
    }
}

// MARK: - Виджет шагов
struct StepsWidget: View {
    let steps: Int
    let distance: Double
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Шаги сегодня")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(steps)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Дистанция")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f км", distance / 1000))
                    .font(.title2.bold())
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - WorkoutSectionCard (с кнопкой «минус»)
struct WorkoutSectionCard: View {
    let day: String
    let workouts: [WorkoutEntry]
    @Binding var expandedSections: Set<String>
    let onDelete: (WorkoutEntry) -> Void
    
    private var isExpanded: Bool {
        expandedSections.contains(day)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if isExpanded {
                        expandedSections.remove(day)
                    } else {
                        expandedSections.insert(day)
                    }
                }
            } label: {
                HStack {
                    Text(day)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(workouts) { workout in
                        HStack(alignment: .center, spacing: 8) {
                            WorkoutCard(workout: workout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                onDelete(workout)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - WorkoutCard (компактный вид)
struct WorkoutCard: View {
    @Bindable var workout: WorkoutEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.date.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline.bold())
                if workout.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Spacer()
                Button {
                    withAnimation(.spring()) { isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            if isExpanded {
                Divider().padding(.vertical, 4)
                if let steps = workout.steps {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "shoeprints.fill").foregroundColor(.blue)
                            Text("Шаги: \(steps)").font(.subheadline)
                        }
                        if let distance = workout.distance {
                            HStack {
                                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").foregroundColor(.green)
                                Text("Дистанция: \(String(format: "%.2f", distance / 1000)) км").font(.subheadline)
                            }
                        }
                        if let calories = workout.caloriesBurned {
                            HStack {
                                Image(systemName: "flame.fill").foregroundColor(.orange)
                                Text("Калории: \(Int(calories)) ккал").font(.subheadline)
                            }
                        }
                    }
                } else if let exercises = workout.exercises, !exercises.isEmpty {
                    ForEach(exercises) { ex in
                        HStack {
                            Text(ex.name).font(.caption)
                            Spacer()
                            Text("\(ex.sets)×\(ex.reps) \(String(format: "%.1f", ex.weight)) кг").font(.caption).bold()
                        }
                        .padding(.vertical, 1)
                    }
                } else {
                    Text("Нет данных").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - AddWorkoutView (с сохранением и сторис)
struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @Binding var storyWorkout: WorkoutEntry?
    @Binding var showingStoryAlert: Bool
    
    @State private var selectedDate = Date()
    @State private var selectedExercises: [ExerciseLog] = []
    
    let exerciseLibrary = [
        ("Приседания", "figure.cross.training"),
        ("Жим лёжа", "figure.strengthtraining.traditional"),
        ("Становая тяга", "figure.strengthtraining.traditional"),
        ("Тяга штанги", "figure.rower"),
        ("Подтягивания", "figure.pullup"),
        ("Отжимания на брусьях", "figure.dips"),
        ("Жим гантелей сидя", "figure.strengthtraining.traditional")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Дата тренировки", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section("Упражнения") {
                    ForEach($selectedExercises) { $exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: iconFor(exercise.name))
                                    .foregroundColor(.accentColor)
                                Text(exercise.name).font(.headline)
                                Spacer()
                                Button {
                                    selectedExercises.removeAll { $0.id == exercise.id }
                                } label: {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                            }
                            Stepper("Подходы: \(exercise.sets)", value: $exercise.sets, in: 1...10)
                            Stepper("Повторения: \(exercise.reps)", value: $exercise.reps, in: 1...20)
                            HStack {
                                Text("Вес (кг):")
                                TextField("", value: $exercise.weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Menu {
                        ForEach(exerciseLibrary, id: \.0) { name, icon in
                            Button {
                                selectedExercises.append(ExerciseLog(name: name))
                            } label: {
                                Label(name, systemImage: icon)
                            }
                        }
                    } label: {
                        Label("Добавить упражнение", systemImage: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .navigationTitle("Новая тренировка")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveWorkout() }
                        .disabled(selectedExercises.isEmpty)
                }
            }
        }
    }
    
    private func iconFor(_ name: String) -> String {
        exerciseLibrary.first { $0.0 == name }?.1 ?? "figure.strengthtraining.traditional"
    }
    
    private func saveWorkout() {
        let workout = WorkoutEntry(date: selectedDate)
        workout.exercises = selectedExercises
        if let id = currentUserID, let uuid = UUID(uuidString: id) {
            var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
            descriptor.fetchLimit = 1
            workout.user = try? modelContext.fetch(descriptor).first
            workout.userID = uuid
        }
        modelContext.insert(workout)
        try? modelContext.save()
        haptic(.success)
        
        NotificationCenter.default.post(name: .recordUserActivity, object: nil)
        
        storyWorkout = workout
        showingStoryAlert = true
        dismiss()
    }
}
