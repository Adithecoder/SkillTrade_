import Foundation
import Combine
import AuthenticationServices
import CryptoKit

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
    
    func loginWithGoogle(token: String, completion: @escaping (Bool) -> Void) {
           isLoading = true
           error = nil
           
           guard let url = URL(string: "\(baseURL)/auth/google") else {
               error = "Érvénytelen URL"
               isLoading = false
               completion(false)
               return
           }
           
           var request = URLRequest(url: url)
           request.httpMethod = "POST"
           request.setValue("application/json", forHTTPHeaderField: "Content-Type")
           
           let body: [String: Any] = [
               "token": token
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
                   
                   print("🔐 Google login response status: \(httpResponse.statusCode)")
                   
                   if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                       do {
                           let authResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                           let user = User.fromServerUser(authResponse.user)
                           
                           self.isAuthenticated = true
                           self.currentUser = user
                           self.userManager.currentUser = user
                           self.userManager.isAuthenticated = true
                           
                           // Token mentése
                           UserDefaults.standard.set(authResponse.token, forKey: "authToken")
                           UserDefaults.standard.set(authResponse.user.id, forKey: "userId")
                           UserDefaults.standard.set(true, forKey: "isLoggedIn")
                           
                           // Lokális mentés
                           self.saveUserLocally(user)
                           
                           print("✅ Google login successful")
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
                           self.error = "Google bejelentkezési hiba (\(httpResponse.statusCode)): \(responseString)"
                       }
                       completion(false)
                   }
               }
           }.resume()
       }
    // ServerAuthManager.swift - Javított login metódus
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
                
                print("🔐 LOGIN - Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .customISO8601
                        
                        let loginResponse = try decoder.decode(LoginResponse.self, from: data)
                        let user = User.fromServerUser(loginResponse.user)
                        
                        self.isAuthenticated = true
                        self.currentUser = user
                        
                        // UserManager frissítése
                        self.userManager.currentUser = user
                        self.userManager.isAuthenticated = true
                        
                        // TOKEN MENTÉS - JAVÍTOTT VERZIÓ
                        print("💾 TOKEN SAVE - Saving token: \(loginResponse.token.prefix(20))...")
                        
                        UserDefaults.standard.set(loginResponse.token, forKey: "authToken")
                        UserDefaults.standard.set(loginResponse.user.id, forKey: "userId")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        
                        // Azonnali szinkronizálás
                        UserDefaults.standard.synchronize()
                        
                        // Ellenőrzés
                        let savedToken = UserDefaults.standard.string(forKey: "authToken")
                        print("💾 TOKEN SAVE - Verification: \(savedToken != nil ? "SUCCESS" : "FAILED")")
                        print("💾 TOKEN SAVE - Token length: \(savedToken?.count ?? 0)")
                        
                        // Lokális user adatok mentése
                        self.saveUserLocally(user)
                        
                        completion(true)
                    } catch {
                        print("JSON decode error: \(error)")
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
    
    // ServerAuthManager.swift - Token recovery
    func validateAndRecoverToken(completion: @escaping (Bool) -> Void) {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("❌ TOKEN RECOVERY - No token found")
            completion(false)
            return
        }
        
        print("🔐 TOKEN RECOVERY - Validating token: \(token.prefix(20))...")
        
        // Validate token with server
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
                    print("❌ TOKEN RECOVERY - Network error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ TOKEN RECOVERY - Invalid response")
                    completion(false)
                    return
                }
                
                print("🔐 TOKEN RECOVERY - Validation response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ TOKEN RECOVERY - Token is valid")
                    self.isAuthenticated = true
                    
                    // Load user data
                    if let data = data {
                        do {
                            let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
                            let user = User.fromServerUser(userResponse.user)
                            self.currentUser = user
                            self.userManager.currentUser = user
                            self.saveUserLocally(user)
                        } catch {
                            print("❌ TOKEN RECOVERY - User data decode error: \(error)")
                        }
                    }
                    
                    completion(true)
                } else {
                    print("❌ TOKEN RECOVERY - Token is invalid")
                    // Clear invalid token
                    self.clearAuthData()
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func clearAuthData() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "currentUserData")
        self.isAuthenticated = false
        self.currentUser = nil
        self.userManager.currentUser = nil
        self.userManager.isAuthenticated = false
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
    func getAuthToken() -> String? {
        let token = UserDefaults.standard.string(forKey: "authToken")
        print("🔐 TOKEN DEBUG - Retrieved token: \(token != nil ? "YES" : "NO")")
        print("🔐 TOKEN DEBUG - Token length: \(token?.count ?? 0)")
        if let token = token {
            print("🔐 TOKEN DEBUG - Token prefix: \(token.prefix(20))...")
        }
        return token
    }

    private func saveAuthToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.synchronize() // Force immediate save
        print("💾 TOKEN SAVED - Length: \(token.count)")
    }

    private func removeAuthToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }
    func hasValidToken() -> Bool {
        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              !token.isEmpty,
              UserDefaults.standard.bool(forKey: "isLoggedIn") else {
            return false
        }
        return true
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
    
    // MARK: - Review Management Methods

    // ÚJ ÉRTÉKELÉS LÉTREHOZÁSA
    func createReview(_ reviewRequest: CreateReviewRequest) async throws -> Bool {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/reviews") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(reviewRequest)
        } catch {
            throw error
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen válasz"])
        }
        
        if httpResponse.statusCode == 201 {
            print("✅ Értékelés sikeresen létrehozva")
            return true
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }

    // FELHASZNÁLÓ ÉRTÉKELÉSEINEK LEKÉRÉSE
    func fetchUserReviews(userId: UUID, type: String? = nil) async throws -> [Review2] {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/reviews/user/\(userId.uuidString)")
        if let type = type {
            urlComponents?.queryItems = [URLQueryItem(name: "type", value: type)]
        }
        
        guard let url = urlComponents?.url else {
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
                let reviewsResponse = try JSONDecoder().decode(ReviewsResponse.self, from: data)
                return reviewsResponse.reviews.map { $0.toReview() }
            } catch {
                print("❌ Reviews decode error: \(error)")
                throw error
            }
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }

    // MUNKA ÉRTÉKELÉSEINEK LEKÉRÉSE
    func fetchWorkReviews(workId: UUID) async throws -> [Review2] {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/reviews/work/\(workId.uuidString)") else {
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
                let reviewsResponse = try JSONDecoder().decode(ReviewsResponse.self, from: data)
                return reviewsResponse.reviews.map { $0.toReview() }
            } catch {
                print("❌ Work reviews decode error: \(error)")
                throw error
            }
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }

    // SAJÁT ÉRTÉKELÉSEIM LEKÉRÉSE
    func fetchMyReviews(reviewerId: UUID) async throws -> [Review2] {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/reviews/my-reviews/\(reviewerId.uuidString)") else {
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
                let reviewsResponse = try JSONDecoder().decode(ReviewsResponse.self, from: data)
                return reviewsResponse.reviews.map { $0.toReview() }
            } catch {
                print("❌ My reviews decode error: \(error)")
                throw error
            }
        } else {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            throw NSError(domain: "Server", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.message])
        }
    }

    // ÉRTÉKELÉS TÖRLÉSE
    func deleteReview(reviewId: UUID) async throws -> Bool {
        guard isAuthenticated, let token = UserDefaults.standard.string(forKey: "authToken") else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nincs érvényes token"])
        }
        
        guard let url = URL(string: "\(baseURL)/reviews/\(reviewId.uuidString)") else {
            throw NSError(domain: "Network", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
    // MARK: - Helper metódusok
    func saveUserLocally(_ user: User) {
    do {
        let data = try JSONEncoder().encode(user)
        UserDefaults.standard.set(data, forKey: "currentUser")
    } catch {
        print("Failed to encode user for local storage: \(error)")
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
        print("🔄 AUTO LOGIN - Starting auto login process")
        
        // First check if we have a token
        guard hasValidToken() else {
            print("❌ AUTO LOGIN - No valid token found")
            completion(false)
            return
        }
        
        // Try to load user data locally first (faster)
        if let localUser = loadUserLocally() {
            print("✅ AUTO LOGIN - Loaded user from local storage")
            self.currentUser = localUser
            self.userManager.currentUser = localUser
            self.isAuthenticated = true
            self.userManager.isAuthenticated = true
            completion(true)
            return
        }
        
        // If no local data, validate token with server
        validateAndRecoverToken { success in
            if success {
                print("✅ AUTO LOGIN - Successfully restored session")
                completion(true)
            } else {
                print("❌ AUTO LOGIN - Token validation failed")
                completion(false)
            }
        }
    }
    // Add to ServerAuthManager for debugging
    func debugTokenStatus() {
        let hasToken = UserDefaults.standard.string(forKey: "authToken") != nil
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        let tokenLength = UserDefaults.standard.string(forKey: "authToken")?.count ?? 0
        
        print("""
        🔐 TOKEN DEBUG:
        - Has Token: \(hasToken)
        - Is Logged In: \(isLoggedIn)
        - Token Length: \(tokenLength)
        - Server Auth: \(isAuthenticated)
        - User Manager Auth: \(userManager.isAuthenticated)
        """)
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
        print("  - Leírás: \(workData.description ?? "Nincs leírás")") // DEBUG
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
        
    // ServerAuthManager.swift-hez add hozzá:
    func removeEmployeeFromWork(workId: UUID, employeeId: UUID) async throws -> Bool {
        // Itt implementáld a backend hívást
        // amely eltávolítja a dolgozót a munkából
        return true // placeholder
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

    // MARK: - User Management Methods

    func updateUser(userId: UUID, updates: [String: Any], completion: @escaping (Bool, User?) -> Void) {
        guard let token = getAuthToken() else {
            completion(false, nil)
            return
        }
        
        // Küldjük el az email címet a frissítéshez (mert az egyedi)
        guard let userEmail = currentUser?.email else {
            completion(false, nil)
            return
        }
        
        // Email alapján frissítünk, mert az egyedi
        let url = URL(string: "\(baseURL)/auth/verify-by-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Csak az email és isVerified mezőket küldjük
        let body: [String: Any] = [
            "email": userEmail,
            "isVerified": updates["isVerified"] as? Bool ?? false
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("🔧 Sending verification update: \(body)")
        } catch {
            print("❌ Request body error: \(error)")
            completion(false, nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Update user error: \(error)")
                completion(false, nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                completion(false, nil)
                return
            }
            
            print("📡 Update user response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Sikeres frissítés - lokálisan is frissítsük a usert
                if var currentUser = self.currentUser {
                    currentUser.isVerified = updates["isVerified"] as? Bool ?? false
                    self.currentUser = currentUser
                    self.userManager.currentUser = currentUser
                    
                    print("✅ User verification updated locally: \(currentUser.isVerified)")
                    completion(true, currentUser)
                } else {
                    completion(true, nil)
                }
            } else {
                print("❌ Update user failed with status: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Server response: \(responseString)")
                }
                completion(false, nil)
            }
        }.resume()
    }
    
    
    func suspendUser(userId: UUID, suspended: Bool, completion: @escaping (Bool) -> Void) {
        guard let token = getAuthToken() else {
            completion(false)
            return
        }
        
        let url = URL(string: "\(baseURL)/auth/users/\(userId.uuidString)/suspend")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["suspended": suspended]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Request body error: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Suspend user error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ User suspension updated: \(suspended)")
                completion(true)
            } else {
                print("❌ Suspend user failed with status: \(httpResponse.statusCode)")
                completion(false)
            }
        }.resume()
    }

    // ServerAuthManager.swift - DEBUG verzió
    func deleteUser(userId: UUID, completion: @escaping (Bool) -> Void) {
        guard let token = getAuthToken() else {
            print("❌ DELETE DEBUG - No auth token")
            completion(false)
            return
        }
        
        let urlString = "\(baseURL)/auth/users/\(userId.uuidString)"
        print("🗑️ DELETE DEBUG - URL: \(urlString)")
        print("🗑️ DELETE DEBUG - UserId: \(userId.uuidString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ DELETE DEBUG - Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🗑️ DELETE DEBUG - Sending request...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ DELETE DEBUG - Network error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ DELETE DEBUG - Invalid response")
                completion(false)
                return
            }
            
            print("🗑️ DELETE DEBUG - Response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("🗑️ DELETE DEBUG - Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ DELETE DEBUG - User deleted successfully")
                completion(true)
            } else {
                print("❌ DELETE DEBUG - Delete failed with status: \(httpResponse.statusCode)")
                completion(false)
            }
        }.resume()
    }
    
    // ServerAuthManager.swift - Email alapú törlés
    func deleteUserByEmail(userEmail: String, completion: @escaping (Bool) -> Void) {
        guard let token = getAuthToken() else {
            print("❌ EMAIL DELETE - No auth token")
            completion(false)
            return
        }
        
        // URL encode the email
        guard let encodedEmail = userEmail.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            print("❌ EMAIL DELETE - Cannot encode email")
            completion(false)
            return
        }
        
        let urlString = "\(baseURL)/auth/users/by-email/\(encodedEmail)"
        print("🗑️ EMAIL DELETE - URL: \(urlString)")
        print("🗑️ EMAIL DELETE - Email: \(userEmail)")
        
        guard let url = URL(string: urlString) else {
            print("❌ EMAIL DELETE - Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        print("🗑️ EMAIL DELETE - Sending request...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ EMAIL DELETE - Network error: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ EMAIL DELETE - Invalid response")
                completion(false)
                return
            }
            
            print("🗑️ EMAIL DELETE - Response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("🗑️ EMAIL DELETE - Response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ EMAIL DELETE - User deleted successfully")
                completion(true)
            } else {
                print("❌ EMAIL DELETE - Delete failed with status: \(httpResponse.statusCode)")
                completion(false)
            }
        }.resume()
    }
    
    // Add this method to ServerAuthManager class
    private func parseSimpleUser(_ userDict: [String: Any]) -> User? {
        print("🔍 Parsing user from update: \(userDict)")
        
        // ID kezelés
        let id: UUID
        if let idInt = userDict["id"] as? Int {
            // SQLite integer ID - generáljunk belőle UUID-t
            id = UUID()
        } else if let idString = userDict["id"] as? String, let uuid = UUID(uuidString: idString) {
            id = uuid
        } else if let idString = userDict["_id"] as? String, let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            print("❌ Invalid ID in userDict: \(userDict["id"] ?? "nil")")
            return nil
        }
        
        guard let name = userDict["name"] as? String,
              let email = userDict["email"] as? String,
              let username = userDict["username"] as? String else {
            print("❌ Missing required fields in userDict")
            return nil
        }
        
        let age = userDict["age"] as? Int ?? 0
        let isVerified = userDict["isVerified"] as? Bool ?? false
        
        // User role parsing
        let userRoleString = userDict["userRole"] as? String ?? "client"
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
        let statusString = userDict["status"] as? String ?? "active"
        let status: UserStatus
        switch statusString.lowercased() {
        case "active":
            status = .active
        case "suspended":
            status = .suspended
        default:
            status = .pending
        }
        
        // Date parsing
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = (userDict["createdAt"] as? String).flatMap { dateFormatter.date(from: $0) }
        let updatedAt = (userDict["updatedAt"] as? String).flatMap { dateFormatter.date(from: $0) }
        
        return User(
            id: id,
            name: name,
            email: email,
            username: username,
            bio: userDict["bio"] as? String ?? "",
            rating: userDict["rating"] as? Double ?? 0.0,
            reviews: [],
            location: Location(
                city: userDict["location_city"] as? String ?? "",
                country: userDict["location_country"] as? String ?? ""
            ),
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
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
}
class GoogleSignInManager: NSObject, ObservableObject {
    let authManager = ServerAuthManager.shared
    static let sharedGoogle = GoogleSignInManager()
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
        @Published var error: String? = nil
    private override init() {}
    
    public var baseURL: String {
        return "http://localhost:3000/api" // vagy amit használsz
    }
    
    
    
    // Google bejelentkezés indítása
    func signInWithGoogle(presentingViewController: UIViewController? = nil, completion: @escaping (Bool, String?) -> Void) {
        // Itt implementáld a Google bejelentkezést
        // Ehhez szükséges a GoogleSignIn SDK hozzáadása a projekthez
        
        // Átmeneti megoldás - redirect a Google OAuth oldalra
        if let googleAuthURL = URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(getGoogleClientID())&redirect_uri=\(getRedirectURI())&response_type=code&scope=email%20profile") {
            UIApplication.shared.open(googleAuthURL)
        }
    }
    // ServerAuthManager.swift - Add hozzá ezt a metódust a ServerAuthManager osztályba

    // ServerAuthManager.swift - Add hozzá EZT a metódust az OSZTÁLYON BELÜLRE

    // MARK: - Apple Login
    // ServerAuthManager.swift - Add hozzá EZT a metódust az OSZTÁLYON BELÜLRE

    // MARK: - Apple Login
    func loginWithApple(identityToken: String, completion: @escaping (Bool) -> Void) {
        // Használd a ServerAuthManager property-ket, ne a GoogleSignInManager-ét
        self.isLoading = true
        self.error = nil
        
        guard let url = URL(string: "\(self.baseURL)/auth/apple") else {
            self.error = "Érvénytelen URL"
            self.isLoading = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Apple adatok összeállítása
        let body: [String: Any] = [
            "identityToken": identityToken,
            "userIdentifier": "",
            "email": "",
            "fullName": ""
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
                
                print("🔐 Apple login response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    do {
                        let authResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                        let user = User.fromServerUser(authResponse.user)
                        
                        self.isAuthenticated = true
                        self.currentUser = user
                        self.currentUser = user
                        self.isAuthenticated = true
                        
                        // Token mentése
                        UserDefaults.standard.set(authResponse.token, forKey: "authToken")
                        UserDefaults.standard.set(authResponse.user.id, forKey: "userId")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        
                        // Lokális mentés
//                        self.saveUserLocally(user)
                        
                        print("✅ Apple login successful")
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
                        self.error = "Apple bejelentkezési hiba (\(httpResponse.statusCode)): \(responseString)"
                    }
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func getGoogleClientID() -> String {
        return "your-google-client-id" // Cseréld le a valódi client ID-re
    }
    
    private func getRedirectURI() -> String {
        return "your-app://google-auth" // Cseréld le a valódi redirect URI-ra
    }
    
    // Google token küldése a szervernek
    func sendGoogleTokenToServer(_ token: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(ServerAuthManager.shared.baseURL)/auth/google") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "token": token
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Google auth error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      let data = data else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    do {
                        let authResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                        let user = User.fromServerUser(authResponse.user)
                        
                        // Token mentése
                        UserDefaults.standard.set(authResponse.token, forKey: "authToken")
                        UserDefaults.standard.set(authResponse.user.id, forKey: "userId")
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                        
                        // UserManager frissítése
                        ServerAuthManager.shared.isAuthenticated = true
                        ServerAuthManager.shared.currentUser = user
                        UserManager.shared.currentUser = user
                        UserManager.shared.isAuthenticated = true
                        
                        // Lokális mentés
                        ServerAuthManager.shared.saveUserLocally(user)
                        
                        print("✅ Google login successful")
                        completion(true)
                    } catch {
                        print("❌ Google auth decode error: \(error)")
                        completion(false)
                    }
                } else {
                    print("❌ Google auth failed with status: \(httpResponse.statusCode)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Ideiglenes megoldás - add direkt a ServerAuthManager osztályba
    public func handleAppleLogin(identityToken: String, completion: @escaping (Bool) -> Void) {
        print("Processing Apple login with token...")
        // Ideiglenes implementáció
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            completion(true)
        }
    }
        // Segéd struktúra
        struct AppleLoginData {
            let identityToken: String
        }
        
        private func sendLoginRequest(loginData: AppleLoginData, completion: @escaping (Result<User, Error>) -> Void) {
            // Implementáld a szerver kommunikációt
            // ...
        }
    }



class AppleSignInManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleSignInManager()
    
    public var currentNonce: String?
    var onCompletion: ((Bool, String?) -> Void)?
    

    
    // ASAuthorizationControllerDelegate metódusok
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                onCompletion?(false, "Invalid state: A login callback was received, but no login request was sent.")
                return
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                onCompletion?(false, "Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                onCompletion?(false, "Unable to serialize token string from data")
                return
            }
            
            // Itt küldd el a token-t a szervernek
            // Ehhez szükséges egy /api/auth/apple endpoint a szerveren
            onCompletion?(true, idTokenString)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(false, error.localizedDescription)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first!
    }
    
    // Segéd függvények
    public func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    public func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
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


// MARK: - Review Modellek
struct CreateReviewRequest: Codable {
    let reviewerId: UUID
    let reviewerName: String
    let reviewedUserId: UUID
    let workId: UUID
    let rating: Int
    let comment: String?
    let isReliable: Bool?
    let isPaid: Bool?
    let type: String // "employee" vagy "employer"
}

struct ReviewResponse: Codable, Identifiable {
    let id: String
    let reviewerId: String
    let reviewerName: String
    let reviewedUserId: String
    let workId: String
    let workTitle: String?
    let reviewedUserName: String?
    let rating: Int
    let comment: String?
    let isReliable: Bool
    let isPaid: Bool
    let type: String
    let createdAt: String
    let updatedAt: String
    
    func toReview() -> Review2 {
        let dateFormatter = ISO8601DateFormatter()
        
        return Review2(
            id: UUID(uuidString: id) ?? UUID(),
            reviewerId: UUID(uuidString: reviewerId) ?? UUID(),
            reviewerName: reviewerName,
            reviewedUserId: UUID(uuidString: reviewedUserId) ?? UUID(),
            reviewedUserName: reviewedUserName,
            workId: UUID(uuidString: workId) ?? UUID(),
            workTitle: workTitle ?? "",
            rating: Double(rating),
            comment: comment ?? "",
            isReliable: isReliable,
            isPaid: isPaid,
            type: type == "employee" ? .employee : .employer,
            date: dateFormatter.date(from: createdAt) ?? Date()
        )
    }
}

struct ReviewsResponse: Codable {
    let reviews: [ReviewResponse]
    let count: Int
}

// MARK: - Review adatmodell
struct Review2: Identifiable {
    let id: UUID
    let reviewerId: UUID
    let reviewerName: String
    let reviewedUserId: UUID
    let reviewedUserName: String?
    let workId: UUID
    let workTitle: String
    let rating: Double
    let comment: String
    let isReliable: Bool
    let isPaid: Bool
    let type: ReviewType
    let date: Date
}

enum ReviewType {
    case employee
    case employer
}


// Add hozzá a ServerAuthManager.swift fájl végéhez
extension Date {
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}
