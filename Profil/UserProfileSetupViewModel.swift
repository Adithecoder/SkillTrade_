import SwiftUI
import Combine
import DesignSystem

// MARK: - User Profile Setup View Model
class UserProfileSetupViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var address = ""
    @Published var city = ""
    @Published var country = "Magyarország"
    @Published var bio = ""
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var isProfileComplete = false
    
    private let serverAuth = ServerAuthManager.shared
    private let userManager = UserManager.shared
    
    var isValid: Bool {
        !phoneNumber.isEmpty &&
        !address.isEmpty &&
        !city.isEmpty &&
        !country.isEmpty
    }
    
    func saveProfile() {
        guard isValid else {
            error = "Kérjük, töltsd ki az összes kötelező mezőt!"
            return
        }
        
        isLoading = true
        error = nil
        
        // Frissítjük a felhasználó adatait
        if var currentUser = serverAuth.currentUser ?? userManager.currentUser {
            // Lokális frissítés
            currentUser.phoneNumber = phoneNumber
            currentUser.location = Location(city: city, country: country)
            
            // UserManager frissítése
            userManager.currentUser = currentUser
            serverAuth.currentUser = currentUser
            
            // Szerveres frissítés
            updateUserOnServer { success in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if success {
                        self.isProfileComplete = true
                    } else {
                        self.error = "Hiba történt a profil mentése során"
                    }
                }
            }
        } else {
            isLoading = false
            error = "Felhasználói adatok nem találhatók"
        }
    }
    
    private func updateUserOnServer(completion: @escaping (Bool) -> Void) {
        guard let userId = userManager.currentUser?.id ?? serverAuth.currentUser?.id else {
            completion(false)
            return
        }
        
        let updates: [String: Any] = [
            "phoneNumber": phoneNumber,
            "location_city": city,
            "location_country": country,
            "bio": bio
        ]
        
        serverAuth.updateUser(userId: userId, updates: updates) { success, updatedUser in
            if success, let user = updatedUser {
                print("✅ Profil sikeresen frissítve: \(user.name)")
                completion(true)
            } else {
                print("❌ Profil frissítés sikertelen")
                completion(false)
            }
        }
    }
}

// MARK: - River Flow Mesh Gradient Background
struct RiverFlowMeshGradient: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0
    
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Base gradient with flowing movement
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.0, green: 0.08, blue: 0.25),   // Deep blue
                    Color(red: 0.1, green: 0.25, blue: 0.5),    // River blue
                    Color(red: 0.2, green: 0.4, blue: 0.7),     // Light blue
                    Color(red: 0.1, green: 0.3, blue: 0.6)      // Medium blue
                ]),
                startPoint: UnitPoint(x: 0.5 + 0.4 * sin(phase1), y: 0.0),
                endPoint: UnitPoint(x: 0.5 + 0.4 * cos(phase1), y: 1.0)
            )
            .ignoresSafeArea()
            
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.03)) {
                phase1 += 0.02
                phase2 += 0.015
                phase3 += 0.025
            }
        }
    }
    
    private var flowingRiverMesh: some View {
        GeometryReader { geometry in
            ZStack {
                // Main flowing lines - horizontal river currents
                ForEach(0..<8) { i in
                    Path { path in
                        let baseY = CGFloat(i) * geometry.size.height / 8
                        let amplitude: CGFloat = 15
                        let frequency: CGFloat = 0.02
                        
                        path.move(to: CGPoint(x: 0, y: baseY + sin(phase2 + CGFloat(i)) * amplitude))
                        
                        for x in stride(from: 0, through: geometry.size.width, by: 10) {
                            let yOffset = sin(phase2 + frequency * x + CGFloat(i) * 0.5) * amplitude +
                                         cos(phase3 + frequency * x * 0.7 + CGFloat(i)) * amplitude * 0.3
                            path.addLine(to: CGPoint(x: x, y: baseY + yOffset))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.08),
                                .white.opacity(0.15)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5 + sin(phase1 + CGFloat(i)) * 0.5
                    )
                }
                
                // Vertical mesh lines with wave effect
                ForEach(0..<12) { i in
                    Path { path in
                        let baseX = CGFloat(i) * geometry.size.width / 12
                        let amplitude: CGFloat = 8
                        
                        path.move(to: CGPoint(x: baseX + sin(phase3 + CGFloat(i)) * amplitude, y: 0))
                        
                        for y in stride(from: 0, through: geometry.size.height, by: 15) {
                            let xOffset = cos(phase1 + CGFloat(y) * 0.01 + CGFloat(i) * 0.3) * amplitude
                            path.addLine(to: CGPoint(x: baseX + xOffset, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .white.opacity(0.1),
                                .white.opacity(0.05),
                                .white.opacity(0.1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
                }
                
                // Subtle wave patterns
                ForEach(0..<5) { i in
                    Path { path in
                        let centerY = geometry.size.height * (0.2 + CGFloat(i) * 0.15)
                        let amplitude: CGFloat = 25
                        let frequency: CGFloat = 0.015
                        
                        path.move(to: CGPoint(x: 0, y: centerY + sin(phase1 + CGFloat(i)) * amplitude))
                        
                        for x in stride(from: 0, through: geometry.size.width, by: 8) {
                            let yOffset = sin(phase1 + frequency * x + CGFloat(i) * 1.2) * amplitude +
                                         cos(phase2 + frequency * x * 0.5 + CGFloat(i)) * amplitude * 0.4
                            path.addLine(to: CGPoint(x: x, y: centerY + yOffset))
                        }
                    }
                    .stroke(
                        Color.white.opacity(0.06),
                        lineWidth: 2 + cos(phase3 + CGFloat(i)) * 1
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var currentLines: some View {
        GeometryReader { geometry in
            ZStack {
                // Fast flowing current lines
                ForEach(0..<4) { i in
                    Path { path in
                        let speedMultiplier = 1.0 + Double(i) * 0.3
                        let baseY = geometry.size.height * (0.3 + CGFloat(i) * 0.1)
                        let amplitude: CGFloat = 12
                        
                        let startX = -geometry.size.width * 0.5 + (phase1 * 200 * speedMultiplier).truncatingRemainder(dividingBy: geometry.size.width * 1.5)
                        
                        path.move(to: CGPoint(x: startX, y: baseY + sin(phase2 + CGFloat(i)) * amplitude))
                        
                        let points = 20
                        for p in 0..<points {
                            let x = startX + CGFloat(p) * geometry.size.width / CGFloat(points)
                            let yOffset = sin(phase2 + CGFloat(p) * 0.3 + CGFloat(i)) * amplitude
                            path.addLine(to: CGPoint(x: x, y: baseY + yOffset))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.2),
                                .white.opacity(0.3),
                                .white.opacity(0.2),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.2
                    )
                }
                
                // Bubble-like particles flowing with current
                ForEach(0..<15) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                        .offset(
                            x: (phase1 * 100 + CGFloat(i) * 50).truncatingRemainder(dividingBy: geometry.size.width + 100) - 50,
                            y: geometry.size.height * (0.2 + CGFloat(i) * 0.05) + sin(phase2 + CGFloat(i)) * 20
                        )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - User Profile Setup View
struct UserProfileSetupView: View {
    @StateObject private var viewModel = UserProfileSetupViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var appear = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // River flow mesh gradient background
                RiverFlowMeshGradient()
                
                // Content overlay
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                        inputSection
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 50)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Később") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 17))
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                appear = true
            }
        }
//        .fullScreenCover(isPresented: $viewModel.isProfileComplete) {
//            ContentView()
//                .onAppear {
//                    print("🚀 Átirányítás a főalkalmazásba")
//                }
//        }
        .fullScreenCover(isPresented: $viewModel.isProfileComplete) {
            UserProfileSetupView2()
                .onAppear {
                    print("🚀 Átirányítás a főalkalmazásba")
                }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.crop.circle.badge.plus")
                .resizable()
                .frame(width: 80, height: 70)
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.white, .blue.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .symbolEffect(.bounce, value: viewModel.isLoading)
                .scaleEffect(appear ? 1 : 0.5)
                .rotationEffect(.degrees(appear ? 0 : -180))
            
            Text("Profil beállítás")
                .font(.custom("Jellee", size: 32))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
            
            Text("Kérjük, add meg további adataidat a könnyebb munkavállalás érdekében.")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .opacity(appear ? 1 : 0)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Phone Number
            animatedInputField(
                title: "Telefonszám",
                placeholder: "Telefonszám (+36 30-123-4567)",
                text: $viewModel.phoneNumber,
                keyboardType: .phonePad,
                delay: 0.1
            )
            
            // Address
            animatedInputField(
                title: "Lakcím",
                placeholder: "Lakcím (utca, házszám)",
                text: $viewModel.address,
                delay: 0.2
            )
            
            // City and Country
            HStack(spacing: 15) {
                animatedInputField(
                    title: "Város",
                    placeholder: "Város",
                    text: $viewModel.city,
                    isSmall: true,
                    delay: 0.3
                )
                
                animatedInputField(
                    title: "Ország",
                    placeholder: "Magyarország",
                    text: $viewModel.country,
                    isSmall: true,
                    delay: 0.4
                )
            }
            
            // Bio (optional)
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Bemutatkozás (opcionális)")
//                    .font(.custom("Lexend", size: 16))
//                    .foregroundColor(.white)
//                    .opacity(appear ? 1 : 0)
//                    .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)
//                TextEditor(text: $viewModel.bio)
//                    .frame(height: 50)
//                    .padding()
//                    .background(Color.white.opacity(0.1))
//                    .cornerRadius(12)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
//                    )
//                    .foregroundColor(.white)
//                    .font(.custom("Lexend", size: 16))
//                    .scrollContentBackground(.hidden)
//                    .opacity(appear ? 1 : 0)
//                    .offset(y: appear ? 0 : 20)
//                .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)
//            }
            
            // Error message
            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.custom("Lexend", size: 14))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 15) {
            Button(action: {
                viewModel.saveProfile()
            }) {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.2)
                    } else {
                        Text("Profil mentése")
                            .font(.custom("Lexend", size: 18))
                            .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .indigo]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            }
            .disabled(viewModel.isLoading || !viewModel.isValid)
            .opacity((viewModel.isLoading || !viewModel.isValid) ? 0.6 : 1.0)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.5).delay(0.7), value: appear)
            
            Button("Kihagyom most") {
                viewModel.isProfileComplete = true
            }
            .font(.custom("Lexend", size: 16))
            .foregroundColor(.white.opacity(0.8))
            .opacity(appear ? 1 : 0)
            .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)        }
        .padding(.top, 20)
    }
    
    // Helper function for animated input fields
    private func animatedInputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSmall: Bool = false,
        delay: Double = 0
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            
            if keyboardType == .phonePad {
                TextField(placeholder, text: text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(ModernTextFieldStyle())
                    .font(.custom("Jellee", size: 18))
                    .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.5))
                    .background(.white)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .indigo]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                    .cornerRadius(20)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)            } else {
                TextField(placeholder, text: text)
                        .textFieldStyle(ModernTextFieldStyle())
                        .font(.custom("Jellee", size: 18))
                        .foregroundStyle(Color(red: 0.1, green: 0.25, blue: 0.5))
                        .background(.white)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .indigo]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                        .cornerRadius(20)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview Provider
struct UserProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileSetupView()
    }
}
