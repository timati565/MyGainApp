import SwiftUI

struct RootView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedProfile") private var hasCompletedProfile = false
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashView(isActive: $showSplash)
            } else {
                if !isLoggedIn {
                    LoginView()
                } else if !hasCompletedProfile {
                    ProfileSetupView(isEditing: false)
                } else {
                    ContentView()
                }
            }
        }
    }
}

struct SplashView: View {
    @Binding var isActive: Bool
    @State private var scale = 0.8
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image("AppIcon")
                    .resizable()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: .accentColor.opacity(0.3), radius: 20)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Text("MyGain")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    isActive = false
                }
            }
        }
    }
}
