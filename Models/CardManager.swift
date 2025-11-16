//
//  CardManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/15/25.
//


//
//  CardManager.swift
//  SkillTrade_latest
//

import Foundation
import SwiftUI
import Combine

class CardManager: ObservableObject {
    static let shared = CardManager()
    
    @Published var userCards: [Card] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let cardsKey = "userCards"
    private let serverAuthManager = ServerAuthManager.shared
    
    private init() {
        loadCards()
    }
    
    // MARK: - Local Storage
    private func loadCards() {
        guard let data = UserDefaults.standard.data(forKey: cardsKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            userCards = try decoder.decode([Card].self, from: data)
        } catch {
            print("❌ Error loading cards: \(error)")
        }
    }
    
    private func saveCards() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(userCards)
            UserDefaults.standard.set(data, forKey: cardsKey)
        } catch {
            print("❌ Error saving cards: \(error)")
        }
    }
    
    // MARK: - Card Management
    func addCard(_ card: Card) async throws {
        await MainActor.run { isLoading = true }
        
        // Validate card
        guard CardValidation.isValidCardNumber(card.cardNumber) else {
            await MainActor.run { isLoading = false }
            throw CardError.invalidCardNumber
        }
        
        guard CardValidation.isValidExpiration(month: card.expirationMonth, year: card.expirationYear) else {
            await MainActor.run { isLoading = false }
            throw CardError.invalidExpiration
        }
        
        guard CardValidation.isValidCVV(card.cvv, cardType: card.cardType) else {
            await MainActor.run { isLoading = false }
            throw CardError.invalidCVV
        }
        
        do {
            print("💾 Kártya mentése a szerverre...")
            
            // Save to server FIRST
            try await saveCardToServer(card)
            
            print("✅ Kártya sikeresen mentve a szerverre")
            
            // Update local storage AFTER server success
            await MainActor.run {
                var newCard = card
                
                // If this is the first card, set as default
                if userCards.isEmpty {
                    newCard.isDefault = true
                }
                
                userCards.append(newCard)
                saveCards()
                isLoading = false
                error = nil
                
                print("💾 Kártya lokálisan is mentve, összesen: \(userCards.count) kártya")
            }
            
        } catch {
            await MainActor.run {
                self.error = "Kártya mentési hiba: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Kártya mentési hiba: \(error)")
            throw error
        }
    }
    func removeCard(_ card: Card) async throws {
        await MainActor.run { isLoading = true }
        
        do {
            // Remove from server
            try await removeCardFromServer(card)
            
            // Update local storage
            await MainActor.run {
                userCards.removeAll { $0.id == card.id }
                
                // If we removed the default card and there are other cards, set a new default
                if card.isDefault && !userCards.isEmpty {
                    userCards[0].isDefault = true
                    // Opcionálisan: szinkronizáld a szerverrel az új alapértelmezett kártyát
                }
                
                saveCards()
                isLoading = false
                error = nil
            }
            
        } catch {
            await MainActor.run {
                self.error = "Kártya törlési hiba: \(error.localizedDescription)"
                isLoading = false
            }
            print("❌ Kártya törlési hiba: \(error)")
            throw error
        }
    }
    
    func setDefaultCard(_ card: Card) async throws {
            await MainActor.run { isLoading = true }
            
            do {
                // Update on server
                try await setDefaultCardOnServer(card)
                
                // Update local storage
                await MainActor.run {
                    for index in userCards.indices {
                        userCards[index].isDefault = (userCards[index].id == card.id)
                    }
                    saveCards()
                    isLoading = false
                    error = nil
                }
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
                throw error
            }
        }
    func deleteCard(_ card: Card) async throws {
           await MainActor.run { isLoading = true }
           
           do {
               // Remove from server
               try await deleteCardFromServer(card)
               
               // Update local storage
               await MainActor.run {
                   userCards.removeAll { $0.id == card.id }
                   
                   // If we deleted the default card and there are other cards, set a new default
                   if card.isDefault && !userCards.isEmpty {
                       userCards[0].isDefault = true
                       // Optionally sync the new default card with server
                       Task {
                           try? await setDefaultCardOnServer(userCards[0])
                       }
                   }
                   
                   saveCards()
                   isLoading = false
                   error = nil
               }
               
           } catch {
               await MainActor.run {
                   self.error = "Kártya törlési hiba: \(error.localizedDescription)"
                   isLoading = false
               }
               throw error
           }
       }
    // MARK: - Server Communication
    private func saveCardToServer(_ card: Card) async throws {
        guard let token = serverAuthManager.getAuthToken() else {
            throw CardError.authenticationRequired
        }
        
        guard let url = URL(string: "\(serverAuthManager.baseURL)/payment/cards") else {
            throw CardError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let cardRequest = CardRequest(
            cardNumber: card.cardNumber,
            cardHolderName: card.cardHolderName,
            expirationMonth: card.expirationMonth,
            expirationYear: card.expirationYear,
            cvv: card.cvv,
            isDefault: card.isDefault
        )
        
        let encoder = JSONEncoder()
        do {
            request.httpBody = try encoder.encode(cardRequest)
            let requestBody = String(data: request.httpBody!, encoding: .utf8) ?? "N/A"
            print("📤 Küldött kártya adatok: \(requestBody)")
        } catch {
            print("❌ JSON encode error: \(error)")
            throw CardError.encodingFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CardError.networkError
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "No response"
        print("📥 Szerver válasz: \(httpResponse.statusCode) - \(responseString)")
        
        if httpResponse.statusCode != 201 {
            throw CardError.serverError(message: "Szerver hiba: \(httpResponse.statusCode) - \(responseString)")
        }
        
        // Sikeres mentés után ellenőrizzük a kártya létezését
        print("✅ Kártya sikeresen mentve a szerverre")
    }
    
    private func removeCardFromServer(_ card: Card) async throws {
        guard let token = serverAuthManager.getAuthToken() else {
            throw CardError.authenticationRequired
        }
        
        // JAVÍTOTT URL - használd a helyes endpoint-ot
        guard let url = URL(string: "\(serverAuthManager.baseURL)/payment/cards/\(card.id.uuidString)") else {
            throw CardError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🗑️ Kártya törlés küldés: \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CardError.networkError
        }
        
        print("🗑️ Törlés válasz: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Törlési hiba: \(errorString)")
            throw CardError.serverError(message: "Törlési hiba: \(httpResponse.statusCode)")
        }
        
        print("✅ Kártya sikeresen törölve a szerverről")
    }
    
    private func setDefaultCardOnServer(_ card: Card) async throws {
           guard let token = serverAuthManager.getAuthToken() else {
               throw CardError.authenticationRequired
           }
           
           guard let url = URL(string: "\(serverAuthManager.baseURL)/payment/cards/\(card.id.uuidString)/default") else {
               throw CardError.invalidURL
           }
           
           var request = URLRequest(url: url)
           request.httpMethod = "PUT"
           request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
           
           let (data, response) = try await URLSession.shared.data(for: request)
           
           guard let httpResponse = response as? HTTPURLResponse else {
               throw CardError.networkError
           }
           
           if httpResponse.statusCode != 200 {
               let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
               throw CardError.serverError(message: "Alapértelmezett beállítási hiba: \(errorString)")
           }
       }
    
    private func deleteCardFromServer(_ card: Card) async throws {
           guard let token = serverAuthManager.getAuthToken() else {
               throw CardError.authenticationRequired
           }
           
           guard let url = URL(string: "\(serverAuthManager.baseURL)/payment/cards/\(card.id.uuidString)") else {
               throw CardError.invalidURL
           }
           
           var request = URLRequest(url: url)
           request.httpMethod = "DELETE"
           request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
           
           let (data, response) = try await URLSession.shared.data(for: request)
           
           guard let httpResponse = response as? HTTPURLResponse else {
               throw CardError.networkError
           }
           
           if httpResponse.statusCode != 200 {
               let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
               throw CardError.serverError(message: "Törlési hiba: \(errorString)")
           }
       }
    
    // MARK: - Helper Methods
    func getDefaultCard() -> Card? {
        return userCards.first { $0.isDefault }
    }
    
    func hasCards() -> Bool {
        return !userCards.isEmpty
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Supporting Types
struct CardRequest: Codable {
    let cardNumber: String
    let cardHolderName: String
    let expirationMonth: Int
    let expirationYear: Int
    let cvv: String
    let isDefault: Bool
}

enum CardError: Error, LocalizedError {
    case invalidCardNumber
    case invalidExpiration
    case invalidCVV
    case authenticationRequired
    case invalidURL
    case networkError
    case serverError(message: String)
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCardNumber:
            return "Érvénytelen bankkártya szám"
        case .invalidExpiration:
            return "Érvénytelen lejárati dátum"
        case .invalidCVV:
            return "Érvénytelen CVV kód"
        case .authenticationRequired:
            return "Bejelentkezés szükséges"
        case .invalidURL:
            return "Érvénytelen URL"
        case .networkError:
            return "Hálózati hiba"
        case .serverError(let message):
            return message
        case .encodingFailed:
            return "Adat formázási hiba"
        }
    }
}
