//
//  UserManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//


// UserManager.swift

// Your imports remain the same
import SwiftUI
import Combine
import GoogleSignIn
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - UserManager
class UserManager: ObservableObject {
    
    private let dbManager = DatabaseManager.shared
    
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthenticated = false
    @Published var isLoggedIn = false
    @Published var isGoogleSignIn = false
    @Published var user: User = .preview // Példa felhasználó
    
    private init() {}
    // Add mapping dictionary for QR codes
    private var qrCodeMappings: [String: UUID] = [:]
    
    // Make shared instance public
    public static let shared = UserManager()
    
    #if DEBUG
    // Add internal init for preview purposes
    internal init(preview: Bool = false) {
        if !preview {
            print("Debug UserManager: Initializing regular instance")
            loadPersistedData()
            if userWorks.isEmpty {
                loadTestData()
            }
            checkSavedLoginState()
        } else {
            print("Debug UserManager: Initializing preview instance")
        }
    }
    #else
    // Private init for release builds
    private init() {
        print("Debug UserManager: Initializing release instance")
        loadPersistedData()
        if userWorks.isEmpty {
            loadTestData()
        }
        checkSavedLoginState()
    }
    #endif
    

    
    // Add new published property for works
    @Published var userWorks: [WorkData] = [] {
        didSet {
            print("Debug UserManager: Works updated. Count: \(userWorks.count)")
            print("Debug UserManager: Work IDs: \(userWorks.map { $0.debugDescription })")
            debouncedPersist()
        }
    }
    
    // Add these properties
//    @Published var userRank: UserRank = .bronze
    @Published var completedWorks: Int = 0
    @Published var positiveRatings: Int = 0
    
    @Published var referralCode: String = ""
    @Published var referrals: [Referral] = []
    
    @Published var users: [User] = []
    
    var totalReferrals: Int { referrals.count }
    var successfulReferrals: Int { referrals.filter { $0.status == .completed }.count }
//    var earnedReferralCoins: Int { successfulReferrals * SkillCoin.Rewards.referralBonus }
    
//    var skillCoin: SkillCoin = .shared
    
    // Add new properties for gamification
    @Published var dailyStreak: Int = 0
    @Published var lastLoginDate: Date?
    @Published var dailyChallenges: [Challenge] = []
    @Published var achievements: [Achievement] = []
    
    // Add Challenge and Achievement structs
    struct Challenge: Codable, Identifiable {
        let id: UUID
        let title: String
        let description: String
        let reward: Int
        var isCompleted: Bool
    }
    
    struct Achievement: Codable, Identifiable {
        let id: UUID
        let title: String
        let description: String
        let reward: Int
        var isUnlocked: Bool
        let category: String
    }
    
    // Add cache for QR mappings
    private let qrCache = NSCache<NSString, NSString>()
    
    // Add debouncer for persist operations
    private var persistTimer: Timer?
    
    // MARK: - Authentication Methods
    
    private func handleSuccessfulLogin(user: User, isGoogle: Bool) {
        currentUser = user
        isAuthenticated = true
        isLoggedIn = true
        isGoogleSignIn = isGoogle
        
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(user.email, forKey: "userEmail")
        UserDefaults.standard.set(isGoogle, forKey: "isGoogleSignIn")
        
        NotificationCenter.default.post(
            name: .userProfileUpdated,
            object: user
        )
    }
    func login(email: String, password: String) {
        // Login logika
        isAuthenticated = true
    }
    // UserManager osztályba
    func logout() {
        isAuthenticated = false
        currentUser = nil
        error = nil
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        
        self.dbManager.loginUser(email: email, password: password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let user):
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoggedIn = true
                self.error = nil
                self.isGoogleSignIn = false
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set(email, forKey: "userEmail")
            case .failure(let error):
                self.error = error
            }
            self.isLoading = false
        }
    }
    
    func signInWithGoogle(user: GIDGoogleUser) {
        isLoading = true
        
        guard let email = user.profile?.email,
              let name = user.profile?.name else {
            self.error = NSError(domain: "GoogleSignIn", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid Google user profile"])
            isLoading = false
            return
        }
        
        // Temporary UUID generation for email lookup
        let tempUserId = UUID()
        
        // Check if user exists
        self.dbManager.getUser(id: tempUserId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let existingUser):
                // User exists, log them in
                var updatedUser = existingUser
                if updatedUser.username.isEmpty {
                    updatedUser.username = updatedUser.email.components(separatedBy: "@")[0]
                }
                self.currentUser = updatedUser
                self.isAuthenticated = true
                self.isLoggedIn = true
                self.isGoogleSignIn = true
                self.error = nil
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set(email, forKey: "userEmail")
                UserDefaults.standard.set(true, forKey: "isGoogleSignIn")
                print("Debug: Logged in user username: \(updatedUser.username)")
                self.isLoading = false
            case .failure:
                // Create new user with Google info
                let newUser = User(
                    name: name,
                    email: email,
                    username: email.components(separatedBy: "@")[0],
                    bio: "",
                    rating: 0,
                    reviews: [],
                    location: Location(city: "", country: ""),
                    skills: [],
                    pricing: [],
                    isVerified: true,  // Verified because using Google
                    servicesOffered: "",
                    servicesAdvertised: "",
                    userRole: .client,
                    status: .active,
                    phoneNumber: nil,
                    address: nil
                )
                
                self.dbManager.registerGoogleUser(user: newUser) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let registeredUser):
                        self.currentUser = registeredUser
                        self.isAuthenticated = true
                        self.isLoggedIn = true
                        self.isGoogleSignIn = true
                        self.error = nil
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(email, forKey: "userEmail")
                        UserDefaults.standard.set(true, forKey: "isGoogleSignIn")
                        
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UserProfileUpdated"),
                            object: registeredUser
                        )
                    case .failure(let error):
                        self.error = error
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        isLoggedIn = false
        isGoogleSignIn = false
        
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "isGoogleSignIn")
        UserDefaults.standard.synchronize()
        
        GIDSignIn.sharedInstance.signOut()
    }
    
    func register(name: String, email: String, username: String, password: String) {
        isLoading = true
        
        // QR-kód generálása
        let personalLink = "https://skilltrade.app/profile/\(UUID().uuidString)"
        let permanentQRCodeUrl = generatePermanentQRCode(for: personalLink)
        
        let newUser = User(
            name: name,
            email: email,
            username: username,
            bio: "",
            rating: 0,
            reviews: [],
            location: Location(city: "", country: ""),
            skills: [],
            pricing: [],
            isVerified: false,
            servicesOffered: "",
            servicesAdvertised: "",
            userRole: .client,
            status: .pending,
            phoneNumber: nil,
            address: nil,
            permanentQRCodeUrl: permanentQRCodeUrl
        )
        
        self.dbManager.registerUser(user: newUser, password: password) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let registeredUser):
                self.currentUser = registeredUser
                self.isAuthenticated = true
                self.isLoggedIn = true
                self.error = nil
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                UserDefaults.standard.set(email, forKey: "userEmail")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserProfileUpdated"),
                    object: registeredUser
                )
            case .failure(let error):
                self.error = error
            }
            self.isLoading = false
        }
    }
    
    // MARK: - Profile Methods
    func updateProfile(_ user: User) {
        // Frissítjük a jelenlegi felhasználót
        currentUser = user
        
        // Meghívjuk a DatabaseManager update metódusát
        dbManager.updateUser(user) { success in
            if !success {
                print("Nem sikerült frissíteni a felhasználói profilt")
                // Opcionálisan küldhetsz egy hibaértesítést is
                NotificationCenter.default.post(
                    name: .userProfileUpdateFailed,
                    object: nil
                )
            } else {
                NotificationCenter.default.post(
                    name: .userProfileUpdated,
                    object: user
                )
            }
        }
    }
    
    // MARK: - Username Change Methods
    func canChangeUsername() -> Bool {
        guard let currentUser = currentUser else { return false }
        return self.dbManager.canChangeUsername(userId: currentUser.id, newUsername: currentUser.username)
    }
    
    func updateUsername(_ newUsername: String) -> Bool {
        guard let user = currentUser else { return false }
        
        // Check if enough time has passed since last change
        if !canChangeUsername() {
            self.error = NSError(domain: "Profile", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "A felhasználónév csak 10 naponta módosítható"])
            return false
        }
        
        // Record the change
        self.dbManager.recordUsernameChange(
            userId: user.id, 
            oldUsername: user.username, 
            newUsername: newUsername
        ) { [weak self] success in
            guard let self = self else { return }
            if success {
                var updatedUser = user
                updatedUser.username = newUsername
                
                self.dbManager.updateUser(updatedUser) { [weak self] updateSuccess in
                    guard let self = self else { return }
                    if updateSuccess {
                        self.currentUser = updatedUser
                    }
                }
            }
        }
        
        return true
    }

    // MARK: - Profile Image Methods
    func updateProfileImage(_ imageUrl: String) -> Bool {
        guard let user = currentUser else { return false }
        
        self.dbManager.updateUserProfileImage(
            userId: user.id, 
            imageURL: imageUrl
        ) { [weak self] success in
            guard let self = self else { return }
            if success {
                var updatedUser = user
                updatedUser.profileImageUrl = imageUrl
                self.currentUser = updatedUser
            }
        }
        
        return true
    }

    // Add method to check saved login state
     func checkSavedLoginState() {
        if UserDefaults.standard.bool(forKey: "isLoggedIn"),
           let savedEmail = UserDefaults.standard.string(forKey: "userEmail") {
            isLoading = true  // Betöltés indítása
            self.dbManager.getUserByEmail(email: savedEmail) { [weak self] result in
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let user):
                    self.currentUser = user
                    self.isAuthenticated = true
                    self.isLoggedIn = true
                    self.isGoogleSignIn = UserDefaults.standard.bool(forKey: "isGoogleSignIn")
                    print("Debug: Automatikus bejelentkezés sikeres")
                case .failure(let error):
                    print("Hiba az automatikus bejelentkezésnél: \(error)")
                    self.signOut()  // Töröljük az érvénytelen állapotot
                }
            }
        }
    }
    
    // Add work management methods
    func saveWork(_ work: WorkData) {
        print("Debug Manager: Saving work: \(work.debugDescription)")
        if let index = userWorks.firstIndex(where: { $0.id == work.id }) {
            userWorks[index] = work
            print("Debug Manager: Updated existing work")
        } else {
            userWorks.append(work)
            print("Debug Manager: Added new work")
        }
        debouncedPersist()
    }
    
    func publishWork(_ work: WorkData) {
        print("Debug Manager: Publishing work: \(work.title)")
        var updatedWork = work
        updatedWork.statusText = "Publikálva"
        saveWork(updatedWork)
    }
    
    func deleteWork(_ workId: UUID) {
        userWorks.removeAll { $0.id == workId }
        
        objectWillChange.send()
        
        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("WorksUpdated"),
            object: userWorks
        )
    }
    
    func loadUserWorks() {
        // TODO: Load from database
        // For now, just using mock data
        if userWorks.isEmpty {
            let mockWork = WorkData(
                title: "Teszt munka",
                employerName: currentUser?.username ?? "Teszt Munkáltató",
                employerID: UUID(),
                wage: 5000,
                paymentType: "órabér",
                statusText: "Piszkozat"
            )
            userWorks = [mockWork]
        
        }
    }
    
    // Add test data method
    func loadTestData() {
        print("Debug UserManager: Loading test data...")
        if userWorks.isEmpty {
            let testWorks = [
                WorkData(
                    title: "Kertészkedés",
                    employerName: currentUser?.username ?? "Teszt Munkáltató",
                    employerID: UUID(),
                    wage: 2500,
                    paymentType: "órabér",
                    statusText: "Publikálva"
                ),
                WorkData(
                    title: "Festés",
                    employerName: currentUser?.username ?? "Teszt Munkáltató",
                    employerID: UUID(),
                    wage: 35000,
                    paymentType: "fix összeg",
                    statusText: "Publikálva"
                )
            ]
            userWorks = testWorks
            print("Debug UserManager: Created test works with IDs: \(testWorks.map { $0.id })")
        }
    }
    
    private func persistData() {
        // Save works
        if let encodedWorks = try? JSONEncoder().encode(userWorks) {
            UserDefaults.standard.set(encodedWorks, forKey: "persisted_works")
        }
        
        // Save QR mappings
        if let encodedMappings = try? JSONEncoder().encode(qrCodeMappings) {
            UserDefaults.standard.set(encodedMappings, forKey: "qr_code_mappings")
        }
        UserDefaults.standard.synchronize()
    }
    
    private func loadPersistedData() {
        // Load works
        if let data = UserDefaults.standard.data(forKey: "persisted_works"),
           let works = try? JSONDecoder().decode([WorkData].self, from: data) {
            userWorks = works
        }
        
        // Load QR mappings
        if let data = UserDefaults.standard.data(forKey: "qr_code_mappings"),
           let mappings = try? JSONDecoder().decode([String: UUID].self, from: data) {
            qrCodeMappings = mappings
        }
    }
    
    func saveQRCodeMapping(_ code: String, for workId: UUID) {
        qrCache.setObject(workId.uuidString as NSString, forKey: code as NSString)
        qrCodeMappings[code] = workId
        debouncedPersist()
    }
    
    func getWorkByQRCode(_ code: String) -> WorkData? {
        if let cachedWorkId = qrCache.object(forKey: code as NSString) {
            let workId = UUID(uuidString: cachedWorkId as String)!
            return userWorks.first { $0.id == workId }
        }
        
        guard let workId = qrCodeMappings[code] else { return nil }
        qrCache.setObject(workId.uuidString as NSString, forKey: code as NSString)
        return userWorks.first { $0.id == workId }
    }
    
    // Add this function
//    func checkAndUpdateRank() {
//        for rank in UserRank.allCases.reversed() {
//            if let requiredWorks = UserRank.Requirements.completedWorks[rank],
//               let requiredRatings = UserRank.Requirements.positiveRatings[rank] {
//                if completedWorks >= requiredWorks && positiveRatings >= requiredRatings {
//                    userRank = rank
//                    break
//                }
//            }
//        }
//    }
    
    // Add this function
//    func calculateProgress(to nextRank: UserRank) -> Double {
//        guard let requiredWorks = UserRank.Requirements.completedWorks[nextRank],
//              let requiredRatings = UserRank.Requirements.positiveRatings[nextRank] else {
//            return 0
//        }
//
//        let worksProgress = min(Double(completedWorks) / Double(requiredWorks), 1.0)
//        let ratingsProgress = min(Double(positiveRatings) / Double(requiredRatings), 1.0)
//
//        return (worksProgress + ratingsProgress) / 2.0
//    }
    
    func generateReferralCode() {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        referralCode = String((0..<6).map { _ in letters.randomElement()! })
    }
    
    func addReferral(referredID: UUID) {
        let referral = Referral(
            referrerID: currentUser?.id ?? UUID(),
            referredID: referredID,
            date: Date(),
            status: .pending,
            rewardClaimed: false
        )
        referrals.append(referral)
    }
    
//    func completeReferral(_ referral: Referral) {
//        if let index = referrals.firstIndex(where: { $0.id == referral.id }) {
//            var updatedReferral = referral
//            updatedReferral.status = .completed
//            referrals[index] = updatedReferral
//
//            if !referral.rewardClaimed {
//                skillCoin.addCoins(SkillCoin.Rewards.referralBonus)
//                referrals[index].rewardClaimed = true
//            }
//        }
//    }
    
    internal func updateStreak() {
        let calendar = Calendar.current
        let now = Date()
        
        if let lastLogin = lastLoginDate {
            let daysSinceLastLogin = calendar.dateComponents([.day], from: lastLogin, to: now).day ?? 0
            
            if daysSinceLastLogin == 1 {
                dailyStreak += 1
                if dailyStreak % 7 == 0 { // Weekly bonus
//                    skillCoin.addCoins(SkillCoin.Rewards.weeklyChallenge)
                }
            } else if daysSinceLastLogin > 1 {
                dailyStreak = 1
            }
        } else {
            dailyStreak = 1
        }
        
        lastLoginDate = now
//        generateDailyChallenges()
    }
    
//    internal func generateDailyChallenges() {
//        dailyChallenges = [
//            Challenge(id: UUID(), title: "Napi Bejelentkezés", description: "Jelentkezz be ma", reward: SkillCoin.Rewards.dailyLogin, //isCompleted: false),
//            Challenge(id: UUID(), title: "Értékelés Írása", description: "Írj egy értékelést", reward: 20, isCompleted: false),
//            Challenge(id: UUID(), title: "Új Készség", description: "Adj hozzá egy új készséget", reward: 30, isCompleted: false)
//        ]
//    }
    
    func checkAchievements() {
        let skillBasedAchievements = [
            Achievement(id: UUID(), title: "Kezdő Szakértő", description: "5 sikeres munka egy kategóriában", reward: 100, isUnlocked: false, category: "Skill"),
            Achievement(id: UUID(), title: "Haladó Mester", description: "15 sikeres munka egy kategóriában", reward: 250, isUnlocked: false, category: "Skill"),
            Achievement(id: UUID(), title: "Elit Specialista", description: "30 sikeres munka egy kategóriában", reward: 500, isUnlocked: false, category: "Skill")
        ]
        
        // Add achievement checking logic here
        achievements = skillBasedAchievements
    }
    
    private func debouncedPersist() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.persistData()
        }
    }
    
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        self.dbManager.fetchAllUsers { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let fetchedUsers):
                self.users = fetchedUsers
                completion(.success(fetchedUsers))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getUserProfile(email: String) {
        // Temporary UUID generation for email lookup
        let tempUserId = UUID()
        
        self.dbManager.getUser(id: tempUserId) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let user):
                var updatedUser = user
                if updatedUser.username.isEmpty {
                    updatedUser.username = updatedUser.email.components(separatedBy: "@")[0]
                }
                self.currentUser = updatedUser
            case .failure(let error):
                self.error = error
            }
        }
    }
    
    // Helper method to convert email to UUID (you might want to implement a more robust method)
    private func getUserIdFromEmail(_ email: String) -> UUID? {
        // This is a placeholder. In a real app, you'd have a more robust way to get the user ID
        return UUID()
    }
    
    func saveUserData() {
        guard let currentUser = currentUser else { return }
        
        self.dbManager.updateUser(currentUser) { [weak self] success in
            guard let self = self else { return }
            if !success {
                self.error = NSError(domain: "SaveUserData", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save user data"])
            }
        }
    }
    
    // QR-kód generálás új metódusa
    private func generatePermanentQRCode(for link: String) -> String? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = link.data(using: .ascii) else { return nil }
        
        filter.setValue(data, forKey: "inputMessage")
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let scaleX = 300 / ciImage.extent.width
        let scaleY = 300 / ciImage.extent.height
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else { return nil }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Mentés a dokumentumok mappájába
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent("permanent_qr_\(UUID().uuidString).png")
        
        do {
            try uiImage.pngData()?.write(to: fileURL)
            return fileURL.path
        } catch {
            print("QR-kód mentése sikertelen: \(error)")
            return nil
        }
    }
}

// Extension for notification names
extension Notification.Name {
    static let userProfileUpdated = Notification.Name("UserProfileUpdated")
    static let userProfileUpdateFailed = Notification.Name("UserProfileUpdateFailed")
    static let worksUpdated = Notification.Name("WorksUpdated")
}

extension WorkData: CustomDebugStringConvertible {
    var debugDescription: String {
        return "WorkData(id: \(id), title: \(title), status: \(statusText))"
    }
}
