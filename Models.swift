import Foundation
import SwiftUI
import Combine
import DesignSystem

import Foundation
import SwiftUI
import Combine

// MARK: - Message Model
public struct Message: Identifiable, Codable, Equatable {
    public let id: String
    public var content: String
    public let timestamp: Date
    public var editedTimestamp: Date?
    public let senderId: String
    public let receiverId: String
    public var isRead: Bool
    public let isFromCurrentUser: Bool
    public var isEdited: Bool
    public var isDeleted: Bool

    public init(
        id: String = UUID().uuidString,
        content: String,
        timestamp: Date = Date(),
        editedTimestamp: Date? = nil,
        senderId: String = "",
        receiverId: String = "",
        isRead: Bool = false,
        isFromCurrentUser: Bool,
        isEdited: Bool = false,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.editedTimestamp = editedTimestamp
        self.senderId = senderId
        self.receiverId = receiverId
        self.isRead = isRead
        self.isFromCurrentUser = isFromCurrentUser
        self.isEdited = isEdited
        self.isDeleted = isDeleted
    }

    // Üzenet szerkesztése
    public func edited(with newContent: String) -> Message {
        Message(
            id: self.id,
            content: newContent,
            timestamp: self.timestamp,
            editedTimestamp: Date(),
            senderId: self.senderId,
            receiverId: self.receiverId,
            isRead: self.isRead,
            isFromCurrentUser: self.isFromCurrentUser,
            isEdited: true,
            isDeleted: self.isDeleted
        )
    }

    // Üzenet törlése
    public func deleted() -> Message {
        Message(
            id: self.id,
            content: "Ez az üzenet törölve lett",
            timestamp: self.timestamp,
            editedTimestamp: self.editedTimestamp,
            senderId: self.senderId,
            receiverId: self.receiverId,
            isRead: self.isRead,
            isFromCurrentUser: self.isFromCurrentUser,
            isEdited: self.isEdited,
            isDeleted: true
        )
    }

    // Equatable megfelelés implementálása
    public static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.timestamp == rhs.timestamp &&
        lhs.editedTimestamp == rhs.editedTimestamp &&
        lhs.senderId == rhs.senderId &&
        lhs.receiverId == rhs.receiverId &&
        lhs.isRead == rhs.isRead &&
        lhs.isFromCurrentUser == rhs.isFromCurrentUser &&
        lhs.isEdited == rhs.isEdited &&
        lhs.isDeleted == rhs.isDeleted
    }
}

// Új enum az üzenet státuszához
public enum MessageStatus: String, Codable {
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

// MARK: - User Model
public struct User: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var email: String
    public var username: String
    public var bio: String
    public var rating: Double
    public var reviews: [Review]
    public var location: Location
    public var skills: [Skill]
    public var pricing: [Pricing]
    public var isVerified: Bool
    public var servicesOffered: String
    public var servicesAdvertised: String
    public var userRole: UserRole
    public var status: UserStatus
    public var phoneNumber: String?
    public var address: Address?
    public var profileImageUrl: String?
    public var xp: Int
    public var permanentQRCodeUrl: String?
    public var typeofservice: String?
    let price: Double
    public var photos: [String]
    public var photoUrls: [URL]?
    public var age: Int?
    public var createdAt: Date?
    public var updatedAt: Date?

    // User struct - Add hozzá ezt a computed property-t
    var idString: String {
        return id.uuidString
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        email: String,
        username: String,
        bio: String,
        rating: Double,
        reviews: [Review] = [],
        location: Location,
        skills: [Skill] = [],
        pricing: [Pricing] = [],
        isVerified: Bool = false,
        servicesOffered: String = "",
        servicesAdvertised: String = "",
        userRole: UserRole = .client,
        status: UserStatus = .pending,
        phoneNumber: String? = nil,
        address: Address? = nil,
        profileImageUrl: String? = nil,
        photos: [String] = [],
        photoUrls: [URL]? = nil,
        xp: Int = 0,
        permanentQRCodeUrl: String? = nil,
        typeofservice: String? = nil,
        price: Double = 0.0,
        age: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.username = username
        self.bio = bio
        self.rating = rating
        self.reviews = reviews
        self.location = location
        self.skills = skills
        self.pricing = pricing
        self.isVerified = isVerified
        self.servicesOffered = servicesOffered
        self.servicesAdvertised = servicesAdvertised
        self.userRole = userRole
        self.status = status
        self.phoneNumber = phoneNumber
        self.address = address
        self.profileImageUrl = profileImageUrl
        self.photos = photos
        self.photoUrls = photoUrls
        self.xp = xp
        self.permanentQRCodeUrl = permanentQRCodeUrl
        self.typeofservice = typeofservice
        self.price = price
        self.age = age
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func updated(
        name: String? = nil,
        email: String? = nil,
        username: String? = nil,
        bio: String? = nil,
        rating: Double? = nil,
        reviews: [Review]? = nil,
        location: Location? = nil,
        skills: [Skill]? = nil,
        pricing: [Pricing]? = nil,
        isVerified: Bool? = nil,
        servicesOffered: String? = nil,
        servicesAdvertised: String? = nil,
        userRole: UserRole? = nil,
        status: UserStatus? = nil,
        phoneNumber: String?? = nil,
        address: Address?? = nil,
        profileImageUrl: String?? = nil,
        xp: Int? = nil,
        permanentQRCodeUrl: String?? = nil,
        typeofservice: String?? = nil,
        age: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) -> User {
        User(
            id: self.id,
            name: name ?? self.name,
            email: email ?? self.email,
            username: username ?? self.username,
            bio: bio ?? self.bio,
            rating: rating ?? self.rating,
            reviews: reviews ?? self.reviews,
            location: location ?? self.location,
            skills: skills ?? self.skills,
            pricing: pricing ?? self.pricing,
            isVerified: isVerified ?? self.isVerified,
            servicesOffered: servicesOffered ?? self.servicesOffered,
            servicesAdvertised: servicesAdvertised ?? self.servicesAdvertised,
            userRole: userRole ?? self.userRole,
            status: status ?? self.status,
            phoneNumber: phoneNumber ?? self.phoneNumber,
            address: address ?? self.address,
            profileImageUrl: profileImageUrl ?? self.profileImageUrl,
            xp: xp ?? self.xp,
            permanentQRCodeUrl: permanentQRCodeUrl ?? self.permanentQRCodeUrl,
            typeofservice: typeofservice ?? self.typeofservice,
            age: age ?? self.age,
            createdAt: createdAt ?? self.createdAt,
            updatedAt: updatedAt ?? self.updatedAt
        )
    }

    public static var preview: User {
        User(
            name: "Preview User",
            email: "preview@example.com",
            username: "previewuser",
            bio: "Sample bio",
            rating: 4.5,
            location: Location(city: "Budapest", country: "Hungary"),
            skills: [Skill(name: "Programming")],
            pricing: [Pricing(price: 5000, unit: "óra")],
            photos: ["profile", "profile", "profile"],
            xp: 1000,
            age: 25
        )
    }
}
extension User {
    static func fromServerUser(_ serverUser: ServerUser) -> User {
        return User(
            id: UUID(uuidString: serverUser.id) ?? UUID(),
            name: serverUser.name,
            email: serverUser.email,
            username: serverUser.username,
            bio: serverUser.bio ?? "",
            rating: serverUser.rating ?? 0.0,
            reviews: serverUser.reviews ?? [],
            location: Location(city: serverUser.location?.city ?? "", country: serverUser.location?.country ?? ""),
            skills: serverUser.skills ?? [],
            pricing: serverUser.pricing ?? [],
            isVerified: serverUser.isVerified ?? false,
            servicesOffered: serverUser.servicesOffered ?? "",
            servicesAdvertised: serverUser.servicesAdvertised ?? "",
            userRole: UserRole.fromString(serverUser.userRole ?? "client"),
            status: UserStatus.fromString(serverUser.status ?? "pending"),
            phoneNumber: serverUser.phoneNumber,
            address: serverUser.address,
            profileImageUrl: serverUser.profileImageUrl,
            photos: serverUser.photos ?? [],
            xp: serverUser.xp ?? 0,
            permanentQRCodeUrl: serverUser.permanentQRCodeUrl,
            typeofservice: serverUser.typeofservice,
            price: serverUser.price ?? 0.0,
            age: serverUser.age,
            createdAt: serverUser.getCreatedAtDate() ?? Date(),
            updatedAt: serverUser.getCreatedAtDate() ?? Date()
        )
    }
}

struct ServerUser: Codable {
    let id: String
    let name: String
    let email: String
    let username: String
    let bio: String?
    let rating: Double?
    let reviews: [Review]?
    let location: ServerLocation?
    let skills: [Skill]?
    let pricing: [Pricing]?
    let isVerified: Bool?
    let servicesOffered: String?
    let servicesAdvertised: String?
    let userRole: String?
    let status: String?
    let phoneNumber: String?
    let address: Address?
    let profileImageUrl: String?
    let photos: [String]?
    let xp: Int?
    let permanentQRCodeUrl: String?
    let typeofservice: String?
    let price: Double?
    let age: Int?
    let createdAt: String?
    let updatedAt: String?
    
    
    func getCreatedAtDate() -> Date? {
        guard let createdAt = createdAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? formatter.date(from: createdAt.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }


    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, email, username, bio, rating, reviews, location, skills, pricing
        case isVerified, servicesOffered, servicesAdvertised, userRole, status
        case phoneNumber, address, profileImageUrl, photos, xp, permanentQRCodeUrl
        case typeofservice, price, age, createdAt, updatedAt
    }
}


struct ServerLocation: Codable {
    let city: String?
    let country: String?
}

extension UserRole {
    static func fromString(_ string: String) -> UserRole {
        switch string.lowercased() {
        case "serviceprovider", "service_provider":
            return .serviceProvider
        case "admin":
            return .admin
        default:
            return .client
        }
    }
    
    var serverString: String {
        switch self {
        case .client:
            return "client"
        case .serviceProvider:
            return "serviceProvider"
        case .admin:
            return "admin"
        }
    }
}

extension UserStatus {
    static func fromString(_ string: String) -> UserStatus {
        switch string.lowercased() {
        case "active":
            return .active
        case "suspended":
            return .suspended
        default:
            return .pending
        }
    }
    
    var serverString: String {
        switch self {
        case .pending:
            return "pending"
        case .active:
            return "active"
        case .suspended:
            return "suspended"
        case .deleted:
            return "deleted"
        }
    }
}

public enum UserRole: String, Codable {
    case admin
    case client
    case serviceProvider = "serviceProvider"
}

public enum UserStatus: String, Codable {
    case pending
    case active
    case suspended
    case deleted
}

public struct Address: Codable {
    public let country: String
    public let county: String
    public let city: String
    public let postalCode: String
    public let streetAddress: String

    public init(country: String, county: String, city: String, postalCode: String, streetAddress: String) {
        self.country = country
        self.county = county
        self.city = city
        self.postalCode = postalCode
        self.streetAddress = streetAddress
    }
}


// MARK: - Supporting Types
public struct Review: Identifiable, Codable {
    public let id: UUID
    public let rating: Double
    public let text: String
    public let reviewerName: String
    public let timestamp: Date

    public init(id: UUID = UUID(), text: String, rating: Double, reviewerName: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.rating = rating
        self.reviewerName = reviewerName
        self.timestamp = timestamp
    }
}

public struct Location: Codable {
    public let city: String
    public let country: String

    public init(city: String, country: String) {
        self.city = city
        self.country = country
    }
}

public struct Skill: Identifiable, Codable, Hashable {
    public let id: UUID
    public let name: String
    public let level: Int

    public init(id: UUID = UUID(), name: String, level: Int = 1) {
        self.id = id
        self.name = name
        self.level = level
    }
}

public struct Pricing: Identifiable, Codable {
    public let id: UUID
    public let price: Double
    public let unit: String
    public let description: String

    public init(id: UUID = UUID(), price: Double, unit: String, description: String = "") {
        self.id = id
        self.price = price
        self.unit = unit
        self.description = description
    }

    public func toPricingItem() -> PricingItem {
        PricingItem(id: id, price: price, unit: unit, description: description)
    }
}

public struct PricingItem: Identifiable, Codable {
    public let id: UUID
    public let price: Double
    public let unit: String
    public let description: String

    public init(id: UUID = UUID(), price: Double, unit: String, description: String = "") {
        self.id = id
        self.price = price
        self.unit = unit
        self.description = description
    }

    public func toPricing() -> Pricing {
        Pricing(id: id, price: price, unit: unit, description: description)
    }
}

// MARK: - Calendar Related Types
public enum WeekDay: Int, Codable, CaseIterable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    public var name: String {
        let key: String
        switch self {
        case .monday: key = "monday"
        case .tuesday: key = "tuesday"
        case .wednesday: key = "wednesday"
        case .thursday: key = "thursday"
        case .friday: key = "friday"
        case .saturday: key = "saturday"
        case .sunday: key = "sunday"
        }
        return NSLocalizedString(key, comment: "")
    }
}
public enum FizetesiMod: String, Codable, CaseIterable {
    case bankkartya = "Bankkártya"
    case atutalas = "Átutalás"
    case keszpenz = "Készpénz"
    
    public var localizedName: String { self.rawValue }
}

public struct TimeRange: Identifiable, Codable {
    public let id: UUID
    public let start: Date
    public let end: Date

    public init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

// MARK: - Service Model
public struct Service: Identifiable, Codable {
    
    public let id: UUID
    public let advertiser: User // Biztosítsuk, hogy a `User` is `Codable`
    public let name: String
    public let description: String
    public let rating: Double
    public let reviewCount: Int
    public let price: Double
    public let location: String
    public let skills: [String]
    public let mediaURLs: [URL] // `URL` `Codable`, ez OK
    public let availability: ServiceAvailability // Biztosítsuk, hogy a `ServiceAvailability` is `Codable`
    public let typeofService: TypeofService // Biztosítsuk, hogy a `TypeofService` is `Codable`
    public let serviceOption: ServiceOption // Biztosítsuk, hogy a `ServiceOption` is `Codable`
    public let fizetesimod: FizetesiMod // Fizetési mód tulajdonság
    

    public init(
        id: UUID = UUID(),
        advertiser: User,
        name: String,
        description: String,
        rating: Double = 0,
        reviewCount: Int = 0,
        price: Double,
        location: String,
        skills: [String],
        mediaURLs: [URL] = [],
        availability: ServiceAvailability,
        typeofService: TypeofService,
        serviceOption: ServiceOption, // Új paraméter
        fizetesimod: FizetesiMod = .keszpenz // Alapértelmezett érték

    ) {
        self.id = id
        self.advertiser = advertiser
        self.name = name
        self.description = description
        self.rating = rating
        self.reviewCount = reviewCount
        self.price = price
        self.location = location
        self.skills = skills
        self.mediaURLs = mediaURLs
        self.availability = availability
        self.typeofService = typeofService
        self.serviceOption = serviceOption
        self.fizetesimod = fizetesimod
    }
    public static var preview: Service {
            Service(
                id: UUID(),
                advertiser: User.preview,
                name: "Sample Service",
                description: "This is a sample service description.",
                rating: 4.5,
                reviewCount: 10,
                price: 100.0,
                location: "Budapest",
                skills: ["Programming", "Web Development"],
                mediaURLs: [],
                availability: ServiceAvailability(serviceId: UUID()),
                typeofService: .other,
                serviceOption: .free
            )
        }
}
public var preview: Service {
        Service(
            advertiser: User.preview,
            name: "Sample Service",
            description: "Sample description",
            price: 5000,
            location: "Budapest",
            skills: ["Programming"],
            availability: ServiceAvailability(serviceId: UUID()),
            typeofService: .other ,// Példaérték
            serviceOption: .premium
            
        )
    }

public enum ServiceOption: String, CaseIterable, Codable {
    case free = "Free"
    case premium = "Premium"
    
    public var localized: String {
        let key = "service_option_\(self.rawValue)"
        return NSLocalizedString(key, comment: "")
    }
}
// MARK: - Appointment Related Types
public enum AppointmentStatus: String, Codable {
    case pending
    case confirmed
    case cancelled
    case completed
}

public struct Appointment: Identifiable, Codable {
    public let id: UUID
    public let serviceProvider: User
    public let client: User
    public let date: Date
    public let duration: TimeInterval
    public var status: AppointmentStatus
    public let notes: String?

    public init(serviceProvider: User, client: User, date: Date, duration: TimeInterval, status: AppointmentStatus = .pending, notes: String? = nil) {
        self.id = UUID()
        self.serviceProvider = serviceProvider
        self.client = client
        self.date = date
        self.duration = duration
        self.status = status
        self.notes = notes
    }
}

// MARK: - Service Availability
public struct ServiceAvailability: Codable {
    public let serviceId: UUID
    public var weeklySchedule: [WeekDay: [TimeRange]]
    public var exceptions: [Date]

    public init(serviceId: UUID, weeklySchedule: [WeekDay: [TimeRange]] = [:], exceptions: [Date] = []) {
        self.serviceId = serviceId
        self.weeklySchedule = weeklySchedule
        self.exceptions = exceptions
    }
}

// Add SearchFilters struct
public struct SearchFilters {
    public var selectedCategories: Set<SkillCategory> = []
    public var minimumRating: Double = 0
    public var maxPrice: Double? = nil

    public init() {}
}

// Add SkillCategory enum
public enum SkillCategory: String, CaseIterable {
    case technology
    case education
    case health
    case arts
    case sports
    case business
    case other

    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}



// Add skillsByCategory dictionary
public let skillsByCategory: [SkillCategory: [String]] = [
    .technology: ["programming", "webDevelopment", "mobileDevelopment", "itSupport"],
    .education: ["math", "language", "history", "physics"],
    .health: ["yoga", "personalTraining", "nutritionAdvice"],
    .arts: ["painting", "music", "photography", "graphicDesign"],
    .sports: ["running", "swimming", "tennis", "football"],
    .business: ["marketing", "accounting", "projectManagement"],
    .other: ["gardening", "cooking", "crafting"]
 ]
public var localizedSkillsByCategory: [SkillCategory: [String]] {
    skillsByCategory.mapValues { skills in
        skills.map { NSLocalizedString($0, comment: "") }
    }
}




// Add ChatPreview struct
public struct ChatPreview: Identifiable {
    public let id: UUID
    public var otherUser: User
    public var lastMessage: Message
    public var unreadCount: Int

    public init(id: UUID = UUID(), otherUser: User, lastMessage: Message, unreadCount: Int = 0) {
        self.id = id
        self.otherUser = otherUser
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
    }
}

struct Referral: Identifiable {
    let id = UUID()
    let referrerID: UUID
    let referredID: UUID
    let date: Date
    var status: ReferralStatus
    var rewardClaimed: Bool

    enum ReferralStatus: String {
        case pending = "Függőben"
        case completed = "Teljesítve"
        case expired = "Lejárt"
    }
}

// Add Work struct
public struct Work: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var employerName: String
    public var employerId: UUID
    public var employeeId: UUID?
    public var wage: Double
    public var paymentType: String
    public var statusText: String
    public var startTime: Date?
    public var endTime: Date?
    public var duration: Int?
    public var progress: Double
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        employerName: String,
        employerId: UUID,
        employeeId: UUID? = nil,
        wage: Double,
        paymentType: String,
        statusText: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        duration: Int? = nil,
        progress: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.employerName = employerName
        self.employerId = employerId
        self.employeeId = employeeId
        self.wage = wage
        self.paymentType = paymentType
        self.statusText = statusText
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.progress = progress
        self.createdAt = createdAt
    }
}





// Central work data structure
struct WorkData: Identifiable, Equatable, Codable {
    let id: UUID // QR kód azonosító
    let title: String
    let employerName: String
    let employerID: UUID
    let employeeID: UUID?
    let wage: Double
    let paymentType: String
    var statusText: String // Enum helyett string-et használunk
    let startTime: Date?
    let endTime: Date?
    var duration: TimeInterval?
    var progress: Double
    let location: String // Új property
    var skills: [String] // Új property
    var category: String? // Új property
    var description: String?
    let createdAt: Date
    
    
    init(id: UUID = UUID(),
         title: String,
         employerName: String,
         employerID: UUID,
         employeeID: UUID? = nil,
         wage: Double,
         paymentType: String,
         statusText: String = "Nem kezdődött el",
         startTime: Date? = nil,
         endTime: Date? = nil,
         duration: TimeInterval? = nil,
         progress: Double = 0.0,
         location: String = "", // Új
         skills: [String] = [], // Új
         category: String? = nil, // Új
         description: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.employerName = employerName
        self.employerID = employerID
        self.employeeID = employeeID
        self.wage = wage
        self.paymentType = paymentType
        self.statusText = statusText
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.progress = progress
        self.location = location
        self.skills = skills
        self.category = category
        self.description = description
        self.createdAt = createdAt
    }

    static func == (lhs: WorkData, rhs: WorkData) -> Bool {
        return lhs.id == rhs.id
    }

    static func fromQRCode(_ code: String) -> WorkData? {
        print("Debug WorkData: Trying to decode QR code: \(code)")
        
        // Ellenőrizzük, hogy a QR kód érvényes-e
        guard let uuid = UUID(uuidString: code) else {
            print("Debug WorkData: Invalid UUID format in QR code: \(code)")
            return nil
        }
        
        // Lekérjük az összes munkát a UserManager-ből
        let works = UserManager.shared.userWorks
        print("Debug WorkData: Total available works: \(works.count)")
        
        // Részletes debug információk minden munkáról
        works.forEach { work in
            print("Debug WorkData: Work ID: \(work.id), Title: \(work.title), Status: \(work.statusText)")
        }
        
        // Keressük meg a megfelelő munkát
        let work = works.first { $0.id == uuid }
        
        if let work = work {
            print("Debug WorkData: Successfully found work - Title: \(work.title), Employer: \(work.employerName), Status: \(work.statusText)")
            return work
        } else {
            print("Debug WorkData: No work found with ID: \(uuid)")
            return nil
        }
    }

    // Helper function to calculate current earnings
    func calculateEarnings() -> Double {
        guard let duration = self.duration else { return 0 }
        let hours = duration / 3600 // Convert seconds to hours
        return wage * hours
    }

    // Helper function to format duration
    func formattedDuration() -> String {
        guard let duration = self.duration else { return "00:00:00" }
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // Helper function to get WorkStatus
    var status: WorkStatus {
        switch statusText {
        case "Nem kezdődött el": return .notStarted
        case "Folyamatban": return .inProgress
        case "Ellenőrzésre vár": return .waitingForReview
        case "Befejezve": return .completed
        default: return .notStarted
        }
    }
}

enum WorkStatus {
    case notStarted
    case inProgress
    case waitingForReview
    case completed
    
    var title: String {
        switch self {
        case .notStarted: return "Nem kezdődött el"
        case .inProgress: return "Folyamatban"
        case .waitingForReview: return "Ellenőrzésre vár"
        case .completed: return "Befejezve"
        }
    }
}




class WorkManager: ObservableObject {
    static let shared = WorkManager()
    private let serverAuthManager = ServerAuthManager.shared
    
    @Published var publishedWorks: [WorkData] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init() {
        // Kezdeti betöltés
        Task {
            await fetchPublishedWorks()
        }
    }
    
    // Munka publikálása - csak szerverre
    func publishWork(_ workData: WorkData) async throws {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let success = try await serverAuthManager.publishWork(workData)
            if !success {
                throw WorkError.saveFailed
            }
            
            // Frissítjük a lokális listát
            await fetchPublishedWorks()
            NotificationCenter.default.post(name: .worksUpdated, object: nil)
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Munkák lekérése - csak szerverről
    func fetchPublishedWorks() async {
        guard !isLoading else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            let works = try await serverAuthManager.fetchWorks()
            
            await MainActor.run {
                withAnimation(.easeInOut) {
                    self.publishedWorks = works
                }
                self.error = nil
                self.isLoading = false
                NotificationCenter.default.post(name: .worksUpdated, object: nil)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                // Hiba esetén üres listát jelenítünk meg
                self.publishedWorks = []
            }
        }
    }
    
    // Munka státusz frissítése - csak szerveren
    func updateWorkStatus(workId: UUID, newStatus: String, employerID: UUID) async throws {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let success = try await serverAuthManager.updateWorkStatus(
                workId: workId,
                status: newStatus,
                employerID: employerID
            )
            
            if !success {
                throw WorkError.updateFailed
            }
            
            // Frissítjük a lokális listát
            await fetchPublishedWorks()
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Munka törlése - csak szerverről
    func deleteWork(_ workData: WorkData) async throws {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let success = try await serverAuthManager.deleteWork(workData.id, employerID: workData.employerID)
            
            if !success {
                throw WorkError.deleteFailed
            }
            
            // Frissítjük a lokális listát
            await fetchPublishedWorks()
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // Munkák lekérése employer ID alapján
    func fetchWorksByEmployer(_ employerID: UUID) async throws -> [WorkData] {
        return try await serverAuthManager.fetchWorks(employerID: employerID)
    }
}

enum WorkError: Error {
    case saveFailed
    case updateFailed
    case deleteFailed
    
    var localizedDescription: String {
        switch self {
        case .saveFailed: return "Nem sikerült elmenteni a munkát"
        case .updateFailed: return "Nem sikerült frissíteni a munka állapotát"
        case .deleteFailed: return "Nem sikerült törölni a munkát"
        }
    }
}


public enum TypeofService: String, Codable {
    case technology = "Technológia"
    case education = "Oktatás"
    case health = "Egészség"
    case arts = "Művészet"
    case sports = "Sport"
    case business = "Üzlet"
    case gardening = "Kertészkedés"
    case other = "Egyéb"
    
    // SF Symbols nevek
    public var systemName: String {
        switch self {
        case .technology:
            return "laptopcomputer"
        case .education:
            return "graduationcap.fill"
        case .health:
            return "heart.fill"
        case .arts:
            return "paintpalette.fill"
        case .sports:
            return "sportscourt.fill"
        case .business:
            return "briefcase.fill"
        case .gardening:
            return "leaf.fill"
        case .other:
            return "ellipsis.circle.fill"
        }
    }
}

extension Card {
    var isExpired: Bool {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        let fullExpirationYear: Int
        if expirationYear < 100 {
            fullExpirationYear = 2000 + expirationYear
        } else {
            fullExpirationYear = expirationYear
        }
        
        if fullExpirationYear < currentYear {
            return true
        } else if fullExpirationYear == currentYear && expirationMonth < currentMonth {
            return true
        }
        return false
    }
    
    // NEW: formatted expiration as "MM/YY"
    var formattedExpiration: String {
        let month = String(format: "%02d", expirationMonth)
        let yearTwoDigits = expirationYear % 100
        let year = String(format: "%02d", yearTwoDigits)
        return "\(month)/\(year)"
    }
}


// MARK: - Card Types
public struct Card: Identifiable, Codable, Equatable {
    public let id: UUID
    public let cardName: String?
    public let cardNumber: String
    public let cardHolderName: String
    public let expirationMonth: Int
    public let expirationYear: Int
    public let cvv: String
    public let cardType: CardType
    public var isDefault: Bool // Changed to var
    public let createdAt: Date
    public let lastFourDigits: String
    public let cardColor: String? // Új: szín tárolása
    
    public init(
        id: UUID = UUID(),
        cardName: String? = nil,
        cardNumber: String,
        cardHolderName: String,
        expirationMonth: Int,
        expirationYear: Int,
        cvv: String,
        cardType: CardType,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        cardColor: String? = nil // Új paraméter
    ) {
        self.id = id
        self.cardName = cardName
        self.cardNumber = cardNumber
        self.cardHolderName = cardHolderName
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.cvv = cvv
        self.cardType = cardType
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.lastFourDigits = String(cardNumber.suffix(4))
        self.cardColor = cardColor
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        cardName = try container.decodeIfPresent(String.self, forKey: .cardName)
        cardNumber = try container.decode(String.self, forKey: .cardNumber)
        cardHolderName = try container.decode(String.self, forKey: .cardHolderName)
        expirationMonth = try container.decode(Int.self, forKey: .expirationMonth)
        expirationYear = try container.decode(Int.self, forKey: .expirationYear)
        cardType = try container.decode(CardType.self, forKey: .cardType)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastFourDigits = try container.decode(String.self, forKey: .lastFourDigits)
        cardColor = try container.decodeIfPresent(String.self, forKey: .cardColor)
        
        self.cvv = ""
    }
    

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cardNumber, forKey: .cardNumber)
        try container.encode(cardHolderName, forKey: .cardHolderName)
        try container.encode(expirationMonth, forKey: .expirationMonth)
        try container.encode(expirationYear, forKey: .expirationYear)
        try container.encode(cardType, forKey: .cardType)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastFourDigits, forKey: .lastFourDigits)
        // Note: CVV is not encoded for security reasons
    }
    
    enum CodingKeys: String, CodingKey {
        case id, cardNumber, cardName, cardHolderName, expirationMonth, expirationYear
        case cardType, isDefault, createdAt, lastFourDigits, cardColor
    }
    
    public func copyWith(
        isDefault: Bool? = nil
    ) -> Card {
        return Card(
            id: self.id,
            cardNumber: self.cardNumber,
            cardHolderName: self.cardHolderName,
            expirationMonth: self.expirationMonth,
            expirationYear: self.expirationYear,
            cvv: self.cvv,
            cardType: self.cardType,
            isDefault: isDefault ?? self.isDefault,
            createdAt: self.createdAt
        )
    }
}

public enum CardType: String, Codable, CaseIterable {
    case none = "None"
    case visa = "Visa"
    case mastercard = "Mastercard"
    case americanExpress = "American Express"
    case discover = "Discover"
    
    public var iconName: String {
        switch self {
        case .none : return "creditcard.fill"
        case .visa: return "visa"
        case .mastercard: return "mastercard"
        case .americanExpress: return "amex"
        case .discover: return "discover"
        }
    }
    
    public var color: Color {
        switch self {
        case .none: return Color.DesignSystem.fokekszin
        case .visa: return Color.blue
        case .mastercard: return Color.red
        case .americanExpress: return Color.green
        case .discover: return Color.orange
        }
    }
    
    public static func detect(from cardNumber: String) -> CardType {
        let cleanedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        
        if cleanedNumber.hasPrefix("4") {
            return .visa
        } else if cleanedNumber.hasPrefix("5") {
            return .mastercard
        } else if cleanedNumber.hasPrefix("3") {
            return .americanExpress
        } else if cleanedNumber.hasPrefix("6") {
            return .discover
        }
        
        return .none // default
    }
}
// MARK: - Card Validation
public struct CardValidation {
    public static func isValidCardNumber(_ number: String) -> Bool {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        
        guard cleaned.count >= 13 && cleaned.count <= 19 else {
            return false
        }
        
        return isValidLuhn(cleaned)
    }
    
    public static func isValidExpiration(month: Int, year: Int) -> Bool {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate) % 100
        let currentMonth = calendar.component(.month, from: currentDate)
        
        guard month >= 1 && month <= 12 else { return false }
        
        if year < currentYear {
            return false
        } else if year == currentYear && month < currentMonth {
            return false
        }
        
        return true
    }
    
    public static func isValidCVV(_ cvv: String, cardType: CardType) -> Bool {
        let cleaned = cvv.replacingOccurrences(of: " ", with: "")
        
        switch cardType {
        case .americanExpress:
            return cleaned.count == 4
        default:
            return cleaned.count == 3
        }
    }
    
    private static func isValidLuhn(_ number: String) -> Bool {
        var sum = 0
        let digits = number.reversed().map { String($0) }
        
        for (index, digit) in digits.enumerated() {
            guard let intDigit = Int(digit) else { return false }
            
            if index % 2 == 1 {
                let doubled = intDigit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += intDigit
            }
        }
        
        return sum % 10 == 0
    }
    
    public static func formatCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        
        for (index, character) in cleaned.enumerated() {
            if index > 0 && index % 4 == 0 {
                formatted += " "
            }
            formatted.append(character)
        }
        
        return formatted
    }
    
    
}

