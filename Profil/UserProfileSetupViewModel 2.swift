//
//  UserProfileSetupViewModel 2.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/8/25.
//

import SwiftUI
import Combine
import DesignSystem

// MARK: - User Profile Setup View Model
class UserProfileSetupViewModel2: ObservableObject {
    @Published var jobTitle = ""
    @Published var jobDescription = ""
    @Published var selectedJobTypes: Set<JobType> = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var isProfileComplete = false
    
    private let serverAuth = ServerAuthManager.shared
    private let userManager = UserManager.shared
    
    var isValid: Bool {
        !jobTitle.isEmpty &&
        !jobDescription.isEmpty &&
        !selectedJobTypes.isEmpty
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
            // Lokális frissítés - csak a meglévő mezőket használjuk
            currentUser.phoneNumber = "" // Optional: clear or keep existing
            currentUser.bio = jobDescription // Use bio for job description
            
            // NEW: Store job data in existing fields or extend User model
            // For now, we'll use the updateUserOnServer to save job-specific data
            // while keeping local compatibility
            
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
            "jobTitle": jobTitle,
            "jobDescription": jobDescription,
            "jobTypes": selectedJobTypes.map { $0.rawValue }
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
    
    func toggleJobType(_ jobType: JobType) {
        if selectedJobTypes.contains(jobType) {
            selectedJobTypes.remove(jobType)
        } else {
            selectedJobTypes.insert(jobType)
        }
    }
}

// MARK: - Job Type Model
public enum JobType: String, CaseIterable {
    case programming = "Programozás"
    case design = "Design"
    case marketing = "Marketing"
    case writing = "Írás"
    case translation = "Fordítás"
    case tutoring = "Oktatás"
    case consulting = "Tanácsadás"
    case photography = "Fotózás"
    case videoEditing = "Videóvágás"
    case music = "Zene"
    case crafts = "Kézművesség"
    case cooking = "Főzés"
    case cleaning = "Takarítás"
    case gardening = "Kertészkedés"
    case repair = "Javítás"
    case delivery = "Kiszállítás"
    case babysitting = "Bébiszitter"
    case elderlyCare = "Idősgondozás"
    case petCare = "Állatgondozás"
    case fitness = "Fitness"
    case beauty = "Szépségápolás"
    case eventPlanning = "Rendezvényszervezés"
    case business = "Üzleti tanácsadás"
    
    var icon: String {
        switch self {
        case .programming: return "laptopcomputer"
        case .design: return "paintpalette"
        case .marketing: return "chart.bar"
        case .writing: return "pencil"
        case .translation: return "globe"
        case .tutoring: return "book"
        case .consulting: return "briefcase"
        case .photography: return "camera"
        case .videoEditing: return "film"
        case .music: return "music.note"
        case .crafts: return "hammer"
        case .cooking: return "fork.knife"
        case .cleaning: return "house"
        case .gardening: return "leaf"
        case .repair: return "wrench"
        case .delivery: return "box.truck"
        case .babysitting: return "figure.and.child.holdinghands"
        case .elderlyCare: return "figure.walk"
        case .petCare: return "pawprint"
        case .fitness: return "dumbbell"
        case .beauty: return "scissors"
        case .eventPlanning: return "calendar"
        case .business: return "building.columns"
        }
    }
}

// MARK: - River Flow Mesh Gradient Background
struct RiverFlowMeshGradient2: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0
    @State private var phase3: CGFloat = 0
    
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Base gradient with flowing movement
            LinearGradient(
                gradient: Gradient(colors: [
                    Color( #colorLiteral(red: 1, green: 0.5401358008, blue: 0.1128892377, alpha: 1)),   // Deep blue
                    Color(#colorLiteral(red: 0.7979255319, green: 0.3984157741, blue: 0, alpha: 1)),    // River blue
                    Color(#colorLiteral(red: 1, green: 0.6193163991, blue: 0, alpha: 1)),     // Light blue
                    Color(#colorLiteral(red: 1, green: 0.8621119857, blue: 0.572447896, alpha: 1))      // Medium blue
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
}

// MARK: - User Profile Setup View
struct UserProfileSetupView2: View {
    @StateObject private var viewModel = UserProfileSetupViewModel2()
    @Environment(\.dismiss) var dismiss
    @State private var appear = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // River flow mesh gradient background
                RiverFlowMeshGradient2()
                
                // Content overlay
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                        inputSection
                        jobTypesSection
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
        .fullScreenCover(isPresented: $viewModel.isProfileComplete) {
            ContentView()
                .onAppear {
                    print("🚀 Átirányítás a főalkalmazásba")
                }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "book.pages.fill")
                .font(.custom("Jellee", size: 60))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: viewModel.isLoading)
                .scaleEffect(appear ? 1 : 0.5)
                .rotationEffect(.degrees(appear ? 0 : -180))
            
            Text("Munkahirdetés")
                .font(.custom("Jellee", size: 32))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
            
            Text("Milyen munkákat fogsz hirdetni? Ezekre jelentkezhetnek nálad a jövőben a felhasználók.")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .opacity(appear ? 1 : 0)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Job Title
            animatedInputField(
                title: "Munkáltatói cím (Specializálódottaknak)",
                placeholder: "Például: Senior iOS fejlesztő",
                text: $viewModel.jobTitle,
                delay: 0.1
            )

            
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
    
    private var jobTypesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Munkatípusok")
                .font(.custom("Lexend", size: 18))
                .foregroundColor(.white)
                .opacity(appear ? 1 : 0)
                .animation(SwiftUI.Animation.easeOut.delay(0.4), value: appear)
            
            Text("Válaszd ki a munkatípusokat (több is lehet)")
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.white.opacity(0.7))
                .opacity(appear ? 1 : 0)
                .animation(SwiftUI.Animation.easeOut.delay(0.5), value: appear)
            
            // 3-column grid for better space utilization
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(JobType.allCases, id: \.self) { jobType in
                    JobTypeBubble(
                        jobType: jobType,
                        isSelected: viewModel.selectedJobTypes.contains(jobType),
                        action: { viewModel.toggleJobType(jobType) }
                    )
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(SwiftUI.Animation.easeOut.delay(0.6 + Double(JobType.allCases.firstIndex(of: jobType) ?? 0) * 0.05), value: appear)
                }
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
                        Text("Munkahirdetés mentése")
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
            .animation(SwiftUI.Animation.easeOut.delay(0.8), value: appear)
        }
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
            Text(title)
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.white)
                .opacity(appear ? 1 : 0)
                .animation(SwiftUI.Animation.easeOut.delay(delay), value: appear)
            
            TextField(placeholder, text: text)
                .textFieldStyle(ModernTextFieldStyle())
                .font(.custom("Jellee", size: 18))
                .foregroundStyle(Color.orange)
                .background(.yellow.opacity(0.5))
                .autocapitalization(.words)
                .autocorrectionDisabled(true)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(LinearGradient(gradient: Gradient(colors: [.yellow, .red]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                .cornerRadius(20)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(SwiftUI.Animation.easeOut.delay(delay + 0.1), value: appear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Job Type Bubble Component
struct JobTypeBubble: View {
    let jobType: JobType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: jobType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(jobType.rawValue)
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                LinearGradient(
                    gradient: Gradient(colors: [.orange, .red]),
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.4)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
            )
            
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                            LinearGradient(gradient: Gradient(colors: [.yellow, .red]), startPoint: .leading, endPoint: .trailing) :
                            
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white, Color.white]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.3 : 0.1), radius: 5, y: 2)
        }
        .buttonStyle(ScaleButtonStyle2())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle2: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview Provider
struct UserProfileSetupView2_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileSetupView2()
    }
}
