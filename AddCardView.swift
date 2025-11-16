//
//  AddCardView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/15/25.
//


//
//  AddCardView.swift
//  SkillTrade_latest
//

import SwiftUI
import DesignSystem
import Combine

struct AddCardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AddCardViewModel()
    @State private var showSuccess = false
    
    var onCardAdded: ((Card) -> Void)?
    
    // Tároljuk a korábbi appearance-t, hogy vissza tudjuk állítani
    @State private var previousStandardAppearance: UINavigationBarAppearance?
    @State private var previousScrollEdgeAppearance: UINavigationBarAppearance?
    
    var body: some View {
        NavigationView {
            Form {
                cardNameAndColorSection
                previewCardSection
                cardDetailsSection
                validationErrorsSection
                defaultToggleSection
            }
            .navigationTitle(viewModel.cardName.isEmpty ? "Új kártya" : viewModel.cardName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Mégse")
                    
                {
                    dismiss()
                }
                    .font(.custom("Lexend", size:17)),
                trailing: Button("Mentés") {
                    Task {
                        await viewModel.saveCard()
                    }
                }
                    .font(.custom("Lexend", size:17))

                .disabled(!viewModel.isFormValid || viewModel.isLoading)
            )
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .background(Color.black.opacity(0.1))
                }
            }
            .alert("Hiba", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
            .alert("Sikeres mentés", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("A kártya sikeresen hozzáadva.")
            }
            .onChange(of: viewModel.saveSuccess) { success in
                if success {
                    showSuccess = true
                    onCardAdded?(viewModel.createdCard!)
                }
            }
        }
        .onAppear {
            // Mentsük a korábbi appearance-eket
            previousStandardAppearance = UINavigationBar.appearance().standardAppearance
            previousScrollEdgeAppearance = UINavigationBar.appearance().scrollEdgeAppearance
            
            // Új lokális appearance a cím betűtípusához
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            
            // Inline cím (mert .inline-t használsz)
            var inlineAttributes = appearance.titleTextAttributes
            if let lexend = UIFont(name: "Lexend", size: 14) {
                inlineAttributes[.font] = lexend
            }
            inlineAttributes[.foregroundColor] = UIColor.label
            appearance.titleTextAttributes = inlineAttributes
            
            // Ha esetleg később large title-re váltanál, itt állítható:
            var largeAttributes = appearance.largeTitleTextAttributes
            if let lexendLarge = UIFont(name: "Lexend", size: 34) {
                largeAttributes[.font] = lexendLarge
            }
            largeAttributes[.foregroundColor] = UIColor.label
            appearance.largeTitleTextAttributes = largeAttributes
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        .onDisappear {
            // Visszaállítás, hogy ne legyen globális
            if let prev = previousStandardAppearance {
                UINavigationBar.appearance().standardAppearance = prev
            }
            if let prevScroll = previousScrollEdgeAppearance {
                UINavigationBar.appearance().scrollEdgeAppearance = prevScroll
            }
        }
    }
}

// MARK: - Subviews
private extension AddCardView {
    var cardNameAndColorSection: some View {
        Section(header: Text("Kártya elnevezése")
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
        ) {
            HStack {
                TextField("Nevezd el és találd meg könnyebben", text: $viewModel.cardName)
                    .font(.custom("Jellee", size: 16))
                    .foregroundStyle(viewModel.selectedColor.color)
                    .padding(10)
                
                Spacer()
                
                Menu {
                    ForEach(viewModel.availableColors, id: \.self) { color in
                        Button {
                            viewModel.selectedColor = color
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 20)
                                Text(color.name)
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(viewModel.selectedColor.color)
                        .frame(width:20, height: 20)
                        
                }
                
                Image(systemName: "pencil.and.scribble")
                    .foregroundColor(.DesignSystem.fokekszin)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.DesignSystem.fokekszin.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
            )
            .listRowInsets(EdgeInsets())
        }
        .padding(4)
    }
    
    var previewCardSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .cornerRadius(20)
                    .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
                
                VStack {
                    HStack {
                        TextField("Kártya neve", text: $viewModel.cardName)
                            .font(.custom("Jellee", size: 28))
                         .foregroundStyle(viewModel.selectedColor.color)
                        Spacer()
                        Image(viewModel.cardType.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 45)
                            .foregroundColor(viewModel.cardType.color)
                            .opacity(viewModel.cardNumber.isEmpty ? 0.3 : 1.0)
                    }
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Card Number")
                                        .font(.custom("Jellee", size: 14))
                                    Text("\(viewModel.cardNumber)")
                                        .font(.custom("Lexend", size: 20))
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Expires")
                                        .font(.custom("Jellee", size: 14))
                                    HStack {
                                        Text("\(viewModel.expirationMonth)")
                                            .font(.custom("Lexend", size: 14))
                                        Text("/")
                                            .font(.custom("Lexend", size: 14))
                                        Text("\(viewModel.expirationYear)")
                                            .font(.custom("Lexend", size: 14))
                                    }
                                }
                            }
                            Spacer()
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Cardholder Name")
                                        .font(.custom("Jellee", size: 14))
                                    Text("\(viewModel.cardHolderName)")
                                        .font(.custom("Lexend", size: 14))
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("CVV")
                                        .font(.custom("Jellee", size: 14))
                                    Text(viewModel.cvv)
                                        .font(.custom("Lexend", size: 14))
                                        .foregroundColor(viewModel.cvv.count == 4 ? .green : .red)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .frame(height: 200)
        }
        .padding(.horizontal, 0)
        .background(Color.DesignSystem.fokekszin.opacity(0.1))
        .cornerRadius(25)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(viewModel.cardType.color, lineWidth: 5)
        )
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.DesignSystem.fokekszin.opacity(0.2))
        )
        .listRowInsets(EdgeInsets())
        .padding(4)
    }
    
    var cardDetailsSection: some View {
        Section(header: Text("Kártya adatai")
            .font(.custom("Jellee", size: 24))
            .foregroundColor(.DesignSystem.fokekszin)
        ) {
            VStack {
                HStack {
                    TextField("Kártyaszám", text: $viewModel.cardNumber)
                        .font(.custom("Jellee", size: 16))
                        .foregroundColor(viewModel.cardType.color)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.cardNumber) { newValue in
                            viewModel.cardNumber = CardValidation.formatCardNumber(newValue)
                            viewModel.detectCardType()
                        }
                    
                    Image(viewModel.cardType.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .foregroundColor(viewModel.cardType.color)
                        .opacity(viewModel.cardNumber.isEmpty ? 0.7 : 1.0)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.cardType.color, lineWidth: 2)
                        )
                }
                .padding(.top, 2)
                
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.DesignSystem.fokekszin)
                
                TextField("Kártya tulajdonosa", text: $viewModel.cardHolderName)
                    .font(.custom("Jellee", size: 16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .overlay(
                        Rectangle()
                            .frame(height: 2).padding(.top, 35)
                    )
                    .foregroundColor(.DesignSystem.fokekszin)
                    .padding(.top, 10)
                
                VStack(alignment: .leading) {
                    HStack {
                        Picker("Hónap:", selection: $viewModel.expirationMonth) {
                            ForEach(Array(1...12), id: \.self) { month in
                                Text(String(format: "%02d", month)).tag(month)
                            }
                        }
                        .font(.custom("Jellee", size: 16))
                        .foregroundStyle(.black)
                        .pickerStyle(MenuPickerStyle())
                        
                        Text("/")
                        
                        Picker("Év:", selection: $viewModel.expirationYear) {
                            ForEach(viewModel.availableYears, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .font(.custom("Jellee", size: 16))
                        .foregroundStyle(.black)
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(.top, 10)
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.DesignSystem.fokekszin)
                }
                
                HStack {
                    SecureField("CVV Biztonsági szám", text: $viewModel.cvv)
                        .font(.custom("Jellee", size: 16))
                        .foregroundColor(viewModel.cvv.count == 4 ? .green : .red)
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.cvv) { newValue in
                            if newValue.count > 4 {
                                viewModel.cvv = String(newValue.prefix(4))
                            }
                        }
                    Spacer()
                    Text("\(viewModel.cvv.count)/4")
                        .font(.custom("Jellee", size: 14))
                        .foregroundColor(viewModel.cvv.count == 4 ? .green : .red)
                }
                .padding(.top, 10)
                
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.DesignSystem.fokekszin)
            }
            .padding()
            .background(Color.DesignSystem.fokekszin.opacity(0.2))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
            )
            .listRowInsets(EdgeInsets())
        }
        .padding(4)
    }
    
    @ViewBuilder
    var validationErrorsSection: some View {
        if !viewModel.validationErrors.isEmpty {
            VStack(alignment: .leading) {
                ForEach(viewModel.validationErrors, id: \.self) { error in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .font(.custom("Lexend", size: 12))
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                }
            }
            .background(Color.DesignSystem.fokekszin.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
            )
            .cornerRadius(15)
            .padding(4)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
    
    var defaultToggleSection: some View {
        Section {
            Toggle("Alapértelmezett kártya", isOn: $viewModel.isDefault)
                .tint(.DesignSystem.fokekszin)
                .font(.custom("Lexend", size: 16))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.DesignSystem.fokekszin.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                )
                .listRowInsets(EdgeInsets())
        }
        .padding(4)
    }
}

struct CardColor: Hashable {
    let name: String
    let color: Color
    
    static let availableColors: [CardColor] = [
        CardColor(name: "Kék", color: .blue),
        CardColor(name: "Piros", color: .red),
        CardColor(name: "Zöld", color: .green),
        CardColor(name: "Lila", color: .purple),
        CardColor(name: "Narancs", color: .orange),
        CardColor(name: "Rózsaszín", color: .pink)
    ]
}

// MARK: - ViewModel for AddCardView
class AddCardViewModel: ObservableObject {
    @Published var cardName = ""
    @Published var selectedColor: CardColor = .availableColors[0]
    @Published var cardNumber = ""
    @Published var cardHolderName = ""
    @Published var expirationMonth = Calendar.current.component(.month, from: Date())
    @Published var expirationYear = Calendar.current.component(.year, from: Date()) % 100
    @Published var cvv = ""
    @Published var isDefault = true
    @Published var cardType: CardType = .none
    @Published var validationErrors: [String] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var saveSuccess = false
    @Published var createdCard: Card?
    
    private let cardManager = CardManager.shared
    
    var availableColors: [CardColor] {
        return CardColor.availableColors
    }
    
    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date()) % 100
        return Array(currentYear...(currentYear + 10))
    }
        
    var isFormValid: Bool {
        validationErrors.isEmpty &&
        !cardNumber.isEmpty &&
        !cardHolderName.isEmpty &&
        !cvv.isEmpty
    }
    
    func detectCardType() {
        let cleanedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        cardType = CardType.detect(from: cleanedNumber)
        validateForm()
    }
    
    func validateCVV() {
        let cleanedCVV = cvv.replacingOccurrences(of: " ", with: "")
        let maxLength = cardType == .americanExpress ? 4 : 3
        
        if cleanedCVV.count > maxLength {
            cvv = String(cleanedCVV.prefix(maxLength))
        }
        validateForm()
    }
    
    func validateForm() {
        validationErrors.removeAll()
        
        if !cardNumber.isEmpty && !CardValidation.isValidCardNumber(cardNumber) {
            validationErrors.append("Érvénytelen kártyaszám")
        }
        
        if !CardValidation.isValidExpiration(month: expirationMonth, year: expirationYear) {
            validationErrors.append("A kártya lejárt vagy érvénytelen a lejárati dátum")
        }
        
        if !cvv.isEmpty && !CardValidation.isValidCVV(cvv, cardType: cardType) {
            let expectedLength = cardType == .americanExpress ? 4 : 3
            validationErrors.append("A CVV kódnak \(expectedLength) számjegyből kell állnia")
        }
        
//          if cardHolderName.count < 2 {
//              validationErrors.append("A kártya tulajdonos nevének // legalább 2 karakterből kell állnia")
//          }
    }
    
    func saveCard() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        validateForm()
        
        guard isFormValid else {
            await MainActor.run {
                isLoading = false
                error = "Kérjük, javítsa ki a hibákat a mentés előtt."
            }
            return
        }
        
        let cleanedCardNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        let cardNameToSave = cardName.isEmpty ? "Új kártya" : cardName
        
        let newCard = Card(
            cardName: cardNameToSave,
            cardNumber: cleanedCardNumber,
            cardHolderName: cardHolderName,
            expirationMonth: expirationMonth,
            expirationYear: expirationYear,
            cvv: cvv,
            cardType: cardType,
            isDefault: isDefault
        )
        
        do {
            try await cardManager.addCard(newCard)
            
            await MainActor.run {
                isLoading = false
                saveSuccess = true
                createdCard = newCard
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview("Add Card View") {
    AddCardView()
}

#Preview("All Card View") {
    CardListView()
}
