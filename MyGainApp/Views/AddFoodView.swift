import SwiftUI
import SwiftData

struct AddFoodView: View {
    let mealType: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""
    @State private var grams = ""
    @State private var showingScanner = false
    
    private var isFormValid: Bool {
        !name.isEmpty && Double(calories) != nil && Double(protein) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $name)
                }
                
                Section("Пищевая ценность") {
                    TextField("Калории", text: $calories)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Белки", text: $protein)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Жиры", text: $fat)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Углеводы", text: $carbs)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Граммовка (опционально)", text: $grams)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                Section {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Сканировать штрих-код", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .navigationTitle("Добавить \(mealType)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveFood()
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { scannedFood in
                    if let food = scannedFood {
                        name = food.name
                        calories = String(format: "%.0f", food.calories)
                        protein = String(format: "%.1f", food.protein)
                        fat = String(format: "%.1f", food.fat)
                        carbs = String(format: "%.1f", food.carbs)
                        if let serving = food.servingSize {
                            grams = String(format: "%.0f", serving)
                        }
                    }
                }
            }
        }
    }
    
    private func saveFood() {
        guard let cal = Double(calories), let prot = Double(protein) else { return }
        let fatVal = Double(fat) ?? 0
        let carbVal = Double(carbs) ?? 0
        let gramVal = Double(grams)
        
        let entry = FoodEntry(
            name: name,
            calories: cal,
            protein: prot,
            fat: fatVal,
            carbs: carbVal,
            grams: gramVal,
            mealType: mealType
        )
        if let id = currentUserID, let uuid = UUID(uuidString: id) {
            var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
            descriptor.fetchLimit = 1
            entry.user = try? modelContext.fetch(descriptor).first
            entry.userID = uuid
        }
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
