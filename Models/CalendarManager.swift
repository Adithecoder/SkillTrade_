//
//  CalendarManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

import SwiftUI
import Foundation
import Combine

// MARK: - Calendar Manager
class CalendarManager: ObservableObject {
    // Your properties remain the same
    @Published var weeklySchedule: [WeekDay: [TimeRange]] = [:]
    @Published var exceptions: [Date] = []
    @Published var appointments: [Appointment] = []

    // All your existing methods remain the same
    func addTimeRange(_ range: TimeRange, to day: WeekDay) {
        var ranges = weeklySchedule[day] ?? []
        ranges.append(range)
        weeklySchedule[day] = ranges
    }

    func removeTimeRange(_ range: TimeRange, from day: WeekDay) {
        weeklySchedule[day]?.removeAll { $0.id == range.id }
    }

    func addException(_ date: Date) {
        exceptions.append(date)
    }

    func removeException(_ date: Date) {
        exceptions.removeAll { Calendar.current.isDate($0, inSameDayAs: date) }
    }

    func addAppointment(_ appointment: Appointment) {
        appointments.append(appointment)
    }

    func updateAppointmentStatus(_ appointment: Appointment, newStatus: AppointmentStatus) {
        if let index = appointments.firstIndex(where: { $0.id == appointment.id }) {
            var updatedAppointment = appointment
            updatedAppointment.status = newStatus
            appointments[index] = updatedAppointment
        }
    }

    func isTimeSlotAvailable(_ date: Date, duration: TimeInterval) -> Bool {
        if exceptions.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) }) {
            return false
        }

        let weekday = WeekDay(rawValue: Calendar.current.component(.weekday, from: date))
        guard let weekday = weekday else { return false }

        guard let ranges = weeklySchedule[weekday] else { return false }

        return ranges.contains { range in
            let slotEnd = date.addingTimeInterval(duration)
            return date >= range.start && slotEnd <= range.end &&
                !appointments.contains { appointment in
                    let appointmentEnd = appointment.date.addingTimeInterval(appointment.duration)
                    return date < appointmentEnd && slotEnd > appointment.date
                }
        }
    }
}

#if DEBUG
extension CalendarManager {
    static var preview: CalendarManager {
        let manager = CalendarManager()
        let calendar = Calendar.current
        let today = Date()

        // Create sample schedule
        for day in WeekDay.allCases {
            if let morningStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today),
               let morningEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) {
                let morningSlot = TimeRange(start: morningStart, end: morningEnd)
                manager.addTimeRange(morningSlot, to: day)
            }

            if let afternoonStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today),
               let afternoonEnd = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today) {
                let afternoonSlot = TimeRange(start: afternoonStart, end: afternoonEnd)
                manager.addTimeRange(afternoonSlot, to: day)
            }
        }

        // Add sample appointment
        if let appointmentDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today) {
            let appointment = Appointment(
                serviceProvider: User.preview,
                client: User.preview,
                date: appointmentDate,
                duration: 3600,
                status: .pending,
                notes: "Teszt időpont"
            )
            manager.appointments.append(appointment)
        }

        // Add sample exception
        if let exceptionDate = calendar.date(byAdding: .day, value: 1, to: today) {
            manager.exceptions.append(exceptionDate)
        }

        return manager
    }
}
#endif



