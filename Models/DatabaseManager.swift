//
//  DatabaseManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//


import Foundation
import SQLite3
import CryptoKit

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {
        self.db = openDatabase()
        createTables()
    }
    
    private func openDatabase() -> OpaquePointer? {
        let fileURL = try! FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SkillTrade.sqlite")
        
        var db: OpaquePointer?
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return nil
        }
        return db
    }
    
    private func createTables() {
        let createUsersTable = """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                username TEXT UNIQUE,
                email TEXT UNIQUE,
                password_hash TEXT,
                salt TEXT,
                profile_picture_url TEXT,
                bio TEXT,
                skills TEXT,
                registration_date TEXT
            );
        """
        
        let createSkillsTable = """
            CREATE TABLE IF NOT EXISTS skills (
                id TEXT PRIMARY KEY,
                name TEXT UNIQUE,
                category TEXT
            );
        """
        
        let createUserSkillsTable = """
            CREATE TABLE IF NOT EXISTS user_skills (
                user_id TEXT,
                skill_id TEXT,
                proficiency INTEGER,
                PRIMARY KEY (user_id, skill_id),
                FOREIGN KEY (user_id) REFERENCES users(id),
                FOREIGN KEY (skill_id) REFERENCES skills(id)
            );
        """
        
        let createTradesTable = """
            CREATE TABLE IF NOT EXISTS trades (
                id TEXT PRIMARY KEY,
                initiator_id TEXT,
                recipient_id TEXT,
                initiator_skill_id TEXT,
                recipient_skill_id TEXT,
                status TEXT,
                created_at TEXT,
                updated_at TEXT,
                FOREIGN KEY (initiator_id) REFERENCES users(id),
                FOREIGN KEY (recipient_id) REFERENCES users(id),
                FOREIGN KEY (initiator_skill_id) REFERENCES skills(id),
                FOREIGN KEY (recipient_skill_id) REFERENCES skills(id)
            );
        """
        
        let createWorksTable = """
            CREATE TABLE IF NOT EXISTS works (
                id TEXT PRIMARY KEY,
                title TEXT,
                employer_name TEXT,
                employer_id TEXT,
                employee_id TEXT,
                wage REAL,
                payment_type TEXT,
                status_text TEXT,
                start_time TEXT,
                end_time TEXT,
                duration REAL,
                progress REAL
            );
        """
        
        let createSavedServicesTable = """
            CREATE TABLE IF NOT EXISTS saved_services (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                service_id TEXT,
                FOREIGN KEY (user_id) REFERENCES users(id)
            );
        """
        
        let createMessagesTable = """
            CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                sender_id TEXT,
                receiver_id TEXT,
                content TEXT,
                timestamp TEXT,
                is_read INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0,
                FOREIGN KEY (sender_id) REFERENCES users(id),
                FOREIGN KEY (receiver_id) REFERENCES users(id)
            );
        """
        
        let createNotesTable = """
                CREATE TABLE IF NOT EXISTS notes(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT,
                content TEXT
            );
        """
        
        let createWorkQRCodesTable = """
            CREATE TABLE IF NOT EXISTS work_qr_codes (
                work_id TEXT PRIMARY KEY,
                qr_code TEXT UNIQUE NOT NULL,
                created_at TEXT NOT NULL
            );
        """
        
        let tables = [
            createUsersTable,
            createSkillsTable,
            createUserSkillsTable,
            createTradesTable,
            createWorksTable,
            createWorkQRCodesTable,
            createSavedServicesTable,
            createMessagesTable
        ]
        
        for table in tables {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, table, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) != SQLITE_DONE {
                    print("Error creating table")
                }
                sqlite3_finalize(statement)
            } else {
                print("Error preparing statement")
            }
        }
    }
    
    private func executeStatement(_ sql: String) -> Bool {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        sqlite3_finalize(statement)
        return false
    }
    
    // User Management Methods
    func loginUser(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        // TODO: Implement login logic
        completion(.failure(NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
    
    func getUser(id: UUID, completion: @escaping (Result<User, Error>) -> Void) {
        // TODO: Implement get user by ID logic with completion handler
        completion(.failure(NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
    
    func getUserByEmail(email: String, completion: @escaping (Result<User, Error>) -> Void) {
        // Implement get user by email logic
        let sql = "SELECT * FROM users WHERE email = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (email as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                // Parse user from database row
                // This is a placeholder - you'll need to implement actual parsing
                let user = User(
                    name: String(cString: sqlite3_column_text(statement, 1)),
                    email: email,
                    username: String(cString: sqlite3_column_text(statement, 2)),
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
                    status: .active,
                    phoneNumber: nil,
                    address: nil
                )
                
                sqlite3_finalize(statement)
                completion(.success(user))
                return
            }
            
            sqlite3_finalize(statement)
        }
        
        completion(.failure(NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
    }
    
    func registerUser(user: User, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        // TODO: Implement user registration
        completion(.failure(NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
    
    func registerGoogleUser(user: User, completion: @escaping (Result<User, Error>) -> Void) {
        // TODO: Implement Google user registration with more robust logic
        completion(.success(user))
    }
    
    func updateUser(_ user: User, completion: @escaping (Bool) -> Void) {
        // TODO: Implement user update with completion handler
        completion(false)
    }
    
    func updateUserProfileImage(userId: UUID, imageURL: String, completion: @escaping (Bool) -> Void) {
        // TODO: Implement profile image update with completion handler
        completion(false)
    }
    
    func canChangeUsername(userId: UUID, newUsername: String) -> Bool {
        // TODO: Implement username change validation
        return false
    }
    
    func recordUsernameChange(userId: UUID, oldUsername: String, newUsername: String, completion: @escaping (Bool) -> Void) {
        // TODO: Implement username change recording with completion handler
        completion(false)
    }
    
    // Work Management Methods
    func saveWork(_ work: WorkData) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO works (
                id, 
                title, 
                employer_name, 
                employer_id, 
                employee_id, 
                wage, 
                payment_type, 
                status_text, 
                start_time, 
                end_time, 
                duration, 
                progress
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (work.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (work.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (work.employerName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (work.employerID.uuidString as NSString).utf8String, -1, nil)
            
            if let employeeID = work.employeeID {
                sqlite3_bind_text(statement, 5, (employeeID.uuidString as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 5)
            }
            
            sqlite3_bind_double(statement, 6, work.wage)
            sqlite3_bind_text(statement, 7, (work.paymentType as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 8, (work.statusText as NSString).utf8String, -1, nil)
            
            if let startTime = work.startTime {
                sqlite3_bind_text(statement, 9, (startTime.ISO8601Format() as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 9)
            }
            
            if let endTime = work.endTime {
                sqlite3_bind_text(statement, 10, (endTime.ISO8601Format() as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 10)
            }
            
            if let duration = work.duration {
                sqlite3_bind_double(statement, 11, duration)
            } else {
                sqlite3_bind_null(statement, 11)
            }
            
            sqlite3_bind_double(statement, 12, work.progress)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("Error saving work to database")
        return false
    }
    
    func getPublishedWorks() -> [WorkData] {
        var works: [WorkData] = []
        
        let sql = """
            SELECT 
                id, 
                title, 
                employer_name, 
                employer_id, 
                employee_id, 
                wage, 
                payment_type, 
                status_text, 
                start_time, 
                end_time, 
                duration, 
                progress 
            FROM works
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(statement, 0))
                let id = UUID(uuidString: idString)!
                
                let title = String(cString: sqlite3_column_text(statement, 1))
                let employerName = String(cString: sqlite3_column_text(statement, 2))
                let employerIDString = String(cString: sqlite3_column_text(statement, 3))
                let employerID = UUID(uuidString: employerIDString)!
                
                let employeeIDString = sqlite3_column_text(statement, 4)
                let employeeID = employeeIDString != nil ? UUID(uuidString: String(cString: employeeIDString!)) : nil
                
                let wage = sqlite3_column_double(statement, 5)
                let paymentType = String(cString: sqlite3_column_text(statement, 6))
                let statusText = String(cString: sqlite3_column_text(statement, 7))
                
                let startTimeString = sqlite3_column_text(statement, 8)
                let startTime = startTimeString != nil ? ISO8601DateFormatter().date(from: String(cString: startTimeString!)) : nil
                
                let endTimeString = sqlite3_column_text(statement, 9)
                let endTime = endTimeString != nil ? ISO8601DateFormatter().date(from: String(cString: endTimeString!)) : nil
                
                let duration = sqlite3_column_double(statement, 10)
                let progress = sqlite3_column_double(statement, 11)
                
                let workData = WorkData(
                    id: id,
                    title: title,
                    employerName: employerName,
                    employerID: employerID,
                    employeeID: employeeID,
                    wage: wage,
                    paymentType: paymentType,
                    statusText: statusText,
                    startTime: startTime,
                    endTime: endTime,
                    duration: duration > 0 ? TimeInterval(duration) : nil,
                    progress: progress
                )
                
                works.append(workData)
            }
            
            sqlite3_finalize(statement)
        } else {
            print("Error preparing statement for fetching works")
        }
        
        return works
    }
    
    func updateWorkStatus(workId: UUID, newStatus: String) -> Bool {
        let sql = """
            UPDATE works 
            SET status_text = ? 
            WHERE id = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (newStatus as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (workId.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("Error updating work status")
        return false
    }
    
    func deleteWork(workId: UUID) -> Bool {
        let sql = "DELETE FROM works WHERE id = ?"
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (workId.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("Error deleting work")
        return false
    }
    
    // User Fetching Methods
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        // TODO: Implement fetching all users
        completion(.failure(NSError(domain: "DatabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
    
    func searchUsers(query: String, completion: @escaping (Result<[User], Error>) -> Void) {
        let sql = """
            SELECT * FROM users 
            WHERE username LIKE ? 
            OR name LIKE ? 
            OR email LIKE ?
        """
        
        var statement: OpaquePointer?
        var users: [User] = []
        
        let searchPattern = "%\(query)%"
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (searchPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (searchPattern as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (searchPattern as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                // Create a basic User object from database results
                let user = User(
                    name: String(cString: sqlite3_column_text(statement, 1)),
                    email: String(cString: sqlite3_column_text(statement, 2)),
                    username: String(cString: sqlite3_column_text(statement, 3)),
                    bio: "",
                    rating: 0,
                    location: Location(city: "", country: ""),
                    skills: [],
                    pricing: []
                )
                users.append(user)
            }
            
            sqlite3_finalize(statement)
            completion(.success(users))
        } else {
            completion(.failure(NSError(domain: "DatabaseManager", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to search users"])))
        }
    }
    
    // Saved Services Management
    func saveService(_ service: Service, userId: UUID) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO saved_services (
                id, 
                user_id, 
                service_id
            ) VALUES (?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (UUID().uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (userId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (service.id.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("Error saving service to database")
        return false
    }
    
    func removeService(_ service: Service, userId: UUID) -> Bool {
        let sql = "DELETE FROM saved_services WHERE user_id = ? AND service_id = ?"
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (service.id.uuidString as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        print("Error removing service from database")
        return false
    }
    
    func getSavedServices(userId: UUID) -> [Service] {
        var services: [Service] = []
        
        let sql = """
            SELECT 
                service_id 
            FROM saved_services
            WHERE user_id = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId.uuidString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let serviceIdString = String(cString: sqlite3_column_text(statement, 0))
                
                // Fetch service from database or API
                // This is a placeholder - you'll need to implement actual fetching
                guard let serviceId = UUID(uuidString: serviceIdString),
                      let user = currentUser else { continue }
                
                let service = Service(
                    id: serviceId,
                    advertiser: user,
                    name: "Mentett Szolgáltatás", // Placeholder
                    description: "Leírás", // Placeholder
                    price: 0,
                    location: "Magyarország", // Placeholder
                    skills: [],
                    availability: ServiceAvailability(serviceId: serviceId),
                    typeofService: .other,
                    serviceOption: .free // Példaérték
                )
                
                services.append(service)
            }
            
            sqlite3_finalize(statement)
        } else {
            print("Error preparing statement for fetching saved services")
        }
        
        return services
    }
    
    // Message Management Methods
    func saveMessage(_ message: Message) -> Bool {
        let sql = """
            INSERT INTO messages (
                id, 
                sender_id, 
                receiver_id, 
                content, 
                timestamp, 
                is_read, 
                is_deleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (message.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (message.senderId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (message.receiverId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (message.content as NSString).utf8String, -1, nil)
            
            let dateFormatter = ISO8601DateFormatter()
            sqlite3_bind_text(statement, 5, (dateFormatter.string(from: message.timestamp) as NSString).utf8String, -1, nil)
            
            sqlite3_bind_int(statement, 6, message.isRead ? 1 : 0)
            sqlite3_bind_int(statement, 7, message.isDeleted ? 1 : 0)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
            
            sqlite3_finalize(statement)
        }
        return false
    }

    func getMessages(forUserId userId: String, withOtherUserId otherUserId: String) -> [Message] {
        var messages: [Message] = []
        
        let sql = """
            SELECT * FROM messages 
            WHERE (sender_id = ? AND receiver_id = ?) 
               OR (sender_id = ? AND receiver_id = ?) 
            ORDER BY timestamp
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (userId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (otherUserId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (otherUserId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (userId as NSString).utf8String, -1, nil)
            
            let dateFormatter = ISO8601DateFormatter()
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let senderId = String(cString: sqlite3_column_text(statement, 1))
                let receiverId = String(cString: sqlite3_column_text(statement, 2))
                let content = String(cString: sqlite3_column_text(statement, 3))
                let timestampString = String(cString: sqlite3_column_text(statement, 4))
                let timestamp = dateFormatter.date(from: timestampString) ?? Date()
                let isRead = sqlite3_column_int(statement, 5) == 1
                let isDeleted = sqlite3_column_int(statement, 6) == 1
                
                let message = Message(
                    id: id,
                    content: content,
                    timestamp: timestamp,
                    senderId: senderId,
                    receiverId: receiverId,
                    isRead: isRead,
                    isFromCurrentUser: senderId == userId,
                    isDeleted: isDeleted
                )
                
                messages.append(message)
            }
            
            sqlite3_finalize(statement)
        }
        
        return messages
    }

    func markMessageAsRead(messageId: String) -> Bool {
        let sql = "UPDATE messages SET is_read = 1 WHERE id = ?"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
            
            sqlite3_finalize(statement)
        }
        return false
    }

    func deleteMessage(messageId: String) -> Bool {
        let sql = "UPDATE messages SET is_deleted = 1 WHERE id = ?"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (messageId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return true
            }
            
            sqlite3_finalize(statement)
        }
        return false
    }
    
    // Új tulajdonság a currentUser tárolásához
    var currentUser: User? {
        // Implementáld a tényleges bejelentkezett felhasználó lekérdezését
        return nil
    }
    
    func createStatusTable() {
        guard let db = openDatabase() else { return }
        
        let createTableString = """
        CREATE TABLE IF NOT EXISTS UserStatus (
            userId TEXT PRIMARY KEY,
            isOnline INTEGER DEFAULT 0,
            lastSeen REAL
        );
        """
        
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("UserStatus tábla létrehozva")
            } else {
                print("UserStatus tábla létrehozási hibája")
            }
        } else {
            print("CREATE TABLE statement nem készíthető elő")
        }
        
        sqlite3_finalize(createTableStatement)
        sqlite3_close(db)
    }
    func updateOnlineStatus(userId: String, isOnline: Bool) {
        guard let db = openDatabase() else { return }
        
        let updateStatementString = "UPDATE UserStatus SET isOnline = ?, lastSeen = ? WHERE userId = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(updateStatement, 1, isOnline ? 1 : 0)
            sqlite3_bind_double(updateStatement, 2, Date().timeIntervalSince1970)
            sqlite3_bind_text(updateStatement, 3, (userId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Státusz frissítve: \(userId) -> \(isOnline ? "Online" : "Offline")")
            } else {
                print("Státusz frissítési hiba")
            }
        } else {
            print("UPDATE statement nem készíthető elő")
        }
        
        sqlite3_finalize(updateStatement)
        sqlite3_close(db)
    }
    func isUserOnline(userId: String) -> Bool {
        guard let db = openDatabase() else { return false }
        
        let queryStatementString = "SELECT isOnline FROM UserStatus WHERE userId = ?;"
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (userId as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                let isOnline = sqlite3_column_int(queryStatement, 0) != 0
                return isOnline
            }
        } else {
            print("SELECT statement nem készíthető elő")
        }
        
        sqlite3_finalize(queryStatement)
        sqlite3_close(db)
        return false
    }
    func createCallRequestsTable() {
        guard let db = openDatabase() else { return }
        
        let createTableString = """
        CREATE TABLE IF NOT EXISTS CallRequests (
            requestId TEXT PRIMARY KEY,
            callerId TEXT,
            receiverId TEXT,
            timestamp REAL
        );
        """
        
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("CallRequests tábla létrehozva")
            } else {
                print("CallRequests tábla létrehozási hibája")
            }
        } else {
            print("CREATE TABLE statement nem készíthető elő")
        }
        
        sqlite3_finalize(createTableStatement)
        sqlite3_close(db)
    }
    func createCallRequest(callerId: String, receiverId: String) -> String? {
        guard let db = openDatabase() else { return nil }
        
        let requestId = UUID().uuidString
        let insertStatementString = "INSERT INTO CallRequests (requestId, callerId, receiverId, timestamp) VALUES (?, ?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (requestId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (callerId as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (receiverId as NSString).utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 4, Date().timeIntervalSince1970)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Hívási kérelem elküldve: \(requestId)")
                return requestId
            } else {
                print("Hívási kérelem mentési hibája")
            }
        } else {
            print("INSERT statement nem készíthető elő")
        }
        
        sqlite3_finalize(insertStatement)
        sqlite3_close(db)
        return nil
    }
    func checkForCallRequests(receiverId: String) -> [String] {
        guard let db = openDatabase() else { return [] }
        
        let queryStatementString = "SELECT requestId, callerId FROM CallRequests WHERE receiverId = ?;"
        var queryStatement: OpaquePointer?
        var requestIds = [String]()
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (receiverId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let requestId = String(cString: sqlite3_column_text(queryStatement, 0))
                let callerId = String(cString: sqlite3_column_text(queryStatement, 1))
                print("Új hívási kérelem: \(callerId) -> \(requestId)")
                requestIds.append(requestId)
            }
        } else {
            print("SELECT statement nem készíthető elő")
        }
        
        sqlite3_finalize(queryStatement)
        sqlite3_close(db)
        return requestIds
    }
    
    func saveWorkQRCode(workId: UUID, qrCode: String) -> Bool {
        let deleteSql = "DELETE FROM work_qr_codes WHERE work_id = ?"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSql, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (workId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
        
        let insertSql = "INSERT INTO work_qr_codes (work_id, qr_code, created_at) VALUES (?, ?, ?)"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSql, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (workId.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (qrCode as NSString).utf8String, -1, nil)
            
            let dateFormatter = ISO8601DateFormatter()
            let currentDate = dateFormatter.string(from: Date())
            sqlite3_bind_text(insertStatement, 3, (currentDate as NSString).utf8String, -1, nil)
            
            let result = sqlite3_step(insertStatement) == SQLITE_DONE
            sqlite3_finalize(insertStatement)
            print("Debug DB: Saved QR code for work \(workId): \(result ? "success" : "failed")")
            return result
        }
        
        sqlite3_finalize(insertStatement)
        return false
    }

    func getWorkByQRCode(_ qrCode: String) -> WorkData? {
        print("Debug DB: Looking for work with QR code: \(qrCode)")
        
        let sql = """
            SELECT w.* FROM works w
            INNER JOIN work_qr_codes q ON w.id = q.work_id
            WHERE q.qr_code = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (qrCode as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(statement, 0))
                guard let id = UUID(uuidString: idString) else {
                    sqlite3_finalize(statement)
                    return nil
                }
                
                let title = String(cString: sqlite3_column_text(statement, 1))
                let employerName = String(cString: sqlite3_column_text(statement, 2))
                let employerIDString = String(cString: sqlite3_column_text(statement, 3))
                guard let employerID = UUID(uuidString: employerIDString) else {
                    sqlite3_finalize(statement)
                    return nil
                }
                
                let wage = sqlite3_column_double(statement, 5)
                let paymentType = String(cString: sqlite3_column_text(statement, 6))
                
                let work = WorkData(
                    id: id,
                    title: title,
                    employerName: employerName,
                    employerID: employerID,
                    wage: wage,
                    paymentType: paymentType,
                    statusText: "Folyamatban"
                )
                
                print("Debug DB: Found work: \(work.title)")
                sqlite3_finalize(statement)
                return work
            }
        }
        
        print("Debug DB: No work found for QR code")
        sqlite3_finalize(statement)
        return nil
    }
}
