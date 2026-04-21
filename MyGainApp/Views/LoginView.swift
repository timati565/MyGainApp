import SwiftUI
import AuthenticationServices
import CryptoKit
import SwiftData

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.white.opacity(0.2)))
                    
                    Text("MyGain")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            #if os(iOS)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            #else
                            .autocorrectionDisabled(true)
                            #endif
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .placeholder(when: email.isEmpty) {
                                Text("Email").foregroundColor(.white.opacity(0.7))
                            }
                        
                        SecureField("Пароль", text: $password)
                            #if os(iOS)
                            .textContentType(.password)
                            #endif
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .placeholder(when: password.isEmpty) {
                                Text("Пароль").foregroundColor(.white.opacity(0.7))
                            }
                    }
                    .padding(.horizontal)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.white)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Button("Войти") {
                        signInWithEmail()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.accentColor)
                    .disabled(email.isEmpty || password.count < 6)
                    
                    Button("Создать аккаунт") {
                        showingSignUp = true
                    }
                    .foregroundColor(.white)
                    
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
    
    private func signInWithEmail() {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.email == email }
        )
        do {
            let users = try modelContext.fetch(descriptor)
            if let user = users.first,
               let hash = user.passwordHash,
               verifyPassword(password, hashed: hash) {
                currentUserID = user.id.uuidString
                isLoggedIn = true
            } else {
                errorMessage = "Неверный email или пароль"
            }
        } catch {
            errorMessage = "Ошибка входа"
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                
                let descriptor = FetchDescriptor<UserProfile>(
                    predicate: #Predicate { $0.appleUserID == userIdentifier }
                )
                do {
                    let users = try modelContext.fetch(descriptor)
                    if let existingUser = users.first {
                        currentUserID = existingUser.id.uuidString
                        isLoggedIn = true
                    } else {
                        let newUser = UserProfile(
                            firstName: fullName?.givenName ?? "",
                            lastName: fullName?.familyName ?? "",
                            birthDate: Date(),
                            gender: .male,
                            heightCm: 170,
                            currentWeightKg: 70,
                            targetWeightKg: 75,
                            activityLevel: .moderate,
                            workoutsPerWeek: 3,
                            bmr: 1600,
                            targetCalories: 2500,
                            targetProtein: 140
                        )
                        newUser.appleUserID = userIdentifier
                        newUser.email = email
                        modelContext.insert(newUser)
                        try modelContext.save()
                        currentUserID = newUser.id.uuidString
                        isLoggedIn = true
                    }
                } catch {
                    errorMessage = "Ошибка Apple Sign In"
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    private func verifyPassword(_ password: String, hashed: String) -> Bool {
        let inputData = Data(password.utf8)
        let hashedInput = SHA256.hash(data: inputData).compactMap { String(format: "%02x", $0) }.joined()
        return hashedInput == hashed
    }
}

// Вспомогательный модификатор для плейсхолдера
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct SignUpView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("currentUserID") private var currentUserID: String?
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            Form {
                Section {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                    SecureField("Пароль (мин. 6 символов)", text: $password)
                    SecureField("Подтвердите пароль", text: $confirmPassword)
                }
                .listRowBackground(Color.white.opacity(0.2))
                
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
                
                Section {
                    Button("Зарегистрироваться") { signUp() }
                        .disabled(!isFormValid)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Новый аккаунт")
    }
    
    private var isFormValid: Bool {
        email.contains("@") && password.count >= 6 && password == confirmPassword
    }
    
    private func signUp() {
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.email == email })
        do {
            let existing = try modelContext.fetch(descriptor)
            if !existing.isEmpty {
                errorMessage = "Email уже используется"
                return
            }
            let inputData = Data(password.utf8)
            let hashed = SHA256.hash(data: inputData).compactMap { String(format: "%02x", $0) }.joined()
            let newUser = UserProfile(
                firstName: "", lastName: "", birthDate: Date(), gender: .male,
                heightCm: 170, currentWeightKg: 70, targetWeightKg: 75,
                activityLevel: .moderate, workoutsPerWeek: 3,
                bmr: 1600, targetCalories: 2500, targetProtein: 140
            )
            newUser.email = email
            newUser.passwordHash = hashed
            modelContext.insert(newUser)
            try modelContext.save()
            currentUserID = newUser.id.uuidString
            isLoggedIn = true
            dismiss()
        } catch {
            errorMessage = "Ошибка создания аккаунта"
        }
    }
}
