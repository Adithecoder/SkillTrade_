import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import DesignSystem
import Combine

// MARK: - Custom Button Style
struct ModernButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                               startPoint: .leading,
                                               endPoint: .trailing))
                    .shadow(color: backgroundColor.opacity(0.3), radius: 8, y: 4)
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

// MARK: - Custom Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color.DesignSystem.fokekszin.opacity(0.3))
            .cornerRadius(20)
            .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x:4, y: 4)
    }
}

// MARK: - Login View Model
class LoginViewModel: ObservableObject {
    @Published var identifier = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var isLoggedIn = false
    
    private let userManager = UserManager.shared
    private let serverAuth = ServerAuthManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Figyeljük a ServerAuthManager állapotváltozásait
        serverAuth.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.isLoggedIn = true
                    self?.isLoading = false
                    self?.error = nil
                }
            }
            .store(in: &cancellables)
        
        serverAuth.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverError in
                if let serverError = serverError {
                    self?.error = serverError
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
        
        serverAuth.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] serverLoading in
                self?.isLoading = serverLoading
            }
            .store(in: &cancellables)
    }
    
    func login() {
        isLoading = true
        error = nil
        
        // Először ellenőrizzük, hogy a szerver elérhető-e
        Task {
            let isServerAvailable = await serverAuth.checkServerStatus()
            
            await MainActor.run {
                if !isServerAvailable {
                    self.error = "A szerver jelenleg nem érhető el. Kérjük, próbáld újra később."
                    self.isLoading = false
                    return
                }
                
                // Folytatjuk a bejelentkezést, ha a szerver elérhető
                self.continueLogin()
            }
        }
    }
    
    // LoginView.swift - Update the login function in ViewModel
    private func continueLogin() {
        guard !identifier.isEmpty, !password.isEmpty else {
            error = "Kérjük, töltsd ki az összes mezőt!"
            isLoading = false
            return
        }

        print("🔐 Bejelentkezési kísérlet: \(identifier)")
        
        serverAuth.login(identifier: identifier, password: password) { [weak self] success in
            DispatchQueue.main.async {
                print("📡 Bejelentkezés válasz: \(success ? "SIKERES" : "SIKERTELEN")")
                
                if success {
                    print("✅ Bejelentkezés sikeres a szerveren")
                    
                    // Force token save and sync
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    UserDefaults.standard.set(self?.identifier, forKey: "userEmail")
                    UserDefaults.standard.synchronize()
                    
                    // Verify token was saved
                    let savedToken = UserDefaults.standard.string(forKey: "authToken")
                    print("💾 TOKEN VERIFICATION - Saved: \(savedToken != nil), Length: \(savedToken?.count ?? 0)")
                    
                    self?.isLoggedIn = true
                } else {
                    print("❌ Bejelentkezés sikertelen a szerveren")
                    if let serverError = self?.serverAuth.error {
                        print("🔴 Szerver hiba: \(serverError)")
                        self?.error = serverError
                    } else {
                        self?.error = "Ismeretlen hiba történt"
                    }
                }
                self?.isLoading = false
            }
        }
    }
    
    // Google Sign In function - marad változatlan
    func signInWithGoogle() {
        isLoading = true
        
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            self.error = "Hiányzó Google Client ID konfiguráció"
            self.isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let rootViewController = windowScene?.windows.first?.rootViewController
        
        if let presentingViewController = rootViewController {
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] signInResult, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.error = error.localizedDescription
                        return
                    }
                    
                    guard let user = signInResult?.user else {
                        self?.error = "Nem sikerült bejelentkezni Google fiókkal"
                        return
                    }
                    
                    // Google bejelentkezés sikeres
                    UserManager.shared.signInWithGoogle(user: user)
                    UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    UserManager.shared.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: "isFirstLogin")
                    self?.isLoggedIn = true
                }
            }
        } else {
            self.error = "Nem sikerült elindítani a Google bejelentkezést"
            self.isLoading = false
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showRegister = false
    @State private var showTerms = false
    @State private var isRotating = false
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Background elements
            animatedBackgroundElements
            
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [.white, Color(.systemGray6)]),
                           startPoint: .top,
                           endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
            
            // Main content
            ScrollView {
                VStack(spacing: 30) {
                    // Logo section
                    Image(systemName: "person.2.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                                        startPoint: .top,
                                                        endPoint: .trailing))
                        .symbolEffect(.bounce, value: viewModel.isLoading)
                        .shadow(color: .DesignSystem.descriptions.opacity(0.3), radius: 16, x: 4, y: 4)
                        .padding(.top, 50)
                    
                    Text("Üdvözlünk a SkillTrade-nél!")
                        .font(.custom("Jellee", size: 26))
                        .multilineTextAlignment(.center)
                    
                    Text("Jelentkezz be!")
                        .font(.custom("Jellee", size: 36))
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing))
                        .multilineTextAlignment(.center)
                    
                    // Input section
                    VStack(spacing: 20) {
                        TextField("E-mail vagy felhasználónév", text: $viewModel.identifier)
                            .textFieldStyle(ModernTextFieldStyle())
                            .font(.custom("Jellee", size: 18))
                            .foregroundStyle(.white)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(20)
                        
                        SecureField("Jelszó", text: $viewModel.password)
                            .foregroundStyle(.white)
                            .textFieldStyle(ModernTextFieldStyle())
                            .textContentType(.password)
                            .font(.custom("Jellee", size: 18))
                            .autocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(20)
                        
                        // Hibaüzenet
                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.custom("Lexend", size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Buttons section
                    VStack(spacing: 20) {
                        Button(action: {
                            print("🎯 Bejelentkezés gomb megnyomva")
                            viewModel.login()
                        }) {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Text("Bejelentkezés")
                                        .font(.custom("Lexend", size: 20))
                                        .foregroundColor(Color.white)
                                }
                            }
                        }
                        .buttonStyle(ModernButtonStyle(backgroundColor: .DesignSystem.fokekszin, foregroundColor: .black))
                        .disabled(viewModel.isLoading)
                        
//                        Button(action: {
//                            print("🎯 Bejelentkezés gomb megnyomva")
//                            viewModel.signInWithGoogle()
//                        }) {
//                            Group {
//                                if viewModel.isLoading {
//                                    ProgressView()
//                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                        .scaleEffect(1.2)
//                                } else {
//                                    Text("Bejelentkezés Gooogle-lel")
//                                        .font(.custom("Lexend", size: 20))
//                                        .foregroundColor(Color.white)
//                                }
//                            }
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.25, green: 0.52, blue: 0.95), // Google Kék
                                        Color(red: 0.91, green: 0.30, blue: 0.24), // Google Piros
                                        Color(red: 0.98, green: 0.73, blue: 0.16), // Google Sárga
                                        Color(red: 0.20, green: 0.81, blue: 0.36)  // Google Zöld
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        )
                        .foregroundColor(.white)
                        .disabled(viewModel.isLoading)
                        
                        SocialLoginView()

                        
//                        GoogleSignInButton {
//                            print("🎯 Google bejelentkezés gomb megnyomva")
//                            viewModel.signInWithGoogle()
//                        }
//                            .frame(height: 60)
//                            .cornerRadius(20)
//                            .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                        
                        Button(action: {
                            showRegister = true
                        }) {
                            Text("Nincs még fiókod? Regisztrálj!")
                                .font(.custom("Jellee", size: 20))
                                .foregroundColor(Color.DesignSystem.fokekszin)
                        }
                        
                        // Felhasználási feltételek
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "book.pages")
                                .font(.title2)
                                .foregroundStyle(Color.DesignSystem.descriptions)
                            Button(action: { showTerms = true }) {
                                Text("Bejelentkezéseddel elfogadod a felhasználási feltételeket és az adatvédelmi irányelveket.")
                                    .font(.custom("Lexend", size: 11))
                                    .foregroundStyle(Color.DesignSystem.descriptions)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
        .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
            ContentView()
                .onAppear {
                    print("🚀 Átirányítás a főképernyőre")
                }
        }
        .onAppear {
            isRotating = true
            isPulsing = true
            // Reseteljük a hibákat az oldal megnyitásakor
            viewModel.error = nil
            ServerAuthManager.shared.error = nil
        }
    }
    
    private var animatedBackgroundElements: some View {
        ZStack {
            // Large rotating circles
            Circle()
                .fill(Color.DesignSystem.fokekszin.opacity(0.2))
                .frame(width: 300)
                .offset(x: -UIScreen.main.bounds.width/3, y: -UIScreen.main.bounds.height/3)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(Animation.linear(duration: 20).repeatForever(autoreverses: false), value: isRotating)
            
            Circle()
                .fill(Color.DesignSystem.bordosszin.opacity(0.2))
                .frame(width: 400)
                .offset(x: UIScreen.main.bounds.width/3, y: UIScreen.main.bounds.height/4)
                .rotationEffect(.degrees(isRotating ? -360 : 0))
                .animation(Animation.linear(duration: 25).repeatForever(autoreverses: false), value: isRotating)
            
            // Medium pulsing circles
            Circle()
                .fill(Color.DesignSystem.sargaska.opacity(0.2))
                .frame(width: 200)
                .offset(x: UIScreen.main.bounds.width/4, y: -UIScreen.main.bounds.height/3)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .animation(Animation.easeInOut(duration: 3).repeatForever(), value: isPulsing)
            
            // Additional background elements
            Circle()
                .fill(Color.DesignSystem.fokekszin.opacity(0.15))
                .frame(width: 150)
                .offset(x: UIScreen.main.bounds.width/2.5, y: UIScreen.main.bounds.height/2.5)
                .rotationEffect(.degrees(isRotating ? 720 : 0))
                .animation(Animation.linear(duration: 15).repeatForever(autoreverses: false), value: isRotating)
            
            Circle()
                .fill(Color.DesignSystem.sargaska.opacity(0.15))
                .frame(width: 180)
                .offset(x: -UIScreen.main.bounds.width/2.8, y: UIScreen.main.bounds.height/3)
                .rotationEffect(.degrees(isRotating ? -540 : 0))
                .animation(Animation.linear(duration: 18).repeatForever(autoreverses: false), value: isRotating)
            
            // Tiny floating dots
            Circle()
                .fill(Color.DesignSystem.descriptions.opacity(0.1))
                .frame(width: 80)
                .offset(x: UIScreen.main.bounds.width/5, y: -UIScreen.main.bounds.height/5)
                .scaleEffect(isPulsing ? 1.5 : 0.7)
                .animation(Animation.easeInOut(duration: 4).repeatForever(), value: isPulsing)
            
            Circle()
                .fill(Color.DesignSystem.fokekszin)
                .frame(width: 60)
                .offset(x: -UIScreen.main.bounds.width/4, y: UIScreen.main.bounds.height/5)
                .scaleEffect(isPulsing ? 1.3 : 0.6)
                .animation(Animation.easeInOut(duration: 5).repeatForever().delay(0.5), value: isPulsing)
            
            // Subtle background grid pattern
            ForEach(0..<5) { i in
                Path { path in
                    let yPos = CGFloat(i) * UIScreen.main.bounds.height/4
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: UIScreen.main.bounds.width, y: yPos))
                }
                .stroke(Color.DesignSystem.descriptions.opacity(0.05), lineWidth: 1)
                
                Path { path in
                    let xPos = CGFloat(i) * UIScreen.main.bounds.width/4
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: UIScreen.main.bounds.height))
                }
                .stroke(Color.DesignSystem.descriptions.opacity(0.05), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Preview Provider
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
