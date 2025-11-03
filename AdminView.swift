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
            }
            .padding(.horizontal)
            
            // Gyors statisztikák
            statsGridSection
        }
        .padding(.vertical)
        .background(Color.white)
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
    private func loadAllUsersFromServer() {
        isLoading = true
        errorMessage = nil
        
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            errorMessage = "Nincs érvényes token. Jelentkezz be újra."
            isLoading = false
            return
        }

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
