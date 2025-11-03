//
//  AppointmentView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//


// © 2024 SkillTrade. Minden jog fenntartva. (All Rights Reserved)

// AppointmentView.swift - Időpontfoglaló nézet
import SwiftUI
import Foundation
import DesignSystem

struct AppointmentView: View {
    let service: Service
    @StateObject private var calendarManager = CalendarManager()
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedTime: Date?
    @State private var notes = ""
    @State private var showConfirmation = false
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showPaymentConfirmation = false
    @State private var currentAppointment: Appointment? = nil
    
    private let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Naptár nézet
                    DatePicker(
                        NSLocalizedString("choose-day", comment:"" ),
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    
                    // Elérhető időpontok
                    if let ranges = service.availability.weeklySchedule[WeekDay(rawValue: Calendar.current.component(.weekday, from: selectedDate)) ?? .monday] {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(NSLocalizedString("free-slots", comment:"" ))
                                .font(.custom("OrelegaOne-Regular", size: 20))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(ranges) { range in
                                        Button(action: {
                                            selectedTime = range.start
                                            showConfirmation = true
                                        }) {
                                            Text(hourFormatter.string(from: range.start))
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(selectedTime == range.start ? Color.yellow : Color.gray.opacity(0.1))
                                                .foregroundColor(selectedTime == range.start ? .black : .primary)
                                                .cornerRadius(8)
                                        }
                                        .disabled(!calendarManager.isTimeSlotAvailable(range.start, duration: 3600))
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        Text(NSLocalizedString("no-available-times", comment:"" ))
                            .foregroundColor(.gray)
                            .font(.custom("OrelegaOne-Regular", size: 18))
                            .padding()
                    }
                    
                    // Jegyzetek
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("comment", comment:"" ))
                            .foregroundColor(Color.black)
                            .underlineTextField()
                            .font(.custom("OrelegaOne-Regular", size: 18))
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    .padding(.horizontal)
                    
                    // Foglalás gomb
                    Button(action: submitAppointment) {
                        HStack {
//                            if isSubmitting {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
//                                    .padding(.trailing, 8)
//                            }
                            Text(isSubmitting ? NSLocalizedString("sending...", comment: "") : NSLocalizedString("book-appointment", comment: ""))                                .font(.custom("OrelegaOne-Regular", size: 20))
                                .foregroundColor(selectedTime == nil ?  Color.black.opacity(0.3): Color.DesignSystem.descriptions)

                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(selectedTime == nil ? Color.gray : Color.DesignSystem.fokekszin)
                        .shadow(color: selectedTime == nil ? Color.gray : Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                    }
                    .disabled(selectedTime == nil || isSubmitting)
                    .padding(.horizontal)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(NSLocalizedString("select-workday", comment:"" ))
                        .focim()
                        .bold()
                        .padding(.top, -1)
                        .padding(.leading, -5)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment:"" ))
                        
                    { dismiss() }
                }
            }
            .alert(NSLocalizedString("successful-appointment", comment:"" ), isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(NSLocalizedString("successful-appointment2", comment:"" ))
            }
        }
        .onAppear {
            // Időpontok betöltése
            calendarManager.weeklySchedule = service.availability.weeklySchedule
            calendarManager.exceptions = service.availability.exceptions
        }
        .sheet(isPresented: $showPaymentConfirmation) {
            if let appointment = currentAppointment {
                PaymentConfirmationView(service: service, appointment: appointment)
            }
        }
    }
    
    private func submitAppointment() {
        guard let time = selectedTime else { return }
        
        isSubmitting = true
        
        // Szimuláljuk az API hívást
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let appointment = Appointment(
                serviceProvider: service.advertiser,
                client: User.preview,  // Itt majd a bejelentkezett felhasználó lesz
                date: time,
                duration: 3600, // 1 óra
                status: .pending,
                notes: notes.isEmpty ? nil : notes
            )
            
            currentAppointment = appointment
            isSubmitting = false
            showPaymentConfirmation = true
        }
    }
}

#if DEBUG
struct AppointmentView_Previews: PreviewProvider {
    static var previews: some View {
        AppointmentView(service: Service.preview)
            .environmentObject(CalendarManager.preview)
    }
}
#endif
