import SwiftUI
import SwiftData

struct ProfileSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @AppStorage("currentUserID") private var currentUserID: String?
    
    let isEditing: Bool
    @State private var user: UserProfile?
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date())!
    @State private var gender: Gender = .male
    @State private var heightCm = ""
    @State private var currentWeight = ""
    @State private var targetWeight = ""
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var workoutsPerWeek = 3
    @State private var bmr = ""
    @State private var targetCalories = ""
    @State private var targetProtein = ""
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty &&
        !heightCm.isEmpty && Double(heightCm) != nil &&
        !currentWeight.isEmpty && Double(currentWeight) != nil &&
        !targetWeight.isEmpty && Double(targetWeight) != nil &&
        !bmr.isEmpty && Double(bmr) != nil &&
        !targetCalories.isEmpty && Double(targetCalories) != nil &&
        !targetProtein.isEmpty && Double(targetProtein) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Личные данные") {
                    TextField("Имя", text: $firstName)
                    TextField("Фамилия", text: $lastName)
                    DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                    Picker("Пол", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Параметры тела") {
                    TextField("Рост (см)", text: $heightCm)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Текущий вес (кг)", text: $currentWeight)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Целевой вес (кг)", text: $targetWeight)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                Section("Активность") {
                    Picker("Уровень активности", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    Stepper("Тренировок в неделю: \(workoutsPerWeek)", value: $workoutsPerWeek, in: 1...7)
                }
                
                Section("Расчёт калорий") {
                    HStack {
                        Text("BMR (ккал)")
                        Spacer()
                        TextField("BMR", text: $bmr)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Button("⟲") {
                            calculateBMR()
                        }
                    }
                    HStack {
                        Text("Целевые калории")
                        Spacer()
                        TextField("ккал", text: $targetCalories)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Button("⟲") {
                            calculateTargetCalories()
                        }
                    }
                    HStack {
                        Text("Целевой белок")
                        Spacer()
                        TextField("грамм", text: $targetProtein)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                        Button("⟲") {
                            calculateTargetProtein()
                        }
                    }
                }
                
                Section {
                    Button("Сохранить") {
                        saveProfile()
                    }
                    .disabled(!isFormValid)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(isEditing ? "Редактировать профиль" : "Заполните профиль")
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }
                    }
                }
            }
            .onAppear {
                loadUser()
                if !isEditing {
                    calculateBMR()
                    calculateTargetCalories()
                    calculateTargetProtein()
                }
            }
        }
    }
    
    private func loadUser() {
        guard let idString = currentUserID,
              let uuid = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == uuid }
        )
        user = try? modelContext.fetch(descriptor).first
        if let user {
            firstName = user.firstName
            lastName = user.lastName
            birthDate = user.birthDate
            gender = user.gender
            heightCm = String(format: "%.0f", user.heightCm)
            currentWeight = String(format: "%.1f", user.currentWeightKg)
            targetWeight = String(format: "%.1f", user.targetWeightKg)
            activityLevel = user.activityLevel
            workoutsPerWeek = user.workoutsPerWeek
            bmr = String(format: "%.0f", user.bmr)
            targetCalories = String(format: "%.0f", user.targetCalories)
            targetProtein = String(format: "%.0f", user.targetProtein)
        }
    }
    
    private func calculateBMR() {
        guard let weight = Double(currentWeight),
              let height = Double(heightCm) else { return }
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
        let calculated: Double
        if gender == .male {
            calculated = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        } else {
            calculated = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }
        bmr = String(format: "%.0f", max(1000, calculated))
    }
    
    private func calculateTargetCalories() {
        guard let bmrValue = Double(bmr) else { return }
        let factor = activityLevel.factor
        let calculated = bmrValue * factor + 400
        targetCalories = String(format: "%.0f", calculated)
    }
    
    private func calculateTargetProtein() {
        guard let weight = Double(currentWeight) else { return }
        targetProtein = String(format: "%.0f", weight * 2.0)
    }
    
    private func saveProfile() {
        guard let idString = currentUserID,
              let uuid = UUID(uuidString: idString),
              let height = Double(heightCm),
              let weight = Double(currentWeight),
              let tWeight = Double(targetWeight),
              let bmrVal = Double(bmr),
              let calVal = Double(targetCalories),
              let protVal = Double(targetProtein) else { return }
        
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == uuid }
        )
        if let existingUser = try? modelContext.fetch(descriptor).first {
            existingUser.firstName = firstName
            existingUser.lastName = lastName
            existingUser.birthDate = birthDate
            existingUser.gender = gender
            existingUser.heightCm = height
            existingUser.currentWeightKg = weight
            existingUser.targetWeightKg = tWeight
            existingUser.activityLevel = activityLevel
            existingUser.workoutsPerWeek = workoutsPerWeek
            existingUser.bmr = bmrVal
            existingUser.targetCalories = calVal
            existingUser.targetProtein = protVal
            try? modelContext.save()
            hasCompletedProfile = true
            if isEditing {
                dismiss()
            }
        }
    }
}
