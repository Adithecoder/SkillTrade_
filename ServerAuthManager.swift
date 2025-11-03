import Foundation
import Combine

class ServerAuthManager: ObservableObject {
    static let shared = ServerAuthManager()
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var currentUser: User?
    
    public var baseURL: String {
        return "http://localhost:3000/api" // vagy amit használsz
    }
    
    
//    public let baseURL = "http://localhost:3000/api"
    public let tokenKey = "authToken"
    private let userIdKey = "userId"
    private let userManager = UserManager.shared
    
    private init() {}
    
    // MARK: - Bejelentkezés
    func login(identifier: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            error = "Érvénytelen URL"
            isLoading = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "identifier": identifier,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = "Hibás adat formátum"
            self.isLoading = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.error = "Érvénytelen válasz"
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    self.error = "Nincs adat"
                    completion(false)
                    return
                }
                
                print("Login response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .customISO8601 // Használd a custom dátum kezelést
                        
                        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                        let user = User.fromServerUser(loginResponse.user)
                        
                        self.isAuthenticated = true
                        self.currentUser = user
                        
                        // UserManager frissítése
                        self.userManager.currentUser = user
                        self.userManager.isAuthenticated = true
                        
                        // Token és user adatok mentése
                        UserDefaults.standard.set(loginResponse.token, forKey: "authToken")
                        UserDefaults.standard.set(loginResponse.user.id, forKey: "userId")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        
                        // Lokális user adatok mentése
                        self.saveUserLocally(user)
                        
                        completion(true)
                    } catch {
                        print("JSON decode error: \(error)")
                        print("Error details: \(error.localizedDescription)")
                        self.error = "Hibás válasz formátum: \(error.localizedDescription)"
                        completion(false)
                    }
                } else {
                    do {
                        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        self.error = errorResponse.message
                    } catch {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                        self.error = "Bejelentkezési hiba (\(httpResponse.statusCode)): \(responseString)"
                    }
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Regisztráció
    func register(name: String, email: String, username: String, password: String, age: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        error = nil
        
        guard let url = URL(string: "\(baseURL)/auth/register") else {
            error = "Érvénytelen URL"
            isLoading = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "username": username,
            "password": password,
            "age": age
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            self.error = "Hibás adat formátum"
            self.isLoading = false
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.error = "Érvénytelen válasz"
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    self.error = "Nincs adat"
                    completion(false)
                    return
                }
                
                print("Register response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 201 {
                    do {
                        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
                        let user = User.fromServerUser(registerResponse.user)
                        
                        self.isAuthenticated = true
                        self.currentUser = user
                        
                        // UserManager frissítése
                        self.userManager.currentUser = user
                        self.userManager.isAuthenticated = true
                        
                        // Token és user adatok mentése
                        UserDefaults.standard.set(registerResponse.token, forKey: "authToken")
                        UserDefaults.standard.set(registerResponse.user.id, forKey: "userId")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        UserDefaults.standard.set(true, forKey: "isFirstLogin")
                        
                        // Lokális user adatok mentése
                        self.saveUserLocally(user)
                        
                        completion(true)
                    } catch {
                        print("JSON decode error: \(error)")
                        self.error = "Hibás válasz formátum"
                        completion(false)
                    }
                } else {
                    do {
                        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                        self.error = errorResponse.message
                    } catch {
                        let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                        self.error = "Regisztrációs hiba (\(httpResponse.statusCode)): \(responseString)"
                    }
                    completion(false)
                }
            }
        }.resume()
    }
    
    
    func applyForWork(
          workId: UUID,
          applicantId: UUID,
          applicantName: String,
          serviceTitle: String,
          employerId: UUID
      ) async throws -> Bool {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/apply") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          let body: [String: Any] = [
              "workId": workId.uuidString,
              "applicantId": applicantId.uuidString,
              "applicantName": applicantName,
              "serviceTitle": serviceTitle,
              "employerId": employerId.uuidString,
              "applicationDate": Date().toISO8601String()
          ]
          
          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body)
          } catch {
              throw error
          }
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode == 200 {
              let responseString = String(data: data, encoding: .utf8) ?? "No response"
              print("✅ Sikeres jelentkezés: \(responseString)")
              return true
          } else {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }
      
      func checkIfApplied(workId: UUID) async -> Bool {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              return false
          }
          
          guard let userId = UserDefaults.standard.string(forKey: "userId"),
                let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/applications/\(userId)") else {
              return false
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "GET"
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          do {
              let (data, response) = try await URLSession.shared.data(for: request)
              
              guard let httpResponse = response as? HTTPURLResponse else {
                  return false
              }
              
              if httpResponse.statusCode == 200 {
                  let applicationResponse = try JSONDecoder().decode(ApplicationStatusResponse.self, from: data)
                  return applicationResponse.hasApplied
              }
          } catch {
              print("❌ Hiba a jelentkezés állapotának lekérésekor: \(error)")
          }
          
          return false
      }
      
      func getWorkApplications(workId: UUID) async throws -> [WorkApplication] {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/applications") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "GET"
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode == 200 {
              let applicationsResponse = try JSONDecoder().decode(WorkApplicationsResponse.self, from: data)
              return applicationsResponse.applications
          } else {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }
  
    // MARK: - Token Management
    public func getAuthToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }

    private func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    private func removeAuthToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }

    private func saveUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
    }

    private func getUserId() -> String? {
        return UserDefaults.standard.string(forKey: userIdKey)
    }

    // MARK: - Verification Methods
    func fetchUserVerificationStatus(userId: UUID, completion: @escaping (Bool?) -> Void) {
        guard let token = getAuthToken() else {
            completion(nil)
            return
        }
        
        let url = URL(string: "\(baseURL)/api/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Verification status fetch error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userData = json["user"] as? [String: Any] {
                    let isVerified = userData["isVerified"] as? Bool ?? false
                    print("✅ Verification status fetched: \(isVerified)")
                    completion(isVerified)
                } else {
                    completion(nil)
                }
            } catch {
                print("❌ Verification status parse error: \(error)")
                completion(nil)
            }
        }.resume()
    }

    func updateUserVerificationStatus(user: User, isVerified: Bool, completion: @escaping (Bool) -> Void) {
        guard let token = getAuthToken() else {
            completion(false)
            return
        }
        
        // Email alapján frissítünk
        let url = URL(string: "\(baseURL)/auth/verify-by-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": user.email,
            "isVerified": isVerified
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Request body error: \(error)")
            completion(false)
            return
        }
        
        print("🔐 Sending verification update for: \(user.email) -> \(isVerified)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Verification update error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                completion(false)
                return
            }
            
            print("📡 Verification response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                print("✅ Verification status updated to: \(isVerified)")
                completion(true)
            } else {
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Server error: \(responseString)")
                }
                completion(false)
            }
        }.resume()
    }
    
    // ServerAuthManager.swift - Add hozzá ezt a metódust
    func refreshCurrentUser(completion: @escaping (Bool) -> Void) {
        guard let token = getAuthToken() else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ User refresh error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(false)
                    return
                }
                
                do {
                    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                    let user = User.fromServerUser(userResponse.user)
                    
                    self.currentUser = user
                    self.userManager.currentUser = user
                    
                    // Lokális mentés
                    self.saveUserLocally(user)
                    
                    print("✅ User data refreshed - Verified: \(user.isVerified)")
                    completion(true)
                } catch {
                    print("❌ User refresh decode error: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Helper metódusok
    private func saveUserLocally(_ user: User) {
        // Itt mentheted a user adatokat lokálisan, ha szükséges
        // Például CoreData-ba vagy UserDefaults-ba
        do {
            let userData = try JSONEncoder().encode(user)
            UserDefaults.standard.set(userData, forKey: "currentUserData")
        } catch {
            print("Error saving user locally: \(error)")
        }
    }
    
    private func loadUserLocally() -> User? {
        guard let userData = UserDefaults.standard.data(forKey: "currentUserData") else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(User.self, from: userData)
        } catch {
            print("Error loading user locally: \(error)")
            return nil
        }
    }
    
    // MARK: - Auto bejelentkezés
    func autoLogin(completion: @escaping (Bool) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(false)
            return
        }
        
        
        
        // Először próbáljuk meg a lokális user adatokat betölteni
        if let localUser = loadUserLocally() {
            self.currentUser = localUser
            self.userManager.currentUser = localUser
            self.isAuthenticated = true
            completion(true)
            return
        }
        
        // Ha nincs lokális adat, akkor kérjük le a szerverről
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Auto login error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(false)
                    return
                }
                
                do {
                    let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                    let user = User.fromServerUser(userResponse.user)
                    
                    self.isAuthenticated = true
                    self.currentUser = user
                    self.userManager.currentUser = user
                    
                    self.saveUserLocally(user)
                    completion(true)
                } catch {
                    print("Auto login decode error: \(error)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Kijelentkezés
    func logout() {
        isAuthenticated = false
        currentUser = nil
        userManager.currentUser = nil
        userManager.isAuthenticated = false
        
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "currentUserData")
    }
    
    
    func publishWork(_ workData: WorkData) async throws -> Bool {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ Nincs érvényes token")
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/works/publish") else {
            print("❌ Érvénytelen URL")
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Dátum formázás
        let dateFormatter = ISO8601DateFormatter()
        
        // WorkData átalakítása dictionary-vé
        let workDict: [String: Any] = [
            "id": workData.id.uuidString,
            "title": workData.title,
            "employerName": workData.employerName,
            "employerID": workData.employerID.uuidString,
            "employeeID": workData.employeeID?.uuidString ?? NSNull(),
            "wage": workData.wage,
            "paymentType": workData.paymentType,
            "statusText": workData.statusText,
            "startTime": workData.startTime.flatMap { dateFormatter.string(from: $0) } ?? NSNull(),
            "endTime": workData.endTime.flatMap { dateFormatter.string(from: $0) } ?? NSNull(),
            "duration": workData.duration ?? NSNull(),
            "progress": workData.progress,
            "location": workData.location,
            "skills": workData.skills,
            "category": workData.category ?? "",
            "description": workData.description ?? "",
            "createdAt": dateFormatter.string(from: workData.createdAt)
        ]
        
        print("📤 Küldött munka adatai a szervernek:")
        print("  - ID: \(workData.id.uuidString)")
        print("  - Cím: \(workData.title)")
        print("  - Munkáltató: \(workData.employerName)")
        print("  - Munkáltató ID: \(workData.employerID.uuidString)")
        print("  - Bér: \(workData.wage)")
        print("  - Hely: \(workData.location)")
        print("  - Készségek: \(workData.skills)")
        print("  - Létrehozva: \(dateFormatter.string(from: workData.createdAt))")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: workDict)
            print("✅ JSON adatok sikeresen létrehozva")
        } catch {
            print("❌ JSON hiba: \(error)")
            throw error
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Érvénytelen válasz")
                throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
            }
            
            print("📥 Szerver válasza: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 201 {
                let responseString = String(data: data, encoding: .utf8) ?? "No response"
                print("✅ Szerver válasza: \(responseString)")
                return true
            } else {
                let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                print("❌ Szerver hiba: \(errorResponse.message)")
                throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
        } catch {
            print("❌ Hálózati hiba: \(error)")
            throw error
        }
    }
    
    
    
    // ServerAuthManager.swift - Javított fetchWorks debug információkkal

    func fetchWorks(employerID: UUID? = nil, limit: Int = 50) async throws -> [WorkData] {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/works")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let employerID = employerID {
            queryItems.append(URLQueryItem(name: "employerID", value: employerID.uuidString))
        }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📥 Works lekérés: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        print("📥 Szerver válasz: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            do {
                // Először próbáljuk meg dekódolni a választ
                let jsonString = String(data: data, encoding: .utf8) ?? "N/A"
                print("📥 Raw JSON válasz: \(jsonString)")
                
                let worksResponse = try JSONDecoder().decode(WorksResponse.self, from: data)
                print("✅ Sikeresen dekódolva \(worksResponse.works.count) munka")
                
                // Debug információk
                worksResponse.works.forEach { work in
                    print("  📋 Munka: \(work.title) - Skills: \(work.skills)")
                }
                
                return worksResponse.works.map { $0.toWorkData() }
            } catch {
                print("❌ JSON dekódolási hiba: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                // További részletek a hibáról
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("❌ Type mismatch: expected \(type), at path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("❌ Value not found: \(type), at path: \(context.codingPath)")
                    case .keyNotFound(let key, let context):
                        print("❌ Key not found: \(key), at path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("❌ Data corrupted: \(context)")
                    @unknown default:
                        print("❌ Unknown decoding error")
                    }
                }
                
                throw error
            }
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }
        func fetchWorkApplications(workId: UUID) async throws -> [WorkApplication] {
            guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
            }
            
            guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/applications") else {
                throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
            }
            
            if httpResponse.statusCode == 200 {
                let applicationsResponse = try JSONDecoder().decode(WorkApplicationsResponse.self, from: data)
                return applicationsResponse.applications
            } else {
                let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
                throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
            }
        }
        
    func updateApplicationStatus(applicationId: String, status: String) async throws {
          guard isAuthenticated,
                let token = UserDefaults.standard.string(forKey: "authToken"),
                !token.isEmpty else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/applications/\(applicationId)/status") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "PUT"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          request.timeoutInterval = 30
          
          let body: [String: Any] = ["status": status]
          
          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body)
          } catch {
              throw error
          }
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode != 200 {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }
    func fetchWorkById(workId: UUID) async throws -> WorkData {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let workResponse = try JSONDecoder().decode(WorkResponse.self, from: data)
                return workResponse.work.toWorkData()
            } catch {
                print("❌ Work decode error: \(error)")
                throw error
            }
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }
    
    func fetchActiveWorkForEmployee(employeeId: UUID) async throws -> WorkData? {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/employee/\(employeeId.uuidString)/active") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "GET"
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode == 200 {
              do {
                  let workResponse = try JSONDecoder().decode(WorkResponse.self, from: data)
                  return workResponse.work.toWorkData()
              } catch {
                  print("❌ Active work decode error: \(error)")
                  return nil
              }
          } else if httpResponse.statusCode == 404 {
              // Nincs aktív munka
              return nil
          } else {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }
      
      // MUNKA FRISSÍTÉSE DOLGOZÓVAL
      func assignEmployeeToWork(workId: UUID, employeeId: UUID) async throws -> Bool {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/assign") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "PUT"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          let body: [String: Any] = [
              "employeeID": employeeId.uuidString,
              "statusText": "Folyamatban"
          ]
          
          do {
              request.httpBody = try JSONSerialization.data(withJSONObject: body)
          } catch {
              throw error
          }
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode == 200 {
              return true
          } else {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }
      
      // MANUÁLIS KÓD ALAPJÁN MUNKA LEKÉRÉSE
      func fetchWorkByManualCode(manualCode: String) async throws -> WorkData {
          guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
              throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
          }
          
          guard let url = URL(string: "\(baseURL)/works/code/\(manualCode)") else {
              throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
          }
          
          var request = URLRequest(url: url)
          request.httpMethod = "GET"
          request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          
          let (data, response) = try await URLSession.shared.data(for: request)
          
          guard let httpResponse = response as? HTTPURLResponse else {
              throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
          }
          
          if httpResponse.statusCode == 200 {
              do {
                  let workResponse = try JSONDecoder().decode(WorkResponse.self, from: data)
                  return workResponse.work.toWorkData()
              } catch {
                  print("❌ Work by code decode error: \(error)")
                  throw error
              }
          } else {
              let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
              throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
          }
      }

    func updateWorkEmployee(workId: UUID, employeeID: UUID, status: String) async throws -> Bool {
        guard isAuthenticated,
              let token = UserDefaults.standard.string(forKey: "authToken"),
              !token.isEmpty else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/employee") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "employeeID": employeeID.uuidString,
            "statusText": status
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }
    
    
    func deleteWork(_ workId: UUID, employerID: UUID) async throws -> Bool {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["employerID": employerID.uuidString]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }
    
    // MUNKA STÁTUSZ FRISSÍTÉSE
    func updateWorkStatus(workId: UUID, status: String, employerID: UUID) async throws -> Bool {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/works/\(workId.uuidString)/status") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "statusText": status,
            "employerID": employerID.uuidString
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        if httpResponse.statusCode == 200 {
            return true
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }
    
    // Add hozzá ezt a funkciót a ServerAuthManager-hez
    func checkServerStatus() async -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return httpResponse.statusCode == 200
        } catch {
            print("❌ Szerver nem elérhető: \(error)")
            return false
        }
    }
    
    
    
    
    func uploadProfileImage(_ imageData: Data, completion: @escaping (Bool) -> Void) {
        guard isAuthenticated,
              let token = UserDefaults.standard.string(forKey: "authToken"),
              let userId = UserDefaults.standard.string(forKey: "userId") else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/auth/profile-image") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Base64 kódolás
        let base64String = imageData.base64EncodedString()
        
        let body: [String: Any] = [
            "userId": userId,
            "profileImageData": base64String
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error creating request body: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Profile image upload error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    print("✅ Profilkép sikeresen feltöltve")
                    
                    // Lokálisan is mentjük a képet
                    self.saveProfileImageLocally(imageData)
                    completion(true)
                } else {
                    print("❌ Profilkép feltöltési hiba: \(httpResponse.statusCode)")
                    completion(false)
                }
            }
        }.resume()
    }

    func fetchProfileImage(completion: @escaping (Data?) -> Void) {
        guard let userId = UserDefaults.standard.string(forKey: "userId"),
              let token = UserDefaults.standard.string(forKey: "authToken") else {
            completion(nil)
            return
        }
        
        // Először próbáljuk meg a lokális képet
        if let localImageData = self.loadProfileImageLocally() {
            completion(localImageData)
            return
        }
        
        // Ha nincs lokális, akkor a szerverről töltjük le
        guard let url = URL(string: "\(baseURL)/auth/profile-image/\(userId)") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Profile image fetch error: \(error)")
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(ProfileImageResponse.self, from: data)
                    
                    if let base64String = response.profileImageData,
                       let imageData = Data(base64Encoded: base64String) {
                        // Lokálisan mentjük a képet
                        self.saveProfileImageLocally(imageData)
                        completion(imageData)
                    } else {
                        completion(nil)
                    }
                } catch {
                    print("Profile image decode error: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }

    private func saveProfileImageLocally(_ imageData: Data) {
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            UserDefaults.standard.set(imageData, forKey: "profileImage_\(userId)")
        }
    }

    private func loadProfileImageLocally() -> Data? {
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            return UserDefaults.standard.data(forKey: "profileImage_\(userId)")
        }
        return nil
    }

    
    
    
}

// Add this extension for date handling
extension JSONDecoder.DateDecodingStrategy {
    static let customISO8601 = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback formatter without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date string \(dateString)"
        )
    }
}

extension JSONDecoder {
    static let skillTradeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .customISO8601
        return decoder
    }()
}

// MARK: - Response Modellek
struct ProfileImageResponse: Codable {
    let profileImageData: String?
}

struct WorksResponse: Codable {
    let works: [ServerWork]
    let count: Int
}

struct ServerWork: Codable {
    let id: String
    let title: String
    let employerName: String
    let employerID: String
    let employeeID: String?
    let wage: Double
    let paymentType: String
    let statusText: String
    let startTime: String?
    let endTime: String?
    let duration: TimeInterval?
    let progress: Double
    let location: String
    let skills: [String]
    let category: String?
    let description: String?
    let createdAt: String
    let updatedAt: String
    let employerProfileImage: String?
    
    
    init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          
          id = try container.decode(String.self, forKey: .id)
          title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Névtelen munka"
          employerName = try container.decodeIfPresent(String.self, forKey: .employerName) ?? "Ismeretlen munkáltató"
          employerID = try container.decodeIfPresent(String.self, forKey: .employerID) ?? ""
          employeeID = try container.decodeIfPresent(String.self, forKey: .employeeID)
          wage = try container.decodeIfPresent(Double.self, forKey: .wage) ?? 0.0
          paymentType = try container.decodeIfPresent(String.self, forKey: .paymentType) ?? "Ismeretlen"
          statusText = try container.decodeIfPresent(String.self, forKey: .statusText) ?? "Publikálva"
          startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
          endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
          duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
          progress = try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
          location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category)
          description = try container.decodeIfPresent(String.self, forKey: .description)
          createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? Date().toISO8601String()
          updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? Date().toISO8601String()
          employerProfileImage = try container.decodeIfPresent(String.self, forKey: .employerProfileImage)
      }
    
    func toWorkData() -> WorkData {
        let dateFormatter = ISO8601DateFormatter()
        
        return WorkData(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            employerName: employerName,
            employerID: UUID(uuidString: employerID) ?? UUID(),
            employeeID: employeeID.flatMap { UUID(uuidString: $0) },
            wage: wage,
            paymentType: paymentType,
            statusText: statusText,
            startTime: startTime.flatMap { dateFormatter.date(from: $0) },
            endTime: endTime.flatMap { dateFormatter.date(from: $0) },
            duration: duration,
            progress: progress,
            location: location,
            skills: skills,
            category: category,
            description: description,
            createdAt: dateFormatter.date(from: createdAt) ?? Date()
        )
    }
    
    private func parseSkills(_ skillsString: String) -> [String] {
            guard let data = skillsString.data(using: .utf8),
                  let skillsArray = try? JSONSerialization.jsonObject(with: data) as? [String] else {
                return []
            }
            return skillsArray
        }
    
    enum CodingKeys: String, CodingKey {
            case id, title, employerName, employerID, employeeID, wage, paymentType
            case statusText, startTime, endTime, duration, progress, location
            case skills, category, description, createdAt, updatedAt, employerProfileImage
        }
}


struct LoginResponse: Codable {
    let token: String
    let user: ServerUser
}

struct RegisterResponse: Codable {
    let token: String
    let user: ServerUser
}

struct UserResponse: Codable {
    let user: ServerUser
}

struct ErrorResponse: Codable {
    let message: String
    let error: String?
}

struct ApplicationStatusResponse: Codable {
    let hasApplied: Bool
    let applicationDate: String?
}

struct WorkApplicationsResponse: Codable {
    let applications: [WorkApplication]
    let count: Int
}

struct WorkApplication: Codable, Identifiable {
    let id: String
    let workId: String
    let applicantId: String
    let applicantName: String
    let applicationDate: String
    let status: ApplicationStatus
}

enum ApplicationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case withdrawn = "withdrawn"
}

struct WorkResponse: Codable {
    let work: ServerWork
}

struct WorkCodeResponse: Codable {
    let workId: String
    let isValid: Bool
}

// Add hozzá a ServerAuthManager.swift fájl végéhez
extension Date {
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
