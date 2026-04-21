import SwiftUI
import SwiftData

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @Query private var foodEntries: [FoodEntry]
    @State private var showingAddSheet = false
    @State private var selectedMeal: String = "Завтрак"
    @State private var showingScanner = false
    
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
        _foodEntries = Query(
            filter: #Predicate { entry in
                entry.userID == predicateUUID
            },
            sort: \FoodEntry.timestamp,
            order: .reverse
        )
    }
    
    private var todayEntries: [FoodEntry] {
        foodEntries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    private var totalCalories: Double {
        todayEntries.reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        todayEntries.reduce(0) { $0 + $1.protein }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let user {
                            HeaderProgressCard(
                                totalCalories: totalCalories,
                                targetCalories: user.targetCalories,
                                totalProtein: totalProtein,
                                targetProtein: user.targetProtein,
                                onAddShake: addProteinShake
                            )
                        }
                        
                        mealSections
                    }
                    .padding()
                }
            }
            .navigationTitle("Питание")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddFoodView(mealType: selectedMeal)
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { scannedFood in
                    if let food = scannedFood {
                        addScannedFood(food)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var mealSections: some View {
        ForEach(["Завтрак", "Обед", "Ужин", "Перекус"], id: \.self) { meal in
            MealSectionView(
                mealType: meal,
                entries: todayEntries.filter { $0.mealType == meal },
                onAdd: {
                    selectedMeal = meal
                    showingAddSheet = true
                }
            )
        }
    }
    
    private func addProteinShake() {
        guard let uuid = userUUID, let user else { return }
        let shake = FoodEntry(
            name: "Протеиновый коктейль",
            calories: 500,
            protein: 30,
            fat: 5,
            carbs: 80,
            grams: 400,
            mealType: "Перекус"
        )
        shake.userID = uuid
        shake.user = user
        modelContext.insert(shake)
        try? modelContext.save()
        
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
    
    private func addScannedFood(_ food: ScannedFood) {
        guard let uuid = userUUID, let user else { return }
        let entry = FoodEntry(
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            fat: food.fat,
            carbs: food.carbs,
            grams: food.servingSize,
            mealType: "Перекус"
        )
        entry.userID = uuid
        entry.user = user
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

// MARK: - HeaderProgressCard (простой и надёжный)
struct HeaderProgressCard: View {
    let totalCalories: Double
    let targetCalories: Double
    let totalProtein: Double
    let targetProtein: Double
    let onAddShake: () -> Void
    
    var progress: Double {
        min(totalCalories / targetCalories, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Калории")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(totalCalories)) / \(Int(targetCalories)) ккал")
                        .font(.subheadline.bold())
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                HStack {
                    Text("Белок")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(totalProtein)) / \(Int(targetProtein)) г")
                        .font(.subheadline.bold())
                }
            }
            .padding()
            
            Button(action: onAddShake) {
                Label("Добавить протеин (+500 ккал)", systemImage: "cup.and.saucer.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }
}

// MARK: - MealSectionView (с кнопкой «минус» для удаления)
struct MealSectionView: View {
    let mealType: String
    let entries: [FoodEntry]
    let onAdd: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconFor(mealType))
                    .foregroundColor(.accentColor)
                Text(mealType)
                    .font(.title3.bold())
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }
            
            if entries.isEmpty {
                Text("Нет продуктов")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        FoodEntryRow(entry: entry)
                        Spacer()
                        Button {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func iconFor(_ meal: String) -> String {
        switch meal {
        case "Завтрак": return "sunrise.fill"
        case "Обед": return "sun.max.fill"
        case "Ужин": return "moon.stars.fill"
        default: return "fork.knife"
        }
    }
}

// MARK: - FoodEntryRow (без изменений)
struct FoodEntryRow: View {
    let entry: FoodEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name)
                .font(.subheadline.bold())
            HStack(spacing: 8) {
                Text("\(Int(entry.calories)) ккал")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                if let grams = entry.grams {
                    Text("·")
                    Text("\(Int(grams)) г")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
