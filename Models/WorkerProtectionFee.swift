//
//  WorkerProtectionFee.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//


//
//  WorkerProtectionFee.swift
//  SkillTrade_latest
//
//  Created by Czeglédi Ádi on 07/01/2025.
//

import Foundation
import Combine

struct WorkerProtectionFee: Identifiable {
    let id = UUID()
    let minValue: Double
    let maxValue: Double
    let percentage: Double
    let fixedFee: Double?

    func calculateFee(for amount: Double) -> Double {
        guard amount >= minValue && (maxValue == .infinity || amount <= maxValue) else { return 0 }
        if let fixedFee = fixedFee {
            return fixedFee
        }
        return amount * (percentage / 100.0)
    }
}

class WorkerProtectionModel: ObservableObject {
    @Published var protectionFees: [WorkerProtectionFee] = [
        WorkerProtectionFee(minValue: 0, maxValue: 2500, percentage: 0, fixedFee: 200),      // Fix 200Ft
        WorkerProtectionFee(minValue: 2500, maxValue: 10000, percentage: 7, fixedFee: nil),  // 7%
        WorkerProtectionFee(minValue: 10000, maxValue: 50000, percentage: 10, fixedFee: nil), // 10%
        WorkerProtectionFee(minValue: 50000, maxValue: 110000, percentage: 7, fixedFee: nil), // 7%
        WorkerProtectionFee(minValue: 110000, maxValue: .infinity, percentage: 5, fixedFee: nil)  // 5%
    ]
    
    func calculateTotalFee(for amount: Double) -> Double {
        // Speciális eset: 0-2500 Ft között maximum 200 Ft
        if amount <= 2500 {
            return min(amount * 0.05, 200)
        }
        
        // Normál esetben megkeressük a megfelelő díjkategóriát
        for fee in protectionFees {
            if amount >= fee.minValue && (fee.maxValue == .infinity || amount <= fee.maxValue) {
                return fee.calculateFee(for: amount)
            }
        }
        
        return 0
    }
}

//
//  WorkerProtectionView.swift
//  SkillTrade_latest
//
//  Created by Czeglédi Ádi on 07/01/2025.
//

import SwiftUI
import DesignSystem
// Custom row view for fee table
struct FeeRow: View {
    let fee: WorkerProtectionFee
    
    private var rangeText: String {
        if fee.maxValue == .infinity {
            return "\(Int(fee.minValue))Ft felett"
        } else if fee.minValue == 0 {
            return "0-\(Int(fee.maxValue))Ft"
        } else {
            return "\(Int(fee.minValue))-\(Int(fee.maxValue))Ft"
        }
    }
    
    private var percentageText: String {
        if fee.minValue == 0 {
            return "\(Int(fee.percentage))%*"
        } else {
            return "\(Int(fee.percentage))%"
        }
    }
    
    var body: some View {
        HStack {
            Text(rangeText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(percentageText)
                .frame(width: 80)
        }
        .padding()
        .background(Color.white)
    }
}

// Fee table component
struct FeeTable: View {
    let fees: [WorkerProtectionFee]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Összeghatár")
                    .font(.custom("OrelegaOne-Regular", size: 20))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Díj")
                    .font(.custom("OrelegaOne-Regular", size: 18))
                    .frame(width: 80)
            }
            .padding()
            .background(Color.yellow)
            
            // Rows
            ForEach(fees) { fee in
                FeeRow(fee: fee)
                Divider()
            }
        }
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// Fee calculator component
struct FeeCalculator: View {
    @Binding var amount: String
    let calculatedFee: Double?
    let onCalculate: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Díjkalkulátor")
                .font(.custom("OrelegaOne-Regular", size: 20))

            TextField("Adja meg az összeget", text: $amount)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding()
            
            Button(action: onCalculate) {
                Text("Számítás")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.yellow)
                    .cornerRadius(10)
            }
            
            if let fee = calculatedFee {
                Text("Vásárlóvédelmi díj: \(Int(fee)) Ft")
                    .font(.headline)
                    .padding()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Modern Fee Card Component
struct FeeCard: View {
    let fee: WorkerProtectionFee
    @State private var isSelected = false
    
    private var rangeText: String {
        if fee.maxValue == .infinity {
            return "\(Int(fee.minValue))Ft felett"
        } else if fee.minValue == 0 {
            return "0-\(Int(fee.maxValue))Ft"
        } else {
            return "\(Int(fee.minValue))-\(Int(fee.maxValue))Ft"
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.yellow.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text("\(Int(fee.percentage))%")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                )
            
            Text(rangeText)
                .font(.system(.headline, design: .rounded))
                .multilineTextAlignment(.center)
            
            if fee.minValue == 0 {
                Text("Maximum 200 Ft")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 160, height: 160)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .onTapGesture {
            withAnimation(.spring()) {
                isSelected.toggle()
            }
        }
    }
}

// MARK: - Modern Calculator Component
struct ModernCalculator: View {
    @Binding var amount: String
    let calculatedFee: Double?
    let onCalculate: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("💰 Díjkalkulátor")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
            
            HStack {
                TextField("Összeg", text: $amount)
                    .keyboardType(.numberPad)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(15)
                
                Text("Ft")
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            Button(action: onCalculate) {
                HStack {
                    Image(systemName: "function")
                    Text("Számítás")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.yellow)
                .cornerRadius(15)
                .shadow(color: Color.yellow.opacity(0.3), radius: 10, y: 5)
            }
            
            if let fee = calculatedFee {
                VStack(spacing: 5) {
                    Text("Vásárlóvédelmi díj")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.gray)
                    Text("\(Int(fee)) Ft")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .padding()
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 15, y: 10)
    }
}

// MARK: - Table Row Component
struct ProtectionTableRow: View {
    let fee: WorkerProtectionFee
    let isHeader: Bool
    let isEven: Bool
    
    private var rangeText: String {
        if fee.maxValue == .infinity {
            return "\(Int(fee.minValue))Ft felett"
        } else if fee.minValue == 0 {
            return "0-\(Int(fee.maxValue))Ft"
        } else {
            return "\(Int(fee.minValue))-\(Int(fee.maxValue))Ft"
        }
    }
    
    var body: some View {
        HStack {
            Text(rangeText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(isHeader ? .bold : .regular)
            
            Text("\(Int(fee.percentage))%" + (fee.minValue == 0 ? "*" : ""))
                .frame(width: 60)
                .fontWeight(isHeader ? .bold : .regular)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        if isHeader {
            return Color.yellow
        } else {
            return isEven ? Color.white : Color.gray.opacity(0.05)
        }
    }
}

// MARK: - Protection Table Component
struct ProtectionTable: View {
    let fees: [WorkerProtectionFee]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ProtectionTableRow(
                fee: WorkerProtectionFee(minValue: 0, maxValue: 0, percentage: 0, fixedFee: nil),
                isHeader: true,
                isEven: true
            )
            
            // Rows
            ForEach(Array(fees.enumerated()), id: \.element.id) { index, fee in
                ProtectionTableRow(
                    fee: fee,
                    isHeader: false,
                    isEven: index % 2 == 0
                )
            }
        }
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Calculator Component
struct ProtectionCalculator: View {
    @Binding var amount: String
    let calculatedFee: Double?
    let onCalculate: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                TextField("Összeg megadása", text: $amount)
                    .keyboardType(.numberPad)
                
                Button(action: onCalculate) {
                    Text("Számítás")
                }
            }
            
            if let fee = calculatedFee {
                Text("Vásárlóvédelmi díj: \(Int(fee)) Ft")
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Table Header Component
struct ProtectionTableHeader: View {
    var body: some View {
        HStack {
            Text("Összeghatár")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Díj")
                .font(.system(.headline, design: .rounded))
                .frame(width: 60)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(
            LinearGradient(gradient:
                Gradient(colors: [Color.yellow, Color.yellow.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - Table Row Component
struct ProtectionTableRowNew: View {
    let fee: WorkerProtectionFee
    let isEven: Bool
    let isCurrentCategory: Bool
    @State private var isBlinking = false
    
    private var rangeText: String {
        if fee.maxValue == .infinity {
            return "\(Int(fee.minValue))Ft felett"
        } else if fee.minValue == 0 {
            return "0-\(Int(fee.maxValue))Ft"
        } else {
            return "\(Int(fee.minValue))-\(Int(fee.maxValue))Ft"
        }
    }
    
    private var feeText: String {
        if let fixedFee = fee.fixedFee {
            return "\(Int(fixedFee))Ft"
        }
        return "\(Int(fee.percentage))%" + (fee.minValue == 0 ? "*" : "")
    }
    
    var body: some View {
        HStack {
            Text(rangeText)
                .font(.system(.body, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(feeText)
                .font(.system(.body, design: .rounded))
                .frame(width: 60)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.03), radius: 3, y: 2)
        )
        .opacity(isCurrentCategory && isBlinking ? 0.7 : 1.0)
        .onAppear {
            if isCurrentCategory {
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever()) {
                    isBlinking.toggle()
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isCurrentCategory {
            return Color.yellow.opacity(0.3)
        }
        return isEven ? Color(.systemBackground) : Color(.systemGray6)
    }
}

// MARK: - Protection Table Component
struct ProtectionTableNew: View {
    let fees: [WorkerProtectionFee]
    let currentAmount: Double
    
    private func isCurrentCategory(_ fee: WorkerProtectionFee) -> Bool {
        return currentAmount >= fee.minValue && (fee.maxValue == .infinity || currentAmount <= fee.maxValue)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ProtectionTableHeader()
            
            ForEach(Array(fees.enumerated()), id: \.element.id) { index, fee in
                ProtectionTableRowNew(
                    fee: fee,
                    isEven: index % 2 == 0,
                    isCurrentCategory: isCurrentCategory(fee)
                )
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Main View
struct WorkerProtectionView: View {
    @StateObject private var model = WorkerProtectionModel()
    @State private var selectedAmount = ""
    @State private var calculatedFee: Double? = nil
    let initialAmount: Double?
    
    init(initialAmount: Double? = nil) {
        self.initialAmount = initialAmount
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text(NSLocalizedString("workerprotection_title", comment: ""))
                    .font(.custom("OrelegaOne-Regular", size: 29))
                    .bold()
                    .padding(.top)
                
                Text(NSLocalizedString("workerprotection_subtitle", comment: ""))
                    .font(.custom("OrelegaOne-Regular", size: 18))
                    .foregroundColor(.gray)
                
                // Table
                ProtectionTableNew(fees: model.protectionFees, currentAmount: initialAmount ?? 0)
                
                // Calculator
                VStack(spacing: 15) {
                    Text(NSLocalizedString("calculator_title", comment: ""))
                        .font(.custom("Pacifico-Regular", size: 20))
                        .padding(.top)
                    
                    HStack {
                        TextField((NSLocalizedString("table_header_fee", comment: "")), text: $selectedAmount)
                            .font(.custom("OrelegaOne-Regular", size: 20))
                        
                        Button(action: calculateFee) {
                            Text(NSLocalizedString("calculator_button", comment: ""))
                                .font(.custom("Pacifico-Regular", size: 14))

                        }
                    }
                    
                    if let fee = calculatedFee {
                        Text("buyer_protection_fee")
                            .padding(.vertical)
                        HStack{
                            Text(" \(fee, format: .number)")
                                .padding(.vertical)
                            
                            Text("currency")
                                .padding(.vertical)
                        }}
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .onAppear {
            if let amount = initialAmount {
                selectedAmount = String(Int(amount))
                calculatedFee = model.calculateTotalFee(for: amount)
            }
        }
    }
    
    private func calculateFee() {
        if let amount = Double(selectedAmount) {
            withAnimation {
                calculatedFee = model.calculateTotalFee(for: amount)
            }
        }
    }
}

// MARK: - Preview Provider
struct WorkerProtectionView_Previews: PreviewProvider {
    static var previews: some View {
        WorkerProtectionView(initialAmount: 10000)
    }
}
