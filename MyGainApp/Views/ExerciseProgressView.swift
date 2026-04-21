import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressView: View {
    let user: UserProfile
    @Query private var workouts: [WorkoutEntry]
    @State private var selectedExercise: String?
    @State private var timeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case month = "30 дней", threeMonths = "3 месяца", all = "Всё время"
        var days: Int? {
            switch self {
            case .month: return 30
            case .threeMonths: return 90
            default: return nil
            }
        }
    }
    
    init(user: UserProfile) {
        self.user = user
        let userID = user.id
        _workouts = Query(filter: #Predicate { $0.userID == userID }, sort: \WorkoutEntry.date)
    }
    
    private var availableExercises: [String] {
        Array(Set(workouts.flatMap { $0.exercises ?? [] }.map { $0.name })).sorted()
    }
    
    private var exerciseData: [(date: Date, maxWeight: Double, volume: Double)] {
        guard let exercise = selectedExercise else { return [] }
        let filtered = workouts.filter { workout in
            workout.exercises?.contains { $0.name == exercise } ?? false
        }
        let cutoff: Date?
        if let days = timeRange.days {
            cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())
        } else {
            cutoff = nil
        }
        let relevant = filtered.filter { cutoff == nil || $0.date >= cutoff! }
        
        return relevant.map { workout in
            let exercises = workout.exercises?.filter { $0.name == exercise } ?? []
            let maxWeight = exercises.map { $0.weight }.max() ?? 0
            let volume = exercises.reduce(0) { $0 + $1.weight * Double($1.sets * $1.reps) }
            return (workout.date, maxWeight, volume)
        }
    }
    
    var body: some View {
        VStack {
            Picker("Упражнение", selection: $selectedExercise) {
                Text("Выберите").tag(String?.none)
                ForEach(availableExercises, id: \.self) { ex in
                    Text(ex).tag(String?.some(ex))
                }
            }
            .pickerStyle(.menu)
            .padding()
            
            if selectedExercise != nil {
                Picker("Период", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if !exerciseData.isEmpty {
                    Chart(exerciseData, id: \.date) { item in
                        LineMark(
                            x: .value("Дата", item.date),
                            y: .value("Макс. вес (кг)", item.maxWeight)
                        )
                        .foregroundStyle(Color.accentColor)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                        
                        BarMark(
                            x: .value("Дата", item.date),
                            y: .value("Объём (кг)", item.volume)
                        )
                        .foregroundStyle(Color.orange.opacity(0.5))
                    }
                    .frame(height: 300)
                    .padding()
                } else {
                    ContentUnavailableView("Нет данных", systemImage: "chart.line.downtrend.xyaxis")
                }
            } else {
                ContentUnavailableView("Выберите упражнение", systemImage: "dumbbell")
            }
        }
        .navigationTitle("Прогресс весов")
        .navigationBarTitleDisplayMode(.inline)
    }
}
