import SwiftUI

struct StreakCelebrationView: View {
    let streak: Int
    @Binding var isPresented: Bool
    @State private var scale = 0.5
    @State private var opacity = 0.0
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .shadow(color: .orange.opacity(0.5), radius: 30)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotation))
                }
                .scaleEffect(scale)
                
                Text("\(streak)")
                    .font(.system(size: 70, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .orange, radius: 10)
                
                Text("Дней в ударе!")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text("Продолжай в том же духе!")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = 0.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}
