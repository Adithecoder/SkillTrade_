//
//  AdminView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 2024.12.21.
//

import SwiftUI
import DesignSystem

struct AdminView: View {
    @StateObject private var serverAuth = ServerAuthManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var serverUsers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var refreshID = UUID()
    
    
    @State private var showingEditUser = false
    @State private var showingDeleteAlert = false
    @State private var showingSuspendAlert = false
    @State private var selectedUserForEdit: User?
    @State private var selectedUserForAction: User?
    @State private var navigationPath = NavigationPath()
    // Statisztikák
    @State private var totalUsers = 0
    @State private var verifiedUsers = 0
    @State private var pendingUsers = 0
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab picker
                tabPickerSection
                
                // Content
                tabContentSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))

            .id(refreshID) // Force refresh when data changes
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Admin Panel")
                        .font(.custom("Jellee", size: 28))
                        .bold()
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("Felhasználók kezelése")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Frissítés gomb
                Button(action: {
                    loadAllUsersFromServer()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                }
                .disabled(isLoading)
                
                Button(action: {
                    testToken()
                }) {
                    Image(systemName: "key")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            
            
            }
            .padding(.horizontal)
            
            // Gyors statisztikák
            statsGridSection
        }
        .padding(.vertical)
        .background(Color.white)
    }
    private func testToken() {
        print("🔐 TOKEN TEST")
        print("🔐 UserDefaults authToken: \(UserDefaults.standard.string(forKey: "authToken") != nil ? "EXISTS" : "MISSING")")
        print("🔐 UserDefaults userId: \(UserDefaults.standard.string(forKey: "userId") ?? "MISSING")")
        print("🔐 UserDefaults isLoggedIn: \(UserDefaults.standard.bool(forKey: "isLoggedIn"))")
        
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            print("🔐 Token length: \(token.count)")
            print("🔐 Token prefix: \(token.prefix(20))...")
        }
    }
    // MARK: - Stats Grid
    private var statsGridSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Összes",
                value: "\(totalUsers)",
                color: .blue,
                icon: "person.3.fill"
            )
            
            StatCard(
                title: "Verified",
                value: "\(verifiedUsers)",
                color: .green,
                icon: "checkmark.seal.fill"
            )
            
            StatCard(
                title: "Függőben",
                value: "\(pendingUsers)",
                color: .orange,
                icon: "clock.fill"
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Tab Picker
    private var tabPickerSection: some View {
        Picker("Válassz nézetet", selection: $selectedTab) {
            Text("Összes").tag(0)
            Text("Hitelesítés").tag(1)
            Text("Felhasználók").tag(2)  // Új tab
            Text("Statisztikák").tag(2)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Tab Content
    private var tabContentSection: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                switch selectedTab {
                case 0:
                    allUsersView
                case 1:
                    verificationView
                case 2:
                    userManagementView
                case 3:
                    statisticsView
                default:
                    allUsersView
                }
            }
        }
    }
    
    // MARK: - All Users View
    private var allUsersView: some View {
        List {
            if filteredUsers.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredUsers) { user in
                    UserRow(
                        user: user,
                        onVerifyToggle: { isVerified in
                            updateUserVerificationStatus(user: user, isVerified: isVerified)
                        }
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
        .searchable(text: $searchText, prompt: "Keresés név vagy email alapján...")
    }
    
    // MARK: - Verification View
    private var verificationView: some View {
        List {
            Section {
                ForEach(pendingVerificationUsers) { user in
                    VerificationUserRow(
                        user: user,
                        onApprove: {
                            updateUserVerificationStatus(user: user, isVerified: true)
                        },
                        onReject: {
                            updateUserVerificationStatus(user: user, isVerified: false)
                        }
                    )
                }
            } header: {
                Text("Hitelesítésre vár (\(pendingVerificationUsers.count))")
                    .font(.custom("Jellee", size: 16))
                    .foregroundColor(.orange)
            }
            
            Section {
                ForEach(verifiedUsersList) { user in
                    VerifiedUserRow(
                        user: user,
                        onRevoke: {
                            updateUserVerificationStatus(user: user, isVerified: false)
                        }
                    )
                }
            } header: {
                Text("Hitelesített felhasználók (\(verifiedUsersList.count))")
                    .font(.custom("Jellee", size: 16))
                    .foregroundColor(.green)
            }
        }
        .listStyle(GroupedListStyle())
    }
    // MARK: - User Management View
    // MARK: - User Management View (NavigationLink verzió)
    private var userManagementView: some View {
        List {
            Section {
                ForEach(serverUsers) { user in
                    NavigationLink(destination: AdminUserEditView(
                        user: user,
                        onUserUpdated: { updatedUser in
                            // Frissítsd a lokális listát
                            if let index = serverUsers.firstIndex(where: { $0.id == updatedUser.id }) {
                                serverUsers[index] = updatedUser
                                calculateStats()
                                refreshID = UUID()
                            }
                        }
                    )) {
                        UserManagementRow(
                            user: user,
                            onSuspend: { suspendUser(user) },
                            onDelete: { deleteUser(user) }
                        )
                    }
                }
            } header: {
                Text("Összes felhasználó (\(serverUsers.count))")
                    .font(.custom("Jellee", size: 16))
                    .foregroundColor(.primary)
            }
        }
        .listStyle(GroupedListStyle())
        .alert("Megerősítés szükséges", isPresented: $showingDeleteAlert) {
            if let userToDelete = selectedUserForAction {
                Button("Törlés", role: .destructive) {
                    confirmDeleteUser(userToDelete)
                }
                Button("Mégse", role: .cancel) {}
            }
        } message: {
            if let user = selectedUserForAction {
                Text("Biztosan törölni szeretnéd \(user.name) fiókját? Ez a művelet nem visszavonható!")
            }
        }
        .alert("Felfüggesztés", isPresented: $showingSuspendAlert) {
            if let userToSuspend = selectedUserForAction {
                if userToSuspend.status == .suspended {
                    Button("Aktiválás") {
                        confirmSuspendUser(userToSuspend, suspended: false)
                    }
                    Button("Mégse", role: .cancel) {}
                } else {
                    Button("Felfüggesztés", role: .destructive) {
                        confirmSuspendUser(userToSuspend, suspended: true)
                    }
                    Button("Mégse", role: .cancel) {}
                }
            }
        } message: {
            if let user = selectedUserForAction {
                if user.status == .suspended {
                    Text("Aktiválod \(user.name) fiókját?")
                } else {
                    Text("Felfüggeszted \(user.name) fiókját?")
                }
            }
        }
    }
    
    // MARK: - Statistics View
    private var statisticsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Fő statisztikák kártyák
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatsCard(
                        title: "Összes felhasználó",
                        value: "\(totalUsers)",
                        icon: "person.3.fill",
                        color: .blue
                    )
                    
                    StatsCard(
                        title: "Hitelesítettek",
                        value: "\(verifiedUsers)",
                        icon: "checkmark.seal.fill",
                        color: .green
                    )
                    
                    StatsCard(
                        title: "Függőben",
                        value: "\(pendingUsers)",
                        icon: "clock.fill",
                        color: .orange
                    )
                    
                    StatsCard(
                        title: "Adminok",
                        value: "\(adminUsersCount)",
                        icon: "person.badge.shield.checkmark.fill",
                        color: .purple
                    )
                }
                .padding(.horizontal)
                
                // Felhasználói eloszlás
                VStack(alignment: .leading, spacing: 12) {
                    Text("Felhasználói eloszlás")
                        .font(.custom("Jellee", size: 18))
                        .bold()
                        .padding(.horizontal)
                    
                    UserDistributionChart(users: serverUsers)
                        .frame(height: 200)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - UI Components
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Adatok betöltése...")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
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
                .padding(.horizontal)
            
            Button("Próbáld újra!") {
                loadAllUsersFromServer()
            }
            .font(.custom("Lexend", size: 16))
            .padding()
            .background(Color.DesignSystem.fokekszin)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Nincsenek felhasználók")
                .font(.custom("Jellee", size: 18))
            
            Text("A szerveren még nem regisztráltak felhasználókat")
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("vagy frissítsd az Admin Panelt")
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    // MARK: - Computed Properties
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return serverUsers
        } else {
            return serverUsers.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var pendingVerificationUsers: [User] {
        serverUsers.filter { !$0.isVerified }
    }
    
    private var verifiedUsersList: [User] {
        serverUsers.filter { $0.isVerified }
    }
    
    private var adminUsersCount: Int {
        serverUsers.filter { $0.userRole == .admin }.count
    }
    
    // MARK: - API Methods
    // AdminView.swift - Részletes header debug
    private func loadAllUsersFromServer() {
        isLoading = true
        errorMessage = nil
        
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            errorMessage = "Nincs érvényes token. Jelentkezz be újra."
            isLoading = false
            print("❌ ADMIN - No token found in UserDefaults")
            return
        }
        
        print("🔐 ADMIN - Token found: \(token.prefix(20))...")
        
        let url = URL(string: "\(serverAuth.baseURL)/auth/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Részletes debug
        print("👥 ADMIN - ===== REQUEST DEBUG =====")
        print("👥 ADMIN - URL: \(url.absoluteString)")
        print("👥 ADMIN - Method: GET")
        print("👥 ADMIN - Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("👥 ADMIN - ==========================")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ ADMIN - Network error: \(error)")
                    self.errorMessage = "Hálózati hiba: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ ADMIN - Invalid response")
                    self.errorMessage = "Érvénytelen válasz"
                    return
                }
                
                print("📡 ADMIN - Response status: \(httpResponse.statusCode)")
                print("📡 ADMIN - Response headers: \(httpResponse.allHeaderFields)")
                
                guard let data = data else {
                    self.errorMessage = "Nincs válasz adat"
                    return
                }
                
                // Debug: nézzük meg a nyers választ
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 ADMIN - Raw server response: \(responseString.prefix(500))...") // Csak az első 500 karakter
                }
                
                // Ellenőrizzük a status code-ot
                if httpResponse.statusCode == 401 {
                    self.errorMessage = "Hozzáférés megtagadva. Token érvénytelen vagy lejárt."
                    return
                } else if httpResponse.statusCode == 403 {
                    self.errorMessage = "Nincs admin jogosultságod."
                    return
                } else if httpResponse.statusCode != 200 {
                    self.errorMessage = "Szerver hiba: \(httpResponse.statusCode)"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ ADMIN - JSON structure: \(json.keys)")
                        
                        if let usersArray = json["users"] as? [[String: Any]] {
                            print("✅ ADMIN - \(usersArray.count) users found")
                            
                            var parsedUsers: [User] = []
                            for userDict in usersArray {
                                print("👤 ADMIN - User data: \(userDict)")
                                if let user = self.parseSimpleUser(userDict) {
                                    parsedUsers.append(user)
                                }
                            }
                            
                            self.serverUsers = parsedUsers
                            self.calculateStats()
                            self.refreshID = UUID()
                            
                            print("✅ ADMIN - \(parsedUsers.count) users loaded successfully")
                        } else {
                            self.errorMessage = "Hibás válasz formátum - nincs 'users' mező"
                        }
                    }
                } catch {
                    print("❌ ADMIN - JSON parse error: \(error)")
                    self.errorMessage = "Hiba az adatok feldolgozásában: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    
    private func continueLoadingUsers() {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
               errorMessage = "Nincs érvényes token. Jelentkezz be újra."
               isLoading = false
               print("❌ ADMIN - No token found in UserDefaults")
               
               // Debug: nézzük meg, mi van a UserDefaults-ban
               let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
               print("🔍 USERDEFAULTS KEYS: \(allKeys.filter { $0.contains("auth") || $0.contains("token") || $0.contains("user") })")
               return
           }
        
        print("🔐 ADMIN - Token found: \(token.prefix(20))...")

        let url = URL(string: "\(serverAuth.baseURL)/auth/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 API hívás: \(url)")
        print("🔑 Token: \(token.prefix(10))...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Hálózati hiba: \(error)")
                    self.errorMessage = "Hálózati hiba: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Érvénytelen válasz"
                    return
                }
                
                print("📡 Status code: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    self.errorMessage = "Nincs válasz adat"
                    return
                }
                
                // Debug: nézzük meg a nyers választ
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📥 Raw server response: \(responseString)")
                }
                
                // Ellenőrizzük a status code-ot
                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Szerver hiba: \(httpResponse.statusCode)"
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ JSON struktúra: \(json.keys)")
                        
                        if let usersArray = json["users"] as? [[String: Any]] {
                            print("✅ \(usersArray.count) user található")
                            
                            var parsedUsers: [User] = []
                            for userDict in usersArray {
                                print("👤 User data: \(userDict)")
                                if let user = self.parseSimpleUser(userDict) {
                                    parsedUsers.append(user)
                                }
                            }
                            
                            self.serverUsers = parsedUsers
                            self.calculateStats()
                            self.refreshID = UUID()
                            
                            print("✅ \(parsedUsers.count) felhasználó betöltve")
                        } else {
                            self.errorMessage = "Hibás válasz formátum - nincs 'users' mező"
                        }
                    }
                } catch {
                    print("❌ JSON parse error: \(error)")
                    self.errorMessage = "Hiba az adatok feldolgozásában: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func parseSimpleUser(_ userDict: [String: Any]) -> User? {
        print("🔍 Parsing user: \(userDict)")
        
        // ID kezelés - SQLite integer ID-t kell stringgé alakítani
        let id: UUID
        if let idInt = userDict["id"] as? Int {
            // SQLite integer ID - generáljunk belőle UUID-t
            id = UUID()
        } else if let idString = userDict["id"] as? String, let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            print("❌ Invalid ID: \(userDict["id"] ?? "nil")")
            return nil
        }
        
        guard let name = userDict["name"] as? String,
              let email = userDict["email"] as? String,
              let username = userDict["username"] as? String else {
            print("❌ Missing required fields")
            return nil
        }
        
        let age = userDict["age"] as? Int ?? 0
        let isVerified = userDict["isVerified"] as? Bool ?? false
        
        // Alap user létrehozása
        return User(
            id: id,
            name: name,
            email: email,
            username: username,
            bio: "",
            rating: 0.0,
            reviews: [],
            location: Location(city: "", country: ""),
            skills: [],
            pricing: [],
            isVerified: isVerified,
            servicesOffered: "",
            servicesAdvertised: "",
            userRole: .client,
            status: .active,
            phoneNumber: nil,
            xp: 0,
            age: age,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func updateUserVerificationStatus(user: User, isVerified: Bool) {
        isLoading = true
        
        serverAuth.updateUserVerificationStatus(user: user, isVerified: isVerified) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Lokális frissítés
                    if let index = self.serverUsers.firstIndex(where: { $0.id == user.id }) {
                        var updatedUser = user
                        updatedUser.isVerified = isVerified
                        self.serverUsers[index] = updatedUser
                        self.calculateStats()
                        self.refreshID = UUID()
                        
                        print("✅ \(user.name) hitelesítési státusza frissítve: \(isVerified)")
                    }
                } else {
                    self.errorMessage = "Nem sikerült frissíteni a hitelesítési státuszt"
                }
            }
        }
    }
    
    private func refreshData() async {
        // Várj egy kicsit, hogy ne legyen azonnali újrahívás
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 másodperc
        
        await MainActor.run {
            loadAllUsersFromServer()
        }
    }
    
    // MARK: - User Management Methods
    private func showEditUser(_ user: User) {
        selectedUserForEdit = user
        showingEditUser = true
    }

    private func suspendUser(_ user: User) {
        selectedUserForAction = user
        showingSuspendAlert = true
    }

    private func deleteUser(_ user: User) {
        selectedUserForAction = user
        showingDeleteAlert = true
    }

    private func confirmSuspendUser(_ user: User, suspended: Bool) {
        isLoading = true
        
        serverAuth.suspendUser(userId: user.id, suspended: suspended) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Lokális frissítés
                    if let index = self.serverUsers.firstIndex(where: { $0.id == user.id }) {
                        var updatedUser = user
                        updatedUser.status = suspended ? .suspended : .active
                        self.serverUsers[index] = updatedUser
                        self.calculateStats()
                        self.refreshID = UUID()
                        
                        print("✅ \(user.name) státusza frissítve: \(suspended ? "felfüggesztve" : "aktiválva")")
                    }
                } else {
                    self.errorMessage = "Nem sikerült frissíteni a felhasználó státuszát"
                }
            }
        }
    }

    // AdminView.swift - Javított törlés
    private func confirmDeleteUser(_ user: User) {
        isLoading = true
        
        // Használd az email alapú törlést
        serverAuth.deleteUserByEmail(userEmail: user.email) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    // Lokális eltávolítás
                    self.serverUsers.removeAll { $0.id == user.id }
                    self.calculateStats()
                    self.refreshID = UUID()
                    
                    print("✅ \(user.name) fiókja törölve (email: \(user.email))")
                } else {
                    self.errorMessage = "Nem sikerült törölni a felhasználót"
                }
            }
        }
    }

    private func updateUserData(_ user: User) {
        isLoading = true
        
        let updates: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "username": user.username,
            "age": user.age ?? 0,
            "userRole": user.userRole.rawValue,
            "isVerified": user.isVerified
        ]
        
        serverAuth.updateUser(userId: user.id, updates: updates) { success, updatedUser in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success, let updatedUser = updatedUser {
                    // Lokális frissítés
                    if let index = self.serverUsers.firstIndex(where: { $0.id == user.id }) {
                        self.serverUsers[index] = updatedUser
                        self.calculateStats()
                        self.refreshID = UUID()
                        
                        print("✅ \(user.name) adatai frissítve")
                    }
                } else {
                    self.errorMessage = "Nem sikerült frissíteni a felhasználó adatait"
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateStats() {
        totalUsers = serverUsers.count
        verifiedUsers = serverUsers.filter { $0.isVerified }.count
        pendingUsers = serverUsers.filter { !$0.isVerified }.count
    }
    
    private func parseUserFromServer(_ userDict: [String: Any]) -> User? {
        guard let idString = userDict["id"] as? String ?? userDict["_id"] as? String,
              let id = UUID(uuidString: idString),
              let name = userDict["name"] as? String,
              let email = userDict["email"] as? String,
              let username = userDict["username"] as? String else {
            return nil
        }
        
        let bio = userDict["bio"] as? String ?? ""
        let rating = userDict["rating"] as? Double ?? 0.0
        let isVerified = userDict["isVerified"] as? Bool ?? false
        let age = userDict["age"] as? Int
        let userRoleString = userDict["userRole"] as? String ?? "client"
        let statusString = userDict["status"] as? String ?? "pending"
        
        // Location parsing
        let city = userDict["location_city"] as? String ?? ""
        let country = userDict["location_country"] as? String ?? ""
        let location = Location(city: city, country: country)
        
        // User role parsing
        let userRole: UserRole
        switch userRoleString.lowercased() {
        case "admin":
            userRole = .admin
        case "serviceprovider", "service_provider":
            userRole = .serviceProvider
        default:
            userRole = .client
        }
        
        // Status parsing
        let status: UserStatus
        switch statusString.lowercased() {
        case "active":
            status = .active
        case "suspended":
            status = .suspended
        default:
            status = .pending
        }
        
        return User(
            id: id,
            name: name,
            email: email,
            username: username,
            bio: bio,
            rating: rating,
            reviews: [],
            location: location,
            skills: [],
            pricing: [],
            isVerified: isVerified,
            servicesOffered: userDict["servicesOffered"] as? String ?? "",
            servicesAdvertised: userDict["servicesAdvertised"] as? String ?? "",
            userRole: userRole,
            status: status,
            phoneNumber: userDict["phoneNumber"] as? String,
            xp: userDict["xp"] as? Int ?? 0,
            age: age,
            createdAt: parseDate(userDict["createdAt"] as? String),
            updatedAt: parseDate(userDict["updatedAt"] as? String)
        )
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }
}
struct UserManagementRow: View {
    let user: User
    let onSuspend: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profil ikon
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.system(size: 16))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.custom("Lexend", size: 16))
                        .bold()
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                
                HStack(spacing: 8) {
                    Text(user.userRole == .admin ? "Admin" :
                         user.userRole == .serviceProvider ? "Szolgáltató" : "Ügyfél")
                        .font(.custom("Lexend", size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.2))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    
                    Text(statusText)
                        .font(.custom("Lexend", size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                    
                    if let age = user.age {
                        Text("\(age) év")
                            .font(.custom("Lexend", size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(user.email)
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.secondary)
                
                Text("@\(user.username)")
                    .font(.custom("Lexend", size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Művelet gombok
            HStack(spacing: 12) {
//                Button(action: onEdit) {
//                    VStack {
//                        Image(systemName: //"pencil.circle.fill")
//                            .font(.system(size: 20))
//                            .foregroundColor(.blue)
//                        Text("Szerkesztés")
//                            .font(.custom("Lexend", size: //10))
//                            .foregroundColor(.blue)
//                    }
//                }
//                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onSuspend) {
                    VStack {
                        Image(systemName: user.status == .suspended ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(user.status == .suspended ? .green : .orange)
                        Text(user.status == .suspended ? "Aktiválás" : "Felfüggesztés")
                            .font(.custom("Lexend", size: 10))
                            .foregroundColor(user.status == .suspended ? .green : .orange)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onDelete) {
                    VStack {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        Text("Törlés")
                            .font(.custom("Lexend", size: 10))
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private var roleColor: Color {
        switch user.userRole {
        case .admin: return .red
        case .serviceProvider: return .green
        case .client: return .blue
        }
    }
    
    private var statusColor: Color {
        switch user.status {
        case .active: return .green
        case .suspended: return .red
        case .pending: return .orange
        case .deleted:
            return.indigo
        }
    }
    
    private var statusIcon: String {
        switch user.status {
        case .active: return "person.circle.fill"
        case .suspended: return "person.crop.circle.badge.xmark"
        case .pending: return "person.crop.circle.badge.clock"
        case .deleted:
            return "trash.circle"
        }
    }
    
    private var statusText: String {
        switch user.status {
        case .active: return "Aktív"
        case .suspended: return "Felfüggesztve"
        case .pending: return "Függőben"
        case .deleted:
            return "Törölve"
        }
    }
}


import SwiftUI

struct AdminUserEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var serverAuth = ServerAuthManager.shared
    
    let user: User
    var onUserUpdated: ((User) -> Void)?
    
    @State private var editedName: String
    @State private var editedEmail: String
    @State private var editedUsername: String
    @State private var editedAge: Int
    @State private var editedUserRole: UserRole
    @State private var editedIsVerified: Bool
    @State private var editedStatus: UserStatus
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var showDeleteConfirmation = false
    
    init(user: User, onUserUpdated: ((User) -> Void)? = nil) {
        self.user = user
        self.onUserUpdated = onUserUpdated
        
        _editedName = State(initialValue: user.name)
        _editedEmail = State(initialValue: user.email)
        _editedUsername = State(initialValue: user.username)
        _editedAge = State(initialValue: user.age ?? 0)
        _editedUserRole = State(initialValue: user.userRole)
        _editedIsVerified = State(initialValue: user.isVerified)
        _editedStatus = State(initialValue: user.status)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Frissítés...")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("Alap információk")) {
                    TextField("Név", text: $editedName)
                        .font(.custom("Lexend", size: 16))
                    
                    TextField("Email", text: $editedEmail)
                        .font(.custom("Lexend", size: 16))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Felhasználónév", text: $editedUsername)
                        .font(.custom("Lexend", size: 16))
                        .autocapitalization(.none)
                    
                    Stepper("Életkor: \(editedAge)", value: $editedAge, in: 16...100)
                        .font(.custom("Lexend", size: 16))
                }
                
                Section(header: Text("Jogosultságok és státusz")) {
                    Picker("Felhasználói szerepkör", selection: $editedUserRole) {
                        Text("Ügyfél").tag(UserRole.client)
                        Text("Szolgáltató").tag(UserRole.serviceProvider)
                        Text("Admin").tag(UserRole.admin)
                    }
                    .font(.custom("Lexend", size: 16))
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Picker("Fiók státusza", selection: $editedStatus) {
                        Text("Aktív").tag(UserStatus.active)
                        Text("Felfüggesztve").tag(UserStatus.suspended)
                        Text("Függőben").tag(UserStatus.pending)
                    }
                    .font(.custom("Lexend", size: 16))
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Toggle("Hitelesített felhasználó", isOn: $editedIsVerified)
                        .font(.custom("Lexend", size: 16))
                }
                
                Section(header: Text("Jelenlegi információk")) {
                    InfoRowAdmin(title: "Felhasználó ID", value: user.id.uuidString.prefix(8) + "...")
                    InfoRowAdmin(title: "Regisztrálva", value: formatDate(user.createdAt))
                    InfoRowAdmin(title: "Utolsó módosítás", value: formatDate(user.updatedAt))
                    InfoRowAdmin(title: "XP pontok", value: "\(user.xp)")
                }
                
                Section(header: Text("Veszélyes műveletek")) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Felhasználó törlése")
                        }
                    }
                    .font(.custom("Lexend", size: 16))
                }
            }
            .navigationTitle("Felhasználó szerkesztése")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Mégse") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.custom("Lexend", size: 16))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mentés") {
                        saveChanges()
                    }
                    .font(.custom("Lexend", size: 16))
                    .bold()
                    .disabled(isLoading)
                }
            }
            .alert("Sikeres mentés", isPresented: $showSuccessAlert) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("A felhasználó adatai sikeresen frissítve.")
            }
            .alert("Felhasználó törlése", isPresented: $showDeleteConfirmation) {
                Button("Törlés", role: .destructive) {
                    deleteUser()
                }
                Button("Mégse", role: .cancel) {}
            } message: {
                Text("Biztosan törölni szeretnéd \(user.name) fiókját? Ez a művelet nem visszavonható!")
            }
        }
    }
    
    private func saveChanges() {
        isLoading = true
        errorMessage = nil
        
        let updates: [String: Any] = [
            "name": editedName,
            "email": editedEmail,
            "username": editedUsername,
            "age": editedAge,
            "userRole": editedUserRole.rawValue,
            "isVerified": editedIsVerified,
            "status": editedStatus.rawValue
        ]
        
        serverAuth.updateUser(userId: user.id, updates: updates) { success, updatedUser in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success, let updatedUser = updatedUser {
                    self.showSuccessAlert = true
                    self.onUserUpdated?(updatedUser)
                    print("✅ \(user.name) adatai frissítve")
                } else {
                    self.errorMessage = "Nem sikerült frissíteni a felhasználó adatait"
                }
            }
        }
    }
    
    private func deleteUser() {
        isLoading = true
        errorMessage = nil
        
        serverAuth.deleteUser(userId: user.id) { success in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.presentationMode.wrappedValue.dismiss()
                    print("✅ \(self.user.name) fiókja törölve")
                } else {
                    self.errorMessage = "Nem sikerült törölni a felhasználót"
                }
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Ismeretlen" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd. HH:mm"
        return formatter.string(from: date)
    }
}

struct InfoRowAdmin: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AdminUserEditView(
        user: User(
            id: UUID(),
            name: "Teszt Felhasználó",
            email: "teszt@example.com",
            username: "tesztuser",
            bio: "",
            rating: 4.5,
            reviews: [],
            location: Location(city: "Budapest", country: "Magyarország"),
            skills: [],
            pricing: [],
            isVerified: true,
            servicesOffered: "",
            servicesAdvertised: "",
            userRole: .client,
            status: .active,
            phoneNumber: nil,
            xp: 100,
            age: 25,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
// MARK: - Supporting Views (Ugyanazok mint az előző verzióban, de most API-val)

struct UserRow: View {
    let user: User
    let onVerifyToggle: (Bool) -> Void
    
    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profilkép vagy inicial
            if isLoadingImage {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.DesignSystem.fokekszin.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.custom("Jellee", size: 16))
                            .foregroundColor(.DesignSystem.fokekszin)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.name)
                        .font(.custom("Lexend", size: 16))
                        .bold()
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                    }
                }
                
                HStack {
                    Text(user.userRole == .admin ? "Admin" :
                         user.userRole == .serviceProvider ? "Szolgáltató" : "Ügyfél")
                        .font(.custom("Lexend", size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.2))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    
                    if let age = user.age {
                        Text("\(age) év")
                            .font(.custom("Lexend", size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { user.isVerified },
                set: { onVerifyToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .onAppear {
            loadProfileImage()
        }
    }
    
    private var roleColor: Color {
        switch user.userRole {
        case .admin:
            return .red
        case .serviceProvider:
            return .green
        case .client:
            return .blue
        }
    }
    
    private func loadProfileImage() {
        isLoadingImage = true
        
        // Profilkép betöltése a szerverről
        ServerAuthManager.shared.fetchProfileImage { imageData in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                
                if let imageData = imageData,
                   let uiImage = UIImage(data: imageData) {
                    self.profileImage = uiImage
                }
            }
        }
    }
}

struct VerificationUserRow: View {
    @State private var profileImage: UIImage?
    @State private var isLoadingImage = false
    
    let user: User
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoadingImage {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.DesignSystem.fokekszin.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(user.name.prefix(1).uppercased())
                            .font(.custom("Jellee", size: 16))
                            .foregroundColor(.DesignSystem.fokekszin)
                    )
            }
            
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.custom("Lexend", size: 16))
                    .bold()
                
                Text(user.email)
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.secondary)
                
                if let createdAt = user.createdAt {
                    Text("Regisztrálva: \(formatDate(createdAt))")
                        .font(.custom("Lexend", size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
                
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadProfileImage()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd. HH:mm"
        return formatter.string(from: date)
    }
    
    private func loadProfileImage() {
            isLoadingImage = true
            
            // Profilkép betöltése a szerverről
            ServerAuthManager.shared.fetchProfileImage { imageData in
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    
                    if let imageData = imageData,
                       let uiImage = UIImage(data: imageData) {
                        self.profileImage = uiImage
                    }
                }
            }
        }
    }


struct VerifiedUserRow: View {
    let user: User
    let onRevoke: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.custom("Lexend", size: 16))
                    .bold()
                
                Text("@\(user.username)")
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.secondary)
                
                Text("Értékelés: \(String(format: "%.1f", user.rating))")
                    .font(.custom("Lexend", size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Visszavonás") {
                onRevoke()
            }
            .font(.custom("Lexend", size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(6)
        }
        .padding(.vertical, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.custom("Jellee", size: 18))
                    .bold()
                    .foregroundColor(color)
                
                Text(title)
                    .font(.custom("Lexend", size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.custom("Jellee", size: 24))
                    .bold()
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.custom("Lexend", size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct UserDistributionChart: View {
    let users: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Felhasználói szerepkörök")
                    .font(.custom("Lexend", size: 14))
                    .bold()
                
                Spacer()
            }
            
            let roleCounts = calculateRoleCounts()
            let total = users.count
            
            VStack(spacing: 8) {
                ForEach(roleCounts.sorted(by: { $0.value > $1.value }), id: \.key) { role, count in
                    HStack {
                        Text(roleDisplayName(role))
                            .font(.custom("Lexend", size: 12))
                            .frame(width: 80, alignment: .leading)
                        
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(roleColor(role))
                                .frame(width: geometry.size.width * CGFloat(count) / CGFloat(total))
                                .cornerRadius(4)
                        }
                        .frame(height: 20)
                        
                        Text("\(count)")
                            .font(.custom("Lexend", size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    private func calculateRoleCounts() -> [UserRole: Int] {
        var counts: [UserRole: Int] = [:]
        for user in users {
            counts[user.userRole, default: 0] += 1
        }
        return counts
    }
    
    private func roleDisplayName(_ role: UserRole) -> String {
        switch role {
        case .admin: return "Admin"
        case .serviceProvider: return "Szolgáltató"
        case .client: return "Ügyfél"
        }
    }
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return .red
        case .serviceProvider: return .green
        case .client: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    AdminView()
        .environmentObject(UserManager.shared)
}

#Preview("Loading State") {
    AdminView()
        .environmentObject(UserManager.shared)
}
