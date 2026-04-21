import SwiftUI
import SwiftData
import Charts

struct WeightProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    @Query private var foodEntries: [FoodEntry]
    @Query private var weightEntries: [WeightEntry]
    @State private var showingAddWeight = false
    @State private var timeRange: TimeRange = .month
    
    enum TimeRange: String, CaseIterable {
        case month = "30 дней"
        case threeMonths = "3 месяца"
    }
    
    private var userUUID: UUID? {
        guard let id = currentUserID else { return nil }
        return UUID(uuidString: id)
    }
    
    init() {
        let userID = UserDefaults.standard.string(forKey: "currentUserID") ?? ""
        let predicateUUID = UUID(uuidString: userID)
        _foodEntries = Query(
            filter: #Predicate { $0.userID == predicateUUID },
            sort: \FoodEntry.timestamp
        )
        _weightEntries = Query(
            filter: #Predicate { $0.userID == predicateUUID },
            sort: \WeightEntry.date
        )
    }
    
    private var filteredWeightEntries: [WeightEntry] {
        let cutoff = cutoffDate
        return weightEntries.filter { $0.date >= cutoff }
    }
    
    private var filteredFoodEntries: [FoodEntry] {
        let cutoff = cutoffDate
        return foodEntries.filter { $0.timestamp >= cutoff }
    }
    
    private var cutoffDate: Date {
        switch timeRange {
        case .month: return Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        case .threeMonths: return Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        }
    }
    
    private var averageCalories: Int {
        let days = Set(filteredFoodEntries.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        guard days > 0 else { return 0 }
        let total = filteredFoodEntries.reduce(0) { $0 + $1.calories }
        return Int(total / Double(days))
    }
    
    private var averageProtein: Int {
        let days = Set(filteredFoodEntries.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        guard days > 0 else { return 0 }
        let total = filteredFoodEntries.reduce(0) { $0 + $1.protein }
        return Int(total / Double(days))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Диапазон", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if filteredWeightEntries.isEmpty {
                        ContentUnavailableView(
                            "Нет данных о весе",
                            systemImage: "chart.line.downtrend.xyaxis",
                            description: Text("Добавьте первое измерение")
                        )
                        .frame(height: 250)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Динамика веса")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart(filteredWeightEntries) { entry in
                                LineMark(
                                    x: .value("Дата", entry.date),
                                    y: .value("Вес", entry.weight)
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Дата", entry.date),
                                    y: .value("Вес", entry.weight)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.1).gradient)
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 250)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "Средние калории",
                            value: "\(averageCalories)",
                            unit: "ккал",
                            icon: "flame.fill",
                            color: .orange
                        )
                        StatCard(
                            title: "Средний белок",
                            value: "\(averageProtein)",
                            unit: "г",
                            icon: "fish.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)
                    
                    Button {
                        showingAddWeight = true
                    } label: {
                        Label("Записать вес", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Прогресс")
            .sheet(isPresented: $showingAddWeight) {
                AddWeightView()
            }
        }
    }
}

// MARK: - StatCard
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2.bold())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AddWeightView
struct AddWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @State private var weight = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Вес (кг)", text: $weight)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                DatePicker("Дата", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("Запись веса")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveWeight()
                    }
                    .disabled(Double(weight) == nil)
                }
            }
        }
    }
    
    private func saveWeight() {
        guard let weightValue = Double(weight) else { return }
        let entry = WeightEntry(weight: weightValue, date: date)
        if let id = currentUserID, let uuid = UUID(uuidString: id) {
            var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
            descriptor.fetchLimit = 1
            entry.user = try? modelContext.fetch(descriptor).first
            entry.userID = uuid
        }
        modelContext.insert(entry)
        
        if let user = entry.user {
            user.currentWeightKg = weightValue
        }
        try? modelContext.save()
        dismiss()
    }
}
