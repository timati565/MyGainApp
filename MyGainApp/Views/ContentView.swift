import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 2  // Лента по индексу 2 (0-based)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NutritionView()
                .tabItem { Label("Питание", systemImage: "fork.knife") }
                .tag(0)
            WorkoutView()
                .tabItem { Label("Тренировки", systemImage: "dumbbell") }
                .tag(1)
            FeedView()
                .tabItem { Label("Лента", systemImage: "newspaper") }
                .tag(2)
            WeightProgressView()
                .tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.circle") }
                .tag(4)
        }
    }
}
