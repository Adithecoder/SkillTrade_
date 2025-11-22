//
//  PaymentPreviewView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 11/13/25.
//


// PaymentPreviewView.swift
import SwiftUI
import DesignSystem

struct PaymentPreviewView: View {
    let service: Service
    @State private var showPaymentSimulation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Fejléc
            HStack {
                Button(action: {
                    dismiss()

                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Fizetés")
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                }) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 16))
                        .foregroundStyle( Color.DesignSystem.fokekszin )
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {

                
                Text(service.name)
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Szolgáltatás részletek
            VStack(spacing: 16) {
                ServiceDetailRow(title: "Szolgáltató / munkavállaló", value: service.advertiser.name)
                
                Divider()
                    .overlay(Rectangle()
                        .frame(height: 2))
                    .foregroundColor(.DesignSystem.descriptions)
                
                if !service.skills.isEmpty {
                    ServiceDetailRow2(title: "Készségek", value: service.skills.joined(separator: ", "))
                    
                }
                
                Divider()
                    .overlay(Rectangle()
                        .frame(height: 2))
                    .foregroundColor(.DesignSystem.descriptions)
                
                ServiceDetailRow(title: "Helyszín", value: service.location)
                Divider()
                    .overlay(Rectangle()
                        .frame(height: 2))
                    .foregroundColor(.DesignSystem.descriptions)
                
                
               
                
                ServiceDetailRow(title: "Összes ár", value: "\(Int(service.price)) Ft")

            }
            
            .padding()
            .background(Color.DesignSystem.fokekszin.opacity(0.1))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
            )
            .padding(.horizontal)
            
            HStack{
                Text("Kártya adatai")
                    .font(.custom("Jellee", size: 20))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .offset(x:20)
                    .padding(.bottom,-10)

                Spacer()
            }
            VStack(spacing: 16) {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
                    
                    VStack {
                        HStack {
                            
                            Spacer()
                            Image("mastercard")
                                .resizable()
                                .frame(width: 45, height:30)
                        }
                        Spacer()

                        HStack {
                            VStack(alignment: .leading) {
                                Spacer()

                                HStack{
                                    Text("**** **** **** 1234")
                                        .font(.custom("Lexend", size:20))
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("Expires")
                                            .font(.custom("Jellee", size:14))
                                        Text("12/25")
                                            .font(.custom("Lexend", size:14))
                                    }
                                }
                                Spacer()

                                HStack{
                                    VStack(alignment: .leading){
                                        Text("Cardholder Name")
                                            .font(.custom("Jellee", size:14))
                                        Text("JOHN DOE")
                                            .font(.custom("Lexend", size:14))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("CVV")
                                            .font(.custom("Jellee", size:14))
                                        Text("***")
                                            .font(.custom("Lexend", size:14))
                                    }
                                    
                                    
                                }

                            }
                           
                        }
                    }
                    .padding()
                }
                .frame(height: 150) // Állítsd be a kívánt magasságra
                
                
            }
            
            .background(Color.DesignSystem.fokekszin.opacity(0.1))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                    .background(Color.DesignSystem.fokekszin.opacity(0.2))
                    .cornerRadius(25)
            )
            .padding(.horizontal)
            .padding(.bottom,-10)
            
            VStack {
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .shadow(color: Color(Color.DesignSystem.fokekszin), radius: 16, x: 4, y: 4)
                    
                    VStack {
                        

                        HStack {
                            VStack(alignment: .leading) {

                                HStack{
                                    Image(systemName: "plus")
                                        .padding(5)
                                        .background(.gray.opacity(0.3))
                                        .cornerRadius(8)
                                    
                                    Text("Másik kártya hozzáadása")
                                        .font(.custom("Lexend", size:18))

                                    Spacer()
                                }


                            }
                           
                        }
                    }
                    .padding(10)
                }
                
                
            }
            
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .cornerRadius(15)

            )
            .background(Color.DesignSystem.fokekszin.opacity(0.4))
            .cornerRadius(15)
            .padding(.horizontal)
            Spacer()
            
            // Fizetés gomb
            Button(action: {
                showPaymentSimulation = true
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                    Text("Fizetés")
                        .font(.custom("Lexend", size: 20))
                }
                .foregroundColor(.DesignSystem.descriptions)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.fokekszin]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                )
                .shadow(color: Color.DesignSystem.fokekszin, radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }

        .fullScreenCover(isPresented: $showPaymentSimulation) {
            PaymentSimulationView(service: service)
        }
    }
}

struct ServiceDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(value)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.DesignSystem.fokekszin)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ServiceDetailRow2: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(value)
                .font(.custom("Jellee", size: 14))
                .foregroundColor(.DesignSystem.fokekszin)
                .multilineTextAlignment(.trailing)
            
        }
    }
}
struct Animation3: View {
    @State private var isPresented = false
    
    var body: some View {
        VStack(spacing: 50){
            Image(systemName: isPresented ? "checkmark.circle.fill" : "faceid")
                .font(.system(size: 100))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle( isPresented ? .green : .black)
            
            Text(isPresented ? "Sikeres fizetés!": "")
                .font(.custom("Lexend", size:20))
            Button("Show symbol", action: { isPresented = true })
        }
    }
}
// PaymentSimulationView.swift
struct PaymentSimulationView: View {
    let service: Service
    @State private var isPresented = false
    @State private var paymentProgress: Double = 0.0
    @State private var currentStep = 0
    @State private var isProcessing = false
    @State private var isCompleted = false
    @State private var showSuccess = false
    @Environment(\.dismiss) var dismiss
    
    let steps = [
        "Fizetés inicializálása",
        "Tranzakció feldolgozása",
        "Banki megerősítés",
        "Befejezés"
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Fejléc
            VStack(spacing: 12) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Fizetés sikeres!")
                        .font(.custom("Jellee", size: 28))
                        .foregroundColor(.green)
                } else {
                    Text("Fizetés folyamatban")
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text(service.name)
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 160)
            
            if !isCompleted {
                // Progress bar
                VStack(spacing: 20) {
                    ProgressView(value: paymentProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .DesignSystem.fokekszin))
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .padding(.horizontal)
                    
                    Text("\(Int(paymentProgress * 100))%")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    // Aktuális lépés
                    if currentStep < steps.count {
                        Text(steps[currentStep])
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                
                // Loading animáció
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.DesignSystem.fokekszin)
                        
                        Text("Feldolgozás...")
                            .font(.custom("Lexend", size: 16))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // Sikeres fizetés részletei
//                  VStack(spacing: 16) {
//                      ServiceDetailRow(title: "Szolgáltató / munkavállaló", //    value: service.advertiser.name)
//
//                      Divider()
//                          .overlay(Rectangle()
//                              .frame(height: 2))
//                          .foregroundColor(.DesignSystem.descriptions)
//
//                      if !service.skills.isEmpty {
//                          ServiceDetailRow2(title: "Készségek", value: // service.skills.joined(separator: ", "))
//
//                      }
//
//                      Divider()
//                          .overlay(Rectangle()
//                              .frame(height: 2))
//                          .foregroundColor(.DesignSystem.descriptions)
//
//                      ServiceDetailRow(title: "Helyszín", value: //   service.location)
//                      Divider()
//                          .overlay(Rectangle()
//                              .frame(height: 2))
//                          .foregroundColor(.DesignSystem.descriptions)
//
//
//
//
//                      ServiceDetailRow(title: "Összes ár", value: //  "\(Int(service.price)) Ft")
//
//                  }
//
//                  .padding()
//                  .background(Color.DesignSystem.fokekszin.opacity(0.1))
//                  .cornerRadius(15)
//                  .overlay(
//                      RoundedRectangle(cornerRadius: 15)
//                          .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
//                  )
//                  .padding(.horizontal)
                
            }
            
            Spacer()
            
            // Gombok
            if isCompleted {
                Button(action: {
                    dismiss()
                }) {
                    Text("Vissza a szolgáltatáshoz")
                        .font(.custom("Jellee", size: 20))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.fokekszin)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 4)
                        )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            startPaymentProcess()
        }
    }
    
    private func startPaymentProcess() {
        isProcessing = true
        
        // Szimuláljuk a fizetési folyamatot
        let totalSteps = steps.count
        let stepDuration = 2.0 // másodperc per lépés
        
        for step in 0..<totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentStep = step
                    paymentProgress = Double(step + 1) / Double(totalSteps)
                }
                
                // Utolsó lépés után
                if step == totalSteps - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isProcessing = false
                            isCompleted = true
                            showSuccess = true
                        }
                    }
                }
            }
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd. HH:mm"
        formatter.locale = Locale(identifier: "hu_HU")
        return formatter.string(from: Date())
    }
}

struct PaymentSuccessRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            
            Text(text)
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.black)
            
            Spacer()
        }
    }
}

// ModernServiceCard2 kiegészítése - Fizetés gomb hozzáadása
// A ModernServiceCard2 struct-ban add hozzá ezt a gombot a meglévő gombok mellé:

/*
// A ModernServiceCard2 body-jában, a gombok részéhez add hozzá:

// Fizetés gomb - csak akkor jelenjen meg, ha a felhasználó a szolgáltató
if shouldShowPaymentButton {
    Button(action: {
        // Navigáció a PaymentPreviewView-hez
        showPaymentView = true
    }) {
        Image(systemName: "creditcard.fill")
            .foregroundColor(.DesignSystem.fokekszin)
            .padding(8)
            .background(Color.DesignSystem.fokekszin.opacity(0.1))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
            )
    }
    .buttonStyle(PlainButtonStyle())
}

// És a State változókhoz add hozzá:
@State private var showPaymentView = false

// A .background modifierhez add hozzá ezt is:
.background(
    NavigationLink(
        destination: PaymentPreviewView(service: service),
        isActive: $showPaymentView,
        label: { EmptyView() }
    )
)
*/

// Előnézet
struct PaymentPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PaymentPreviewView(service: Service.preview)
        }
        
        PaymentSimulationView(service: Service.preview)
    }
}
