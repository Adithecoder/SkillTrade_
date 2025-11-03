import SwiftUI
import DesignSystem

struct ProfilView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var showingEditProfile = false
    @State private var showingServerUsers = false
    @State private var isLoading = false
    @State private var profileImageData: Data?
    @State private var showingImagePicker = false
    @State private var verificationCheckTimer: Timer?
    @State private var lastRefreshTime = Date() // Új állapot
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    Text(NSLocalizedString("Profiladatok", comment:"" ))
                        .font(.custom("Jellee", size: 30))
                        .foregroundColor(Color.DesignSystem.fokekszin) // Dinamikus színváltás
                        .multilineTextAlignment(.center)
                    
                    // Profilkép és alapadatok
                    profileHeader
                    
                    // Betöltés indikátor
                    if isLoading {
                        ProgressView("Adatok betöltése...")
                            .font(.custom("Lexend", size: 14))
                            .padding()
                    }
                    
                    // Alapadatok
                    basicInfoSection
                    
                    // Szerver adatok (ha van szerver kapcsolat)
                    
                    
                    // Lokális adatbázis adatok
                    localInfoSection
                    
//                    verificationStatusSection

                    if serverAuth.isAuthenticated {
                        serverInfoSection
                    }
                    // Műveletek
                    actionsSection
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Szerkesztés") {
                        showingEditProfile = true
                    }
                    .font(.custom("Lexend", size: 17))
                    .foregroundStyle(Color.DesignSystem.fokekszin)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .sheet(isPresented: $showingServerUsers) {
                ServerUsersView()
            }
            .onAppear {
                loadUserData()
            }
            .refreshable {
                await refreshData()
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 15) {
            ZStack {
                if let profileImageData = profileImageData,
                   let uiImage = UIImage(data: profileImageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    if let user = getDisplayUser(), !user.name.isEmpty {
                        Text(user.name.prefix(1).uppercased())
                            .font(.custom("Jellee", size: 48))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    
                        
                }
                if let user = getDisplayUser(), user.isVerified {
                    DottedBadge(size: 125) // Nagyobb méret, hogy a profilkép körül legyen
                }
            }
            
            
            .overlay(
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera.badge.ellipsis.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(5)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .offset(x: 40, y: 40)
            )
            
            VStack(spacing: 5) {
                if let user = getDisplayUser() {
                    // ITT A JAVÍTÁS: a név és a verified badge egy sorban
                    if user.isVerified {
                        HStack(spacing: 4) {
                            VerifiedBadge(size: 20)
                            Text(user.username)
                                .font(.custom("Jellee", size:24))

                        }
                        .rainbow()  // 👈 az egész HStack-re
                    } else {
                        Text(user.username)
                            .foregroundStyle(.black)
                            .font(.custom("Jellee", size:24))
                    }

                    
                    HStack(spacing: 4) {

                        
                        HStack{
                            VStack{
                                
                                Text("Értékelések")
                                    .font(.custom("Lexend", size: 18))
                                    .foregroundColor(.black)
                                
                                HStack{
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.DesignSystem.descriptions)
                                        .font(.system(size: 18))
                                    
                                    Text("\(String(format: "%.1f", user.rating))")
                                        .font(.custom("Jellee", size: 16))
                                        .foregroundColor(.black)
                                }
                            }
                            Divider()
                                .overlay(Rectangle()
                                    .frame(width: 2))
                                .foregroundColor(.DesignSystem.descriptions)
                            VStack{
                                Text("Követések")
                                    .font(.custom("Lexend", size: 18))
                                    .foregroundColor(.black)
                                HStack{
                                    Image(systemName: "person.fill.badge.plus")
                                        .foregroundColor(.DesignSystem.fokekszin)
                                        .font(.system(size: 18))
                                    
                                    Text("\(String(format: "%.1f", user.rating))")
                                        .font(.custom("Jellee", size: 16))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(10)
                    Divider()
                        .overlay(Rectangle()
                            .frame(height: 2))
                        .foregroundColor(.DesignSystem.descriptions)
                    // Szerver státusz
                    if serverAuth.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Szerver kapcsolat aktív")
                                .font(.custom("Lexend", size: 12))
                                .foregroundColor(.green)
                        }
                    }
                } else {
                    Text("Nincs bejelentkezve")
                        .font(.custom("Jellee", size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Alap- és személyes adatok")
                .font(.custom("Jellee", size: 20))
                .bold()
                .foregroundColor(.DesignSystem.fokekszin)
            
            LazyVStack(spacing: 12) {
                if let user = getDisplayUser() {
                    if let serverUser = serverAuth.currentUser {
                        
                        InfoRow(icon: "person", title: "Név", value: serverUser.name)
                        
                        InfoRow(icon: "envelope", title: "Email", value: user.email)
                        InfoRow(icon: "person.text.rectangle", title: "Felhasználónév", value: user.username)
                        
                        if let age = user.age {
                            InfoRow(icon: "number", title: "Életkor", value: "\(age) év")
                        }
                        
                        //                        InfoRow(icon: "star", title: "Értékelés", value: "\(String(format: "%.1f", user.rating))")
                        VStack{
                            HStack{
                                if user.isVerified {
                                    InfoRow(icon: "checkmark.seal", title: "Hitelesítve", value: "Igen")
                                        .rainbow()  // 👈 így helyesen
                                    
                                    
                                    Image("verified")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    
                                    
                                } else {
                                    InfoRow(icon: "exclamationmark.triangle", title: "Állapot", value: "Nincs hitelesítve")
                                        .foregroundColor(.orange)
                                    
                                            Image(systemName: "xmark.seal")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(.orange)
                                        
                                    
                                }
                                
                                
                            }

                        }

                        HStack{
                            Text(user.isVerified ? "Fiókod hitelesítve van. Munkáidat előrébbsoroljuk, profilodat megbízhatóként tüntetjük fel." : "A hitelesítés adminisztrátori jóváhagyást igényel")
                                .font(.custom("Lexend", size: 14))
                                .bold()
                                .foregroundColor(user.isVerified ? .green : .orange)
                            
                            Spacer()
                            if user.isVerified {
                                
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(user.isVerified ? .green : .red)
                                
                            }
                            
                            else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        Divider()
                            .overlay(Rectangle()
                                .frame(height: 2))
                            .foregroundColor(.DesignSystem.descriptions)
                        
                        HStack{
                            Text("További információ a hitelesítésről és annak menetéről")
                                .font(.custom("Lexend", size: 14))
                                .foregroundStyle(Color.DesignSystem.fokekszin)

                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(Color.DesignSystem.fokekszin)
                            
                        }
                        
                    }
                    
                }
                
            }
            .padding()

            .background(Color.DesignSystem.fokekszin.opacity(0.1))
            .cornerRadius(20)
            
            
        }
    }
    
    // MARK: - Server Info Section
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Szerver Adatok")
                    .font(.custom("Jellee", size: 20))
                    .bold()
                    .foregroundColor(.DesignSystem.descriptions)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.DesignSystem.descriptions)
                    .font(.title2)
            }
            
            LazyVStack(spacing: 12) {
                if let serverUser = serverAuth.currentUser {
                    InfoRow(icon: "server.rack", title: "Szerver ID", value: serverUser.id.uuidString.prefix(8) + "...")
//                    InfoRow(icon: "person", title: "Név", value: serverUser.name)
//                    InfoRow(icon: "at", title: "Felhasználónév", value: serverUser.username)
//                    InfoRow(icon: "number", title: "Életkor", value: "\(serverUser.age ?? 0) év")
                    
                    if let createdAt = serverUser.createdAt {
                        InfoRow(icon: "clock", title: "Létrehozva", value: formatDate(createdAt))
                    }
                } else {
                    InfoRow(icon: "xmark.circle", title: "Állapot", value: "Nincs szerver adat")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.DesignSystem.descriptions.opacity(0.1))
            .cornerRadius(20)
        }
    }
    private var debugInfoSection: some View {
        Section(header: Text("Debug Info").font(.custom("Jellee", size: 16))) {
            if let serverUser = serverAuth.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Szerver adatok:")
                        .font(.custom("Lexend", size: 14))
                        .bold()
                    
                    Text("ID: \(serverUser.id.uuidString.prefix(8))...")
                        .font(.custom("Lexend", size: 12))
                    
                    Text("Verified: \(serverUser.isVerified ? "IGEN ✅" : "NEM ❌")")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(serverUser.isVerified ? .green : .red)
                    
                    Text("Email: \(serverUser.email)")
                        .font(.custom("Lexend", size: 12))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            
            if let localUser = userManager.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lokális adatok:")
                        .font(.custom("Lexend", size: 14))
                        .bold()
                    
                    Text("ID: \(localUser.id.uuidString.prefix(8))...")
                        .font(.custom("Lexend", size: 12))
                    
                    Text("Verified: \(localUser.isVerified ? "IGEN ✅" : "NEM ❌")")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(localUser.isVerified ? .green : .red)
                    
                    Text("Email: \(localUser.email)")
                        .font(.custom("Lexend", size: 12))
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(20)
            }
        }
    }
    // MARK: - Local Info Section
    private var localInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            LazyVStack(spacing: 12) {
                if let user = userManager.currentUser {
                    InfoRow(icon: "location", title: "Város", value: user.location.city.isEmpty ? "Nincs megadva" : user.location.city)
                    InfoRow(icon: "globe", title: "Ország", value: user.location.country.isEmpty ? "Nincs megadva" : user.location.country)
                    InfoRow(icon: "phone", title: "Telefon", value: user.phoneNumber ?? "Nincs megadva")
                    InfoRow(icon: "briefcase", title: "Szerepkör", value: userRoleDisplayName(user.userRole))
                    InfoRow(icon: "flag", title: "Státusz", value: userStatusDisplayName(user.status))
                    
                    // Szolgáltatások
                    if !user.servicesOffered.isEmpty {
                        InfoRow(icon: "wand.and.stars", title: "Kínált szolgáltatások", value: user.servicesOffered)
                    }
                    
                    if !user.servicesAdvertised.isEmpty {
                        InfoRow(icon: "megaphone", title: "Hirdetett szolgáltatások", value: user.servicesAdvertised)
                    }
                    
                    // XP
                    InfoRow(icon: "sparkles", title: "XP pontok", value: "\(user.xp)")
                    
                    
                    Divider()
                        .overlay(Rectangle()
                            .frame(height: 2))
                        .foregroundColor(.DesignSystem.descriptions)
                    
                    HStack{
                        Text("Ezeket csak a te engedélyeddel láthatják mások")
                            .font(.custom("Lexend", size: 14))
                            .foregroundStyle(.red)
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.red)
                    }
                    HStack{

                        Text("További információ személyes adataid kezeléséről")
                            .font(.custom("Lexend", size: 14))
                            .foregroundStyle(Color.DesignSystem.fokekszin)
                        Spacer()
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundStyle(Color.DesignSystem.fokekszin)
                    }
                }
                
                
            }
            .padding()
            .background(Color.DesignSystem.bordosszin.opacity(0.1))
            .cornerRadius(20)
            
            
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 15) {
            if serverAuth.isAuthenticated {
                Button(action: {
                    showingServerUsers = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("Összes szerver felhasználó")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            
            Button(action: {
                Task {
                    await refreshData()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Adatok frissítése")
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.white)
                .padding()
                .background(Color.DesignSystem.fokekszin)
                .cornerRadius(20)
            }
            .disabled(isLoading)
            
            // FRISSÍTETT KIJELENTKEZÉS GOMB
            Button(action: {
                logout()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Kijelentkezés")
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
                .cornerRadius(20)
            }
            .disabled(isLoading)

        }
        .padding(.vertical)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(imageData: $profileImageData, onImageSelected: uploadProfileImage)
        }
        .onAppear {
            loadProfileImage()
        }
    }
    private var verificationStatusSection: some View {
           VStack(alignment: .leading, spacing: 15) {
               HStack {
                   Text("Hitelesítési Státusz")
                       .font(.custom("Jellee", size: 20))
                       .bold()
                       .foregroundColor(.DesignSystem.fokekszin)
                   
                   Spacer()
                   
                   if let user = getDisplayUser() {
                       if user.isVerified {
                           Image(systemName: "checkmark.seal.fill")
                               .foregroundColor(.blue)
                               .font(.title2)
                       } else {
                           Image(systemName: "xmark.seal")
                               .foregroundColor(.secondary)
                               .font(.title2)
                       }
                   }
               }
               
               if let user = getDisplayUser() {
                   VStack(alignment: .leading, spacing: 10) {
                       HStack {
                           Text("Státusz:")
                               .font(.custom("Lexend", size: 14))
                               .foregroundColor(.secondary)
                           
                           Spacer()
                           
                           Text(user.isVerified ? "Hitelesítve " : "Nincs hitelesítve")
                               .font(.custom("Lexend", size: 14))
                               .bold()
                               .foregroundColor(user.isVerified ? .green : .orange)
                       }
                       
                       if !user.isVerified {
                           Text("A hitelesítés adminisztrátori jóváhagyást igényel")
                               .font(.custom("Lexend", size: 12))
                               .foregroundColor(.secondary)
                               .multilineTextAlignment(.center)
                       }
                       
                       Text(user.isVerified ? "Fiókod hitelesítve van. Munkáidat előrébbsoroljuk, profilodat megbízhatóként tüntetjük fel." : "Nincs hitelesítve")
                           .font(.custom("Lexend", size: 14))
                           .bold()
                           .foregroundColor(user.isVerified ? .green : .orange)

                       HStack{
                           Text("További információ a hitelesítésről és annak menetéről")
                               .font(.custom("Lexend", size: 14))
                           
                           Image(systemName: "chevron.right")
                           
                       }
                       // Admin gomb - csak admin felhasználóknak
//                       if user.userRole == .admin {
//                           Button("Hitelesítés Kezelése") {
//                               showVerificationManagement()
//                           }
//                           .font(.custom("Lexend", size: 14))
//                           .padding(.horizontal, 16)
//                           .padding(.vertical, 8)
//                           .background(Color.blue)
//                           .foregroundColor(.white)
//                           .cornerRadius(8)
//                       }
                   }
                   .padding()
                   .background(user.isVerified ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                   .cornerRadius(20)
               }
           }
       }
       
       // MARK: - Verified státusz polling
    private func startVerificationPolling() {
        verificationCheckTimer?.invalidate()
        
        verificationCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.checkVerificationStatus()
        }
    }
       
       private func stopVerificationPolling() {
           verificationCheckTimer?.invalidate()
           verificationCheckTimer = nil
       }
       
       private func checkVerificationStatus() {
           guard serverAuth.isAuthenticated,
                 let currentUser = serverAuth.currentUser else { return }
           
           serverAuth.fetchUserVerificationStatus(userId: currentUser.id) { isVerified in
               guard let isVerified = isVerified else { return }
               
               DispatchQueue.main.async {
                   // Frissítsd a lokális usert ha változott a verified státusz
                   if let currentUser = serverAuth.currentUser,
                      currentUser.isVerified != isVerified {
                       
                       var updatedUser = currentUser
                       updatedUser.isVerified = isVerified
                       serverAuth.currentUser = updatedUser
                       
                       // Értesítsd a usermanager-t is
                       if userManager.currentUser?.id == updatedUser.id {
                           userManager.currentUser = updatedUser
                       }
                       
                       print("🔄 Verified státusz frissítve: \(isVerified)")
                   }
               }
           }
       }
       
       // MARK: - Hitelesítés kezelése (admin funkció)
       private func showVerificationManagement() {
           // Itt lehet navigálni egy admin felületre
           // Jelenleg csak logoljuk
           print("🔧 Admin: Hitelesítés kezelése")
       }
    // MARK: - Helper Methods
    private func getDisplayUser() -> User? {
        // Prioritizáljuk a szerver adatokat, ha vannak
        if let serverUser = serverAuth.currentUser {
            print("🔍 DEBUG: Szerver user - Verified: \(serverUser.isVerified), Email: \(serverUser.email)")
            return serverUser
        } else {
            print("🔍 DEBUG: Lokális user - Verified: \(userManager.currentUser?.isVerified ?? false), Email: \(userManager.currentUser?.email ?? "N/A")")
            return userManager.currentUser
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd. HH:mm"
        formatter.locale = Locale(identifier: "hu_HU")
        return formatter.string(from: date)
    }
    
    private func userRoleDisplayName(_ role: UserRole) -> String {
        switch role {
        case .client:
            return "Ügyfél"
        case .serviceProvider:
            return "Szolgáltató"
        case .admin:
            return "Admin"
        }
    }
    
    private func userStatusDisplayName(_ status: UserStatus) -> String {
        switch status {
        case .pending:
            return "Függőben"
        case .active:
            return "Aktív"
        case .suspended:
            return "Felfüggesztve"
        case .deleted:
            return "Törölve"
        }
    }
    
    private func refreshUserData() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Várj egy kicsit a jobb UX-ért
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        serverAuth.refreshCurrentUser { success in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    print("✅ User adatok frissítve a szerverről")
                    self.lastRefreshTime = Date()
                    
                    // Profilkép újratöltése is
                    self.loadProfileImage()
                } else {
                    print("❌ User adatok frissítése sikertelen")
                }
            }
        }
    }
    
    private func loadUserData() {
        isLoading = true
        
        if UserDefaults.standard.bool(forKey: "isLoggedIn") {
            // Használd az új refreshCurrentUser-t helyette
            serverAuth.refreshCurrentUser { success in
                self.isLoading = false
                if success {
                    print("✅ User adatok betöltve - Verified: \(self.serverAuth.currentUser?.isVerified ?? false)")
                } else {
                    print("❌ User adatok betöltése sikertelen")
                    // Fallback: régi autoLogin
                    self.serverAuth.autoLogin { _ in }
                }
            }
        } else {
            isLoading = false
        }
    }
    
    private func refreshData() async {
        isLoading = true
        
        // Szimulált hálózati késleltetés
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Frissíti a szerver adatokat
        if serverAuth.isAuthenticated {
            serverAuth.autoLogin { success in
                isLoading = false
                if success {
                    print("✅ Adatok frissítve a szerverről")
                }
            }
        } else {
            isLoading = false
        }
    }
    
    // MARK: - Helper Methods
    private func logout() {
        // Szerver kijelentkezés
        serverAuth.logout()
        
        // Lokális kijelentkezés
        userManager.logout()
        
        // UserDefaults reset
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        
        // Visszadobás a LoginView-ra
        // Ez automatikusan megtörténik, mivel a userManager.isAuthenticated false lesz
        // és a ContentView figyeli ezt az állapotot
        print("✅ Sikeres kijelentkezés")
    }
    
    
    // MARK: - Profilkép betöltése
    private func loadProfileImage() {
        serverAuth.fetchProfileImage { imageData in
            if let imageData = imageData {
                self.profileImageData = imageData
            }
        }
    }

    // MARK: - Profilkép feltöltése
    private func uploadProfileImage() {
        guard let imageData = profileImageData else { return }
        
        serverAuth.uploadProfileImage(imageData) { success in
            if success {
                print("✅ Profilkép sikeresen feltöltve")
            } else {
                print("❌ Profilkép feltöltése sikertelen")
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userManager: UserManager
    @StateObject private var serverAuth = ServerAuthManager.shared
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var phoneNumber: String = ""
    @State private var city: String = ""
    @State private var country: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Alapadatok").font(.custom("Jellee", size: 16))) {
                    
                    VStack{
                        TextField("Név", text: $name)
                            .font(.custom("Lexend", size: 16))
                        .foregroundStyle(.black)
                        .underlineTextField()
                        
                        
                        TextField("Email", text: $email)
                            .font(.custom("Lexend", size: 16))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .foregroundStyle(.black)
                            .underlineTextField()

                        TextField("Felhasználónév", text: $username)
                            .font(.custom("Lexend", size: 16))
                            .autocapitalization(.none)
                            .foregroundStyle(.black)
                            .underlineTextField()

                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .listRowBackground(Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                    .foregroundColor(.DesignSystem.fokekszin)
                    .font(.custom("Lexend", size: 18))
                    .accentColor(.DesignSystem.fokekszin)
                    .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
                    .padding(4)
                }
                
                Section(header: Text("Elérhetőség").font(.custom("Jellee", size: 16))) {
                    
                    VStack{
                        TextField("Telefonszám", text: $phoneNumber)
                            .font(.custom("Lexend", size: 16))
                            .keyboardType(.phonePad)
                            .foregroundStyle(.black)
                            .underlineTextField()
                        
                        TextField("Város", text: $city)
                            .font(.custom("Lexend", size: 16))
                            .foregroundStyle(.black)
                            .underlineTextField()
                        
                        TextField("Ország", text: $country)
                            .font(.custom("Lexend", size: 16))
                            .foregroundStyle(.black)
                            .underlineTextField()
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .listRowBackground(Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                    .foregroundColor(.DesignSystem.fokekszin)
                    .font(.custom("Lexend", size: 18))
                    .accentColor(.DesignSystem.fokekszin)
                    .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
                    .padding(4)
                }
                
                Section(header: Text("Bemutatkozás").font(.custom("Jellee", size: 16))) {
                    TextEditor(text: $bio)
                        .font(.custom("Lexend", size: 16))
                        .frame(minHeight: 100)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .listRowBackground(Color.clear)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                        .foregroundColor(.DesignSystem.fokekszin)
                        .font(.custom("Lexend", size: 18))
                        .accentColor(.DesignSystem.fokekszin)
                        .listRowInsets(EdgeInsets()) // Eltávolítja a default paddingot
                        .padding(4)
                }
            }
            
            .navigationTitle("Profil szerkesztése")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Mégse") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 17))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mentés") {
                        saveProfile()
                    }
                    .font(.custom("Lexend", size: 17))
                    .bold()
                }
            }
            .onAppear {
                loadCurrentUserData()
            }
        }
    }
    
    private func loadCurrentUserData() {
        if let user = userManager.currentUser {
            name = user.name
            email = user.email
            username = user.username
            bio = user.bio
            phoneNumber = user.phoneNumber ?? ""
            city = user.location.city
            country = user.location.country
        }
    }
    
    private func saveProfile() {
        // Profil mentése
        if var user = userManager.currentUser {
            user = user.updated(
                name: name,
                email: email,
                username: username,
                bio: bio,
                location: Location(city: city, country: country), phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
            )
            
            userManager.currentUser = user
            
            // Ha szerver kapcsolat van, itt lehetne API hívás is
            if serverAuth.isAuthenticated {
                print("📤 Profil frissítése a szerveren...")
            }
        }
        
        dismiss()
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.DesignSystem.fokekszin)
                .frame(width: 25)
            
            Text(title)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.custom("Lexend", size: 14))
                .bold()
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Server Users View
struct ServerUsersView: View {
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var serverUsers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Felhasználók betöltése...")
                        .font(.custom("Lexend", size: 16))
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Hiba történt")
                            .font(.custom("Jellee", size: 18))
                        Text(error)
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Újrapróbál") {
                            loadServerUsers()
                        }
                        .font(.custom("Lexend", size: 16))
                        .padding()
                        .background(Color.DesignSystem.fokekszin)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else if serverUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Nincsenek felhasználók")
                            .font(.custom("Jellee", size: 18))
                        Text("A szerveren még nem regisztráltak felhasználókat")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(serverUsers) { user in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(user.name)
                                    .font(.custom("Jellee", size: 18))
                                    .bold()
                                
                                Spacer()
                                
                                Text("ID: \(user.id.uuidString.prefix(8))...")
                                    .font(.custom("Lexend", size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("@\(user.username)")
                                    .font(.custom("Lexend", size: 14))
                                    .foregroundColor(.blue)
                                
                                Text("•")
                                    .foregroundColor(.secondary)
                                
                                if let age = user.age {
                                    Text("\(age) év")
                                        .font(.custom("Lexend", size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text(user.email)
                                .font(.custom("Lexend", size: 12))
                                .foregroundColor(.secondary)
                            
                            if let createdAt = user.createdAt {
                                Text("Regisztrálva: \(formatDate(createdAt))")
                                    .font(.custom("Lexend", size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .navigationTitle("Szerver Felhasználók")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kész") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 17))
                }
            }
        }
        .onAppear {
            loadServerUsers()
        }
    }
    
    private func loadServerUsers() {
        isLoading = true
        errorMessage = nil
        
        // Jelenleg csak a lokális adatokat jelenítjük meg
        // A jövőben itt lehet API hívás a /api/auth/users endpoint-hoz
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let currentUser = serverAuth.currentUser {
                self.serverUsers = [currentUser]
            } else {
                self.errorMessage = "Nincs elérhető szerver adat"
            }
            self.isLoading = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd. HH:mm"
        formatter.locale = Locale(identifier: "hu_HU")
        return formatter.string(from: date)
    }
}


// ImagePicker.swift - Új fájl
import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    var onImageSelected: (() -> Void)?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, error in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        // Tömörítjük a képet
                        if let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                            self.parent.imageData = compressedData
                            self.parent.onImageSelected?()
                        }
                    }
                }
            }
        }
    }
}

// ProfileImage.swift - Új fájl
import SwiftUI

struct ProfileImage: View {
    let imageData: Data?
    let size: CGFloat
    let showEditButton: Bool
    let onEditTapped: (() -> Void)?
    
    @StateObject private var serverAuth = ServerAuthManager.shared
    @State private var localImageData: Data?
    
    init(
        imageData: Data? = nil,
        size: CGFloat = 60,
        showEditButton: Bool = false,
        onEditTapped: (() -> Void)? = nil
    ) {
        self.imageData = imageData
        self.size = size
        self.showEditButton = showEditButton
        self.onEditTapped = onEditTapped
    }
    
    var body: some View {
        ZStack {
            if let imageData = getImageData(),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                if let user = serverAuth.currentUser, !user.name.isEmpty {
                    Text(user.name.prefix(1).uppercased())
                        .font(.custom("Jellee", size: size * 0.4))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: size * 0.6))
                        .foregroundColor(.white)
                }
            }
        }
        .overlay(editButtonOverlay)
        .onAppear {
            loadProfileImage()
        }
    }
    
    private var editButtonOverlay: some View {
        Group {
            if showEditButton {
                Button(action: {
                    onEditTapped?()
                }) {
                    Image(systemName: "camera.badge.ellipsis.fill")
                        .font(.system(size: size * 0.25))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .offset(x: size * 0.35, y: size * 0.35)
            }
        }
    }
    
    private func getImageData() -> Data? {
        return imageData ?? localImageData
    }
    
    private func loadProfileImage() {
        // Ha már kapunk imageData-t, ne töltünk újra
        if imageData != nil { return }
        
        // Lokális gyorsítótár
        if let localData = loadLocalProfileImage() {
            self.localImageData = localData
            return
        }
        
        // Szerverről töltés
        serverAuth.fetchProfileImage { imageData in
            if let imageData = imageData {
                DispatchQueue.main.async {
                    self.localImageData = imageData
                    self.saveLocalProfileImage(imageData)
                }
            }
        }
    }
    
    private func saveLocalProfileImage(_ imageData: Data) {
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            UserDefaults.standard.set(imageData, forKey: "localProfileImage_\(userId)")
        }
    }
    
    private func loadLocalProfileImage() -> Data? {
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            return UserDefaults.standard.data(forKey: "localProfileImage_\(userId)")
        }
        return nil
    }
}
// MARK: - Preview
struct ProfilView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilView()
            .environmentObject(UserManager.shared)
    }
}
