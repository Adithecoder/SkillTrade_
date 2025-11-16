
//
//  PaymentConfirmation.swift
//  SkillTrade_latest
//
//  Created by Czeglédi Ádi on 07/01/2025.
//

import SwiftUI
import Combine
// MARK: - Models
struct PaymentConfirmation: Identifiable {
    let id = UUID()
    let service: Service
    let appointment: Appointment
    let amount: Double
    let protectionFee: Double
    var status: PaymentStatus
    let timestamp: Date
    
    var totalAmount: Double {
        amount + protectionFee
    }
}

enum PaymentStatus: String {
    case pending = "Függőben"
    case confirmed = "Megerősítve"
    case completed = "Teljesítve"
    case refunded = "Visszatérítve"
    case failed = "Sikertelen"
    
    var color: Color {
        switch self {
        case .pending: return .yellow
        case .confirmed: return .blue
        case .completed: return .green
        case .refunded: return .purple
        case .failed: return .red
        }
    }
}

// MARK: - Helper Functions
func calculateProtectionFee(for amount: Double) -> Double {
    if amount <= 0 { return 0 }
    if amount <= 2500 { return 200 }
    if amount <= 10000 { return amount * 0.07 }
    if amount <= 50000 { return amount * 0.10 }
    if amount <= 110000 { return amount * 0.07 }
    return amount * 0.05
}

// MARK: - View Model
class PaymentConfirmationViewModel: ObservableObject {
    @Published var confirmation: PaymentConfirmation
    @Published var isLoading = false
    @Published var error: String? = nil
    
    init(service: Service, appointment: Appointment) {
        let amount = service.price
        let protectionFee = calculateProtectionFee(for: amount)
        
        self.confirmation = PaymentConfirmation(
            service: service,
            appointment: appointment,
            amount: amount,
            protectionFee: protectionFee,
            status: .pending,
            timestamp: Date()
        )
    }
    
    func confirmPayment() async {
        await MainActor.run { isLoading = true }
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            // TODO: Add actual payment processing logic here
            await MainActor.run {
                confirmation.status = .confirmed
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = "Hiba történt a fizetés során. Kérjük, próbáld újra."
                isLoading = false
            }
        }
    }
}

// MARK: - Views
struct PaymentConfirmationView: View {
    let service: Service
    let appointment: Appointment
    @StateObject private var viewModel: PaymentConfirmationViewModel
    @Environment(\.dismiss) var dismiss
    
    init(service: Service, appointment: Appointment) {
        self.service = service
        self.appointment = appointment
        _viewModel = StateObject(wrappedValue: PaymentConfirmationViewModel(service: service, appointment: appointment))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Service Info Card
                    ServiceInfoCard(service: service)
                    
                    // Payment Details Card
                    PaymentDetailsCard(confirmation: viewModel.confirmation)
                    
                    // Protection Info
                    ProtectionInfoCard(protectionFee: viewModel.confirmation.protectionFee)
                    
                    // Appointment Details
                    AppointmentDetailsCard(appointment: appointment)
                    
                    // Confirm Button
                    Button(action: {
                        Task {
                            await viewModel.confirmPayment()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                Text("Feldolgozás...").foregroundColor(.black)
                            } else {
                                Text("Fizetés megerősítése")
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isLoading ? Color.gray : Color.yellow)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Fizetés megerősítése")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Mégse") { dismiss() })
            .alert("Hiba", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct ServiceInfoCard: View {
    let service: Service
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(service.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "person.circle.fill")
                Text(service.advertiser.name)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                Text(service.location)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct PaymentDetailsCard: View {
    let confirmation: PaymentConfirmation
    
    var body: some View {
        VStack(spacing: 12) {
            PaymentRow(title: "Szolgáltatás díja", amount: confirmation.amount)
            PaymentRow(title: "Munkavédelmi díj", amount: confirmation.protectionFee)
            Divider()
            PaymentRow(title: "Teljes összeg", amount: confirmation.totalAmount, isTotal: true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct PaymentRow: View {
    let title: String
    let amount: Double
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(isTotal ? .primary : .gray)
            Spacer()
            Text("\(Int(amount)) Ft")
                .bold(isTotal)
                .foregroundColor(isTotal ? .blue : .primary)
        }
    }
}

struct ProtectionInfoCard: View {
    let protectionFee: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.yellow)
                Text("Vásárlóvédelem")
                    .font(.headline)
            }
            
            Text("A vásárlóvédelmi díj \(Int(protectionFee)) Ft, ami biztosítja a biztonságos tranzakciót és a pénzvisszafizetési garanciát.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct AppointmentDetailsCard: View {
    let appointment: Appointment
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Időpont részletei")
                .font(.headline)
            
            HStack {
                Image(systemName: "calendar")
                Text(dateFormatter.string(from: appointment.date))
                    .foregroundColor(.gray)
            }
            
            if let notes = appointment.notes {
                HStack {
                    Image(systemName: "note.text")
                    Text(notes)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#if DEBUG
struct PaymentConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentConfirmationView(
            service: Service.preview,
            appointment: Appointment(
                serviceProvider: User.preview,
                client: User.preview,
                date: Date(),
                duration: 3600,
                status: .pending,
                notes: "Test appointment"
            )
        )
    }
}
#endif
