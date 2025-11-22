//
//  CardListView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/15/25.
//


//
//  CardListView.swift
//  SkillTrade_latest
//

import SwiftUI
import DesignSystem

struct CardListView: View {
    @StateObject private var cardManager = CardManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingAddCard = false
    @State private var cardToDelete: Card?
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Hozzáadott HStack felülre
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()

                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Fizetés és pénzügyek")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingAddCard = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                            .foregroundStyle( Color.DesignSystem.fokekszin )
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, -240)
                
                // Meglévő tartalom
                Group {
                    if cardManager.userCards.isEmpty {
                        EmptyCardView(showingAddCard: $showingAddCard)
                    } else {
                        List {
                            ForEach(cardManager.userCards) { card in
                                CardRowView(
                                    card: card,
                                    onSetDefault: { setDefaultCard(card) },
                                    onDelete: { confirmDelete(card) }
                                )
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
            }
            .alert("Kártya törlése", isPresented: $showDeleteAlert) {
                Button("Mégse", role: .cancel) { }
                Button("Törlés", role: .destructive) {
                    if let card = cardToDelete {
                        deleteCard(card)
                    }
                }
            } message: {
                Text("Biztosan törölni szeretné ezt a kártyát?")
            }
            .overlay {
                if cardManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    private var addButton: some View {
        Button(action: { showingAddCard = true }) {
            Image(systemName: "plus")
        }
    }
    
    private func setDefaultCard(_ card: Card) {
        Task {
            try? await cardManager.setDefaultCard(card)
        }
    }
    
    private func confirmDelete(_ card: Card) {
        cardToDelete = card
        showDeleteAlert = true
    }
    
    private func deleteCard(_ card: Card) {
        Task {
            do {
                try await cardManager.removeCard(card)
                print("✅ Kártya sikeresen törölve lokálisan és a szerverről")
            } catch {
                print("❌ Kártya törlési hiba: \(error.localizedDescription)")
                // Hiba kezelése a felhasználó számára
                await MainActor.run {
                    // Itt jelenítsd meg a hibát a felhasználónak
                }
            }
        }
    }
}


struct CardItemView: View {
    let card: Card
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    @State private var showActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                Image(systemName: card.cardType.iconName)
                    .font(.title2)
                    .foregroundColor(card.cardType.color)
                
                Text(card.cardName ?? "Új kártya")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Default Badge
                if card.isDefault {
                    Text("Alapértelmezett")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                
                
                // Menu Button
                Menu {
                    // Set as Default Option
                    if !card.isDefault {
                        Button {
                            onSetDefault()
                        } label: {
                            Label("Alapértelmezetté tesz", systemImage: "star.fill")
                        }
                    }
                    
                    // Delete Option
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Törlés", systemImage: "trash")
                    }
                    
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            
            // Card Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("•••• \(card.lastFourDigits)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    Text(card.cardHolderName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Lejárat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(card.formattedExpiration)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Expired Warning
            if card.isExpired {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Kártya lejárt")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(card.isDefault ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views
struct CardRowView: View {
    let card: Card
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Card Icon

            
            // Card Details
            VStack(alignment: .leading) {
                HStack {
                    
                    Image(card.cardType.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 45)
                        .foregroundColor(card.cardType.color)
                    
                    Text("•••• \(card.lastFourDigits)")
                        .font(.custom("Lexend", size: 20))
                    
                    if card.isDefault {
                        Text("Alapértelmezett")
                            .font(.custom("Lexend", size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    if card.isExpired {
                        Text("LEJÁRT")
                            .font(.custom("Jellee", size: 12))
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    else {
                        Text("ÉRVÉNYES")
                            .font(.custom("Jellee", size: 12))
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("🔍 Debug Info") {
                            print("🔍 KÁRTYA DEBUG:")
                            print("   - ID: \(card.id.uuidString)")
                            print("   - Név: \(card.cardName)")
                            print("   - Tulajdonos: \(card.cardHolderName)")
                            print("   - Alapértelmezett: \(card.isDefault)")
                        }
                        
                        if !card.isDefault {
                            Button {
                                print("⭐ Alapértelmezetté tesz: \(card.id.uuidString)")
                                onSetDefault()
                            } label: {
                                Label("Alapértelmezetté tesz", systemImage: "star.fill")
                            }
                        }
                        
                        Button(role: .destructive) {
                            print("🗑️ TÖRLÉS INDÍTÁS: \(card.id.uuidString)")
                            onDelete()
                        } label: {
                            Label("Törlés", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.DesignSystem.fokekszin)
                    }
                }
                HStack{
                    Text(card.cardHolderName)
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Lejárat: \(card.formattedExpiration)")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
            )
            
            // Actions Menu

        }
        .onAppear {
            print("👀 CardRowView megjelenítve: \(card.id.uuidString.prefix(8))...")
        }
        .padding(.vertical, 8)
        .opacity(card.isExpired ? 0.6 : 1.0)

    }
}

// Update EmptyCardView to accept binding

struct EmptyCardView: View {
    @Binding var showingAddCard: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("Nincsenek kártyák")
                    .font(.custom("Jellee", size: 24))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Adj hozzá egy bankkártyát a gyorsabb fizetéshez")
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingAddCard = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Kártya hozzáadása")
                }
                .font(.custom("Lexend", size: 20))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CardListView_Previews: PreviewProvider {
    static var previews: some View {
        CardListView()
    }
}
#endif
