import SwiftUI

struct WorkoutStoryView: View {
    let workout: WorkoutEntry
    let onDismiss: () -> Void
    @State private var offset: CGSize = .zero
    @State private var backgroundOpacity: Double = 0.7
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            
            VStack(spacing: 20) {
                // Карточка сторис
                VStack(spacing: 20) {
                    Text("Тренировка завершена!")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text(workout.date.formatted(date: .long, time: .shortened))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    if let steps = workout.steps {
                        HStack(spacing: 30) {
                            VStack {
                                Image(systemName: "shoeprints.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                Text("\(steps)")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                Text("шагов")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            if let distance = workout.distance {
                                VStack {
                                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                        .font(.title)
                                        .foregroundColor(.green)
                                    Text(String(format: "%.2f", distance / 1000))
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                    Text("км")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            if let calories = workout.caloriesBurned {
                                VStack {
                                    Image(systemName: "flame.fill")
                                        .font(.title)
                                        .foregroundColor(.orange)
                                    Text("\(Int(calories))")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                    Text("ккал")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    } else if let exercises = workout.exercises, !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(exercises) { ex in
                                HStack {
                                    Text(ex.name)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(ex.sets)×\(ex.reps) \(String(format: "%.1f", ex.weight)) кг")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Text("Отличная работа!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .top, endPoint: .bottom))
                )
                .padding(.horizontal, 20)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                            backgroundOpacity = 0.7 - Double(min(abs(offset.height) / 500, 0.7))
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 150 {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    offset = .zero
                                    backgroundOpacity = 0.7
                                }
                            }
                        }
                )
                
                HStack(spacing: 40) {
                    Button {
                        shareStory()
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .transition(.opacity)
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            offset = CGSize(width: 0, height: UIScreen.main.bounds.height)
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
    
    private func shareStory() {
        // Создание изображения для шаринга (можно через UIGraphicsImageRenderer)
        // Для простоты используем стандартный ActivityViewController
        let renderer = ImageRenderer(content: storyCardView)
        if let uiImage = renderer.uiImage {
            let av = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(av, animated: true)
            }
        }
    }
    
    @ViewBuilder
    private var storyCardView: some View {
        VStack(spacing: 20) {
            Text("Тренировка завершена!")
                .font(.title.bold())
                .foregroundColor(.white)
            // ... копия содержимого карточки ...
        }
        .padding(30)
        .background(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
        .frame(width: 350, height: 500)
    }
}
