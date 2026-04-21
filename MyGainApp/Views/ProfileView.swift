import SwiftUI
import SwiftData
import HealthKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("currentUserID") private var currentUserID: String?
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @State private var showingEditProfile = false
    @State private var showingDeleteConfirmation = false
    @State private var showingImagePicker = false
    @State private var avatarData: Data?
    
    @StateObject private var healthManager = HealthKitManager.shared
    @State private var isSyncingHealth = false
    @State private var showHealthAlert = false
    @State private var healthAlertMessage = ""
    
    private var user: UserProfile? {
        guard let id = currentUserID, let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let user {
                    ScrollView {
                        VStack(spacing: 20) {
                            ProfileHeader(user: user, onAvatarTap: { showingImagePicker = true })
                            StatsGrid(user: user)
                            ParametersSection(user: user)
                            
                            // Настройки
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Настройки")
                                        .font(.headline)
                                        .padding(.horizontal, 8)
                                    
                                    VStack(spacing: 0) {
                                        Toggle("Тактильная отдача", isOn: Binding(
                                            get: { user.hapticsEnabled },
                                            set: { newValue in
                                                user.hapticsEnabled = newValue
                                                try? modelContext.save()
                                                UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                                            }
                                        ))
                                        .padding()
                                        
                                        Divider()
                                        
                                        Toggle("Звуки", isOn: Binding(
                                            get: { user.soundsEnabled },
                                            set: { newValue in
                                                user.soundsEnabled = newValue
                                                try? modelContext.save()
                                                UserDefaults.standard.set(newValue, forKey: "soundsEnabled")
                                            }
                                        ))
                                        .padding()
                                    }
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            
                            // Apple Health
                            Section {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Apple Health")
                                        .font(.headline)
                                        .padding(.horizontal, 8)
                                    
                                    VStack(spacing: 0) {
                                        if healthManager.isAuthorized {
                                            Button {
                                                syncWithHealth()
                                            } label: {
                                                HStack {
                                                    Text("Синхронизировать данные")
                                                    if isSyncingHealth {
                                                        Spacer()
                                                        ProgressView()
                                                    }
                                                }
                                                .padding()
                                            }
                                        } else {
                                            Button("Подключить Apple Health") {
                                                healthManager.requestAuthorization { success in
                                                    if success {
                                                        haptic(.success)
                                                        healthAlertMessage = "Доступ разрешён"
                                                    } else {
                                                        healthAlertMessage = "Не удалось получить доступ к Health. Проверьте настройки конфиденциальности."
                                                    }
                                                    showHealthAlert = true
                                                }
                                            }
                                            .padding()
                                        }
                                    }
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                            
                            // Достижения
                            NavigationLink {
                                AchievementsView(user: user)
                            } label: {
                                HStack {
                                    Label("Достижения", systemImage: "medal.fill")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .padding(.horizontal, 8)
                            
                            ActionsSection(
                                onEdit: { showingEditProfile = true },
                                onLogout: logout,
                                onDelete: { showingDeleteConfirmation = true }
                            )
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Профиль не найден",
                        systemImage: "person.slash",
                        description: Text("Попробуйте перезайти в аккаунт")
                    )
                }
            }
            .navigationTitle("Профиль")
            .sheet(isPresented: $showingEditProfile) {
                ProfileSetupView(isEditing: true)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(imageData: $avatarData)
                    .onDisappear {
                        if let data = avatarData, let user {
                            user.avatarData = data
                            try? modelContext.save()
                        }
                    }
            }
            .confirmationDialog(
                "Удалить все данные?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) { deleteAllData() }
                Button("Отмена", role: .cancel) {}
            }
            .alert("Apple Health", isPresented: $showHealthAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(healthAlertMessage)
            }
        }
    }
    
    private func syncWithHealth() {
        guard let user = user else { return }
        isSyncingHealth = true
        
        let group = DispatchGroup()
        
        group.enter()
        healthManager.fetchLatestWeight { weight in
            if let weight = weight, weight != user.currentWeightKg {
                let entry = WeightEntry(weight: weight)
                entry.user = user
                entry.userID = user.id
                self.modelContext.insert(entry)
                user.currentWeightKg = weight
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            try? self.modelContext.save()
            self.isSyncingHealth = false
            haptic(.success)
            healthAlertMessage = "Синхронизация завершена"
            showHealthAlert = true
        }
    }
    
    private func logout() {
        isLoggedIn = false
        currentUserID = nil
        hasCompletedProfile = false
    }
    
    private func deleteAllData() {
        guard let user else { return }
        for entry in user.foodEntries ?? [] { modelContext.delete(entry) }
        for entry in user.workoutEntries ?? [] { modelContext.delete(entry) }
        for entry in user.weightEntries ?? [] { modelContext.delete(entry) }
        modelContext.delete(user)
        try? modelContext.save()
        logout()
    }
}

// MARK: - Компоненты
struct ProfileHeader: View {
    let user: UserProfile
    let onAvatarTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: onAvatarTap) {
                if let avatarData = user.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 120, height: 120)
                        Text(user.firstName.prefix(1).uppercased())
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 3))
                }
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 4) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.title.bold())
                Text(user.email ?? "—")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct StatsGrid: View {
    let user: UserProfile
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCell(title: "Текущий вес", value: String(format: "%.1f", user.currentWeightKg), unit: "кг")
            StatCell(title: "Целевой вес", value: String(format: "%.1f", user.targetWeightKg), unit: "кг")
            StatCell(title: "BMR", value: "\(Int(user.bmr))", unit: "ккал")
            StatCell(title: "Цель калорий", value: "\(Int(user.targetCalories))", unit: "ккал")
        }
    }
}

struct StatCell: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ParametersSection: View {
    let user: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Параметры")
                .font(.headline)
                .padding(.horizontal, 8)
            
            VStack(spacing: 12) {
                ParameterCard(icon: "ruler", title: "Рост", value: "\(Int(user.heightCm)) см", color: .blue)
                ParameterCard(icon: "figure.walk", title: "Активность", value: user.activityLevel.rawValue, color: .green)
                ParameterCard(icon: "calendar", title: "Тренировок в неделю", value: "\(user.workoutsPerWeek)", color: .orange)
                ParameterCard(icon: "fish.fill", title: "Целевой белок", value: "\(Int(user.targetProtein)) г", color: .purple)
            }
        }
        .padding(.horizontal, 8)
    }
}

struct ParameterCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .bold()
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActionsSection: View {
    let onEdit: () -> Void
    let onLogout: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onEdit) {
                Label("Редактировать профиль", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(role: .destructive, action: onLogout) {
                Label("Выйти из аккаунта", systemImage: "arrow.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(role: .destructive, action: onDelete) {
                Label("Удалить все данные", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
    }
}
