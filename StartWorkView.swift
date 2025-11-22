// StartWorkView.swift

import SwiftUI
import CodeScanner
import DesignSystem
internal import AVFoundation

struct StartWorkView: View {
    @StateObject private var workManager = WorkManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuthManager = ServerAuthManager.shared
    
    @State private var selectedWork: WorkData?
    @State private var showingApplications = false
    @State private var showingQRScanner = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var applications: [WorkApplication] = []
    @State private var refreshID = UUID()
    @State private var navigateToQRCode = false // Új állapot a navigációhoz
    @State private var navigateToEmployeeView = false
    @State private var scannedWorkData: WorkData?
    
    let work: WorkData
//    let onTap: () -> Void
//    let onApplicationsTap: () -> Void
//    let onShowQRCode: () -> Void
//    let onShowQRCode2: () -> Void
    var body: some View {
        NavigationView {
            
            ZStack {
                // Háttér
//                Image("hatter2")
//                    .resizable()
//                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {

                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18))
                                .foregroundColor(.DesignSystem.fokekszin)
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text("Munkáid kezelése")
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            refreshWorks()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundStyle( Color.DesignSystem.fokekszin )
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    // Header
                    VStack(spacing: 16) {

                        
                        Text("Itt kezelheted a posztolt munkáidat és a jelentkezéseket")
                            .font(.custom("Lexend", size: 16))
                            .foregroundColor(.DesignSystem.descriptions)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 10)
                    
                    
                    HStack(spacing: 12) {

                        Image(systemName: "person")
                        Text(selectedWork?.employerName ?? workManager.publishedWorks.first?.employerName ?? work.employerName)
                            .foregroundColor(.DesignSystem.fokekszin)
                            .font(.custom("Jellee", size: 20))
//                        if let user = userManager.currentUser {
//                            if user.isVerified {
//
//
//                                    VerifiedBadge(size: 0)
//
//                                    Text(user.username)
//
//                                        .font(.custom("Jellee", size: 24))
//
//
//                            }
//                        }
                    }
                    .foregroundColor(.DesignSystem.fokekszin)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(10)

                    
                    if workManager.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                    } else if workManager.publishedWorks.isEmpty {
                        emptyStateView
                    } else {
                        workListView
                    }
                    
                    Spacer()

                               
                }
                
            }

            .sheet(item: $selectedWork) { work in
                WorkDetailView(
                    work: work,
                    onStatusUpdate: { refreshWorks() }
                )
            }
            .sheet(isPresented: $showingApplications) {
                if let work = selectedWork {
                    WorkApplicationsView(
                        work: work,
                        applications: applications,
                        onApplicationAction: { action in
                            handleApplicationAction(action)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                CodeScannerView(
                    codeTypes: [.qr],
                    completion: handleQRScan
                )
            }
            .alert("Hiba", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                refreshWorks()
            }
            // Navigáció a QR kód view-hoz
            // StartWorkView.swift - a navigáció rész
            .background(
                NavigationLink(
                    destination: WorkQRCodeView(work: selectedWork ?? work),
                    isActive: $navigateToQRCode
                ) {
                    EmptyView()
                }
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 60))
                .foregroundColor(.DesignSystem.fokekszin)
            
            Text("Még nincsenek munkáid")
                .font(.custom("Jellee", size: 24))
                .foregroundColor(.DesignSystem.fokekszin)

            
            NavigationLink(destination: SearchView2(initialSearchText: "")) {
                Text("Új munka létrehozása")
                    .font(.custom("Jellee", size: 18))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
            }
        }
        .padding()
    }
    
    
       private var workListView: some View {
           ScrollView {
               LazyVStack(spacing: 16) {
                   ForEach(workManager.publishedWorks) { work in
                       WorkCardView(
                           work: work,
                           onTap: {
                               selectedWork = work
                           },
                           onApplicationsTap: {
                               selectedWork = work
                               loadApplications(for: work)
                           },
                           onShowQRCode: {
                               selectedWork = work
//                               navigateToQRCode = true // Navigáció indítása
                           },
                           onShowQRCode2: {
//                               selectedWork = work
                               navigateToQRCode = true // Navigáció indítása
                           },
                           onDelete: {
                               deleteWork(work) // Új callback kezelése
                           }
                       )
                       .id(refreshID)
                   }
               }
               .padding()
           }
       }
    private func deleteWork(_ work: WorkData) {
           Task {
               do {
                   try await WorkManager.shared.deleteWork(work)
                   await MainActor.run {
                       refreshWorks() // Frissítjük a listát
                   }
               } catch {
                   await MainActor.run {
                       errorMessage = "Hiba a munka törlésekor: \(error.localizedDescription)"
                       showingError = true
                   }
               }
           }
       }
    
    private func refreshWorks() {
        Task {
            await workManager.fetchPublishedWorks()
        }
    }
    
    private func loadApplications(for work: WorkData) {
        isLoading = true
        applications = []
        
        Task {
            do {
                let apps = try await serverAuthManager.fetchWorkApplications(workId: work.id)
                await MainActor.run {
                    applications = apps
                    showingApplications = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Hiba a jelentkezések betöltésekor: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func handleApplicationAction(_ action: ApplicationAction) {
        Task {
            do {
                switch action {
                case .accept(let applicationId):
                    try await serverAuthManager.updateApplicationStatus(
                        applicationId: applicationId,
                        status: "accepted"
                    )
                    
                case .reject(let applicationId):
                    try await serverAuthManager.updateApplicationStatus(
                        applicationId: applicationId,
                        status: "rejected"
                    )
                    
                case .startWork(let applicationId, let employeeId):
                    // Itt kezdjük el a munkát és megnyitjuk a QR szkennert
                    if let work = selectedWork {
                        try await serverAuthManager.updateWorkStatus(
                            workId: work.id,
                            status: "Folyamatban",
                            employerID: work.employerID
                        )
                        showingQRScanner = true
                    }
                }
                
                // Frissítjük a listákat
                await MainActor.run {
                    refreshWorks()
                    if let work = selectedWork {
                        loadApplications(for: work)
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Hiba a művelet során: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func handleQRScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let result):
            let qrCode = result.string
            print("📱 Beolvasott QR kód: \(qrCode)")
            
            if let work = selectedWork {
                startWorkWithQRCode(work: work, qrCode: qrCode)
            }
            
        case .failure(let error):
            errorMessage = "QR kód olvasási hiba: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func startWorkWithQRCode(work: WorkData, qrCode: String) {
        Task {
            do {
                // Ellenőrizzük, hogy a QR kód érvényes employee ID-t tartalmaz-e
                guard let employeeId = UUID(uuidString: qrCode) else {
                    throw NSError(domain: "Invalid QR code", code: 400, userInfo: [NSLocalizedDescriptionKey: "Érvénytelen QR kód formátum"])
                }
                
                // Frissítjük a munkát az employee ID-val és állapottal
                let success = try await serverAuthManager.updateWorkEmployee(
                    workId: work.id,
                    employeeID: employeeId,
                    status: "Folyamatban"
                )
                
                if success {
                    await MainActor.run {
                        errorMessage = "Munka sikeresen elindítva!"
                        showingError = true
                        refreshWorks()
                    }
                } else {
                    throw NSError(domain: "Failed to start work", code: 500, userInfo: [NSLocalizedDescriptionKey: "Nem sikerült elindítani a munkát"])
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Hiba a munka indításakor: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

// Módosított WorkCardView

struct WorkCardView: View {
    let work: WorkData
    let onTap: () -> Void
    let onApplicationsTap: () -> Void
    let onShowQRCode: () -> Void
    let onShowQRCode2: () -> Void
    let onDelete: () -> Void // Új callback a törléshez
    @State private var applicationCount = 0
    @State private var isLoadingApplications = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingStatusUpdate = false
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    
                    //                    Text(work.employerName)
                    //                        .font(.custom("Lexend", size: 20))
                    //                        .foregroundColor(.DesignSystem.descriptions)
                    
                    
                    Text(work.title)
                        .font(.custom("Jellee", size: 20))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .lineLimit(2)
                    
                }
                
                Spacer()
                // QR kód megjelenítése gomb
                if work.statusText == "Publikálva" || work.statusText == "Nem kezdődött el" {
                    Button(action: onShowQRCode) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(15)
                    }
                }
                
                HStack{
                    // Státusz badge
                    statusBadge
                    Button {
                        showingStatusUpdate = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundStyle(.white)
                        
                    }
                    .foregroundColor(.blue)
                }
                .padding(6)
                .background(statusColor)
                .cornerRadius(15)
                
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.circle.fill")
                    }
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.red)
                    .cornerRadius(10)
                }

            }
            
            // Munka részletek
            HStack(spacing: 16) {
                HStack {
                    Text("\(Int(work.wage)) Ft")
                        .font(.custom("Jellee", size: 18))
                        .foregroundColor(.green)
                    
//                    Divider()
//                        .frame(width: 20)
                    
                    Spacer()
                    
                    
                    Text(work.paymentType)
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                }
                

                
            }
            
            // Készségek
            if !work.skills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(work.skills.prefix(3), id: \.self) { skill in
                            Text(skill)
                                .font(.custom("Lexend", size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.DesignSystem.fokekszin.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
//            if !work.location.isEmpty {
//                VStack(alignment: .leading, spacing: 4) {
//                    Label(work.location, systemImage: "mappin.circle.fill")
//                        .font(.custom("Lexend", size: 12))
//                        .foregroundColor(.gray)
//                }
//            }
            HStack(spacing: 12) {
                           // Jelentkezések gomb
                           Button(action: {
                               loadApplicationCount()
                               onApplicationsTap()
                           }) {
                               HStack(spacing: 6) {
                                   if isLoadingApplications {
                                       ProgressView()
                                           .scaleEffect(0.8)
                                           .tint(.white)
                                   } else {
                                       Image(systemName: "person.3.fill")
                                   }
                                   
                                   Text("Jelentkezések")
                                       .font(.custom("Lexend", size: 14))
                                   
                                   if applicationCount > 0 {
                                       Text("\(applicationCount)")
                                           .font(.custom("Lexend", size: 12))
                                           .padding(.horizontal, 6)
                                           .padding(.vertical, 2)
                                           .background(Color.white)
                                           .foregroundColor(.blue)
                                           .cornerRadius(8)
                                   }
                               }
                               .foregroundColor(.white)
                               .padding(.horizontal, 12)
                               .padding(.vertical, 8)
                               .background(Color.blue)
                               .cornerRadius(10)
                           }
                           .disabled(isLoadingApplications)
                           
//                           // QR kód megjelenítése gomb
//                           if work.statusText == "Publikálva" || work.statusText //       == "Nem kezdődött el" {
//                               Button(action: onShowQRCode) {
//                                   HStack(spacing: 6) {
//                                       Image(systemName: "qrcode")
//                                       Text("Infó")
//                                           .font(.custom("Lexend", size: 14))
//                                   }
//                                   .foregroundColor(.white)
//                                   .padding(.horizontal, 12)
//                                   .padding(.vertical, 8)
//                                   .background(Color.green)
//                                   .cornerRadius(10)
//                               }
//                           }
                
                Spacer()
                Button(action: onShowQRCode2) {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                        Text("QR Kód")
                            .font(.custom("Lexend", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.yellow)
                    .cornerRadius(10)
                }
                           
                           
                           // Részletek gomb
//                           Button(action: onTap) {
//                               Image(systemName: "chevron.right")
//                                   .foregroundColor(.DesignSystem.fokekszin)
//                                   .font(.system(size: 16, weight: .medium))
//                           }
                       }
                   }
                   .padding()
                   .background(
                       RoundedRectangle(cornerRadius: 20)
                           .fill(Color.white)
                           .overlay(
                               RoundedRectangle(cornerRadius: 20)
                                   .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                           )
                   )
                   .listRowInsets(EdgeInsets())
                   .padding(4)

                   .background(Color.white)
                   .cornerRadius(25)
                   .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                   .onAppear {
                       loadApplicationCount()
                   }
                   .alert("Hiba", isPresented: $showError) {
                       Button("OK", role: .cancel) { }
                   } message: {
                       Text(errorMessage)
                   }
                   .alert("Munka törlése", isPresented: $showingDeleteAlert) {
                       Button("Mégse", role: .cancel) { }
                       Button("Törlés", role: .destructive) {
                           onDelete() // Meghívjuk a callback-et
                       }
                   } message: {
                       Text("Biztosan törölni szeretnéd ezt a munkát?")
                   }
                   .sheet(isPresented: $showingStatusUpdate) {
                       StatusUpdateView(
                           currentStatus: work.statusText,
                           onStatusUpdate: { newStatus in
                               updateWorkStatus(newStatus)
                           }
                       )
                   }
        
               }
    
    private var statusBadge: some View {
        Text(work.statusText)
            .font(.custom("Lexend", size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch work.statusText {
        case "Publikálva", "Nem kezdődött el":
            return .blue
        case "Folyamatban":
            return .orange
        case "Ellenőrzésre vár":
            return .purple
        case "Befejezve":
            return .green
        default:
            return .gray
        }
    }
    
    private func loadApplicationCount() {
        guard !isLoadingApplications else { return }
        
        isLoadingApplications = true
        
        Task {
            do {
                let apps = try await ServerAuthManager.shared.fetchWorkApplications(workId: work.id)
                await MainActor.run {
                    applicationCount = apps.count
                    isLoadingApplications = false
                }
            } catch {
                await MainActor.run {
                    isLoadingApplications = false
                    // Csak logoljuk a hibát, de ne jelenítsük meg a felhasználónak
                    print("❌ Hiba a jelentkezések számának lekérésekor: \(error)")
                    
                    // Ha nem hitelesítési hiba, akkor mutassuk meg
                    if (error as NSError).code != 401 {
                        errorMessage = "Nem sikerült betölteni a jelentkezések számát"
                        showError = true
                    }
                }
            }
        }
    }
    
    // FIX: Implement status update here for WorkCardView
    private func updateWorkStatus(_ status: String) {
        Task {
            do {
                try await WorkManager.shared.updateWorkStatus(
                    workId: work.id,
                    newStatus: status,
                    employerID: work.employerID
                )
            } catch {
                await MainActor.run {
                    errorMessage = "Nem sikerült frissíteni a státuszt: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// WorkQRCodeView.swift
import SwiftUI
import CoreImage.CIFilterBuiltins

struct WorkQRCodeView: View {
    let work: WorkData
    @Environment(\.presentationMode) var presentationMode
    @State private var isShowingFullID = false
    @State private var isCopied = false
    
    init(work: WorkData) {
        self.work = work
    }
    
    var body: some View {
        ZStack {
            // Háttér
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        
                        
                        Text("Munka QR Kódja")
                            .font(.custom("Jellee", size: 28))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .multilineTextAlignment(.center)
                        
                    }
                    .padding(.top, 20)
                    
                    // QR kód kártya
                    VStack(spacing: 20) {
                        if let qrCodeImage = generateQRCode(from: work.id.uuidString) {
                            Image(uiImage: qrCodeImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 250, height: 250)
                                .padding()
                                .cornerRadius(20)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.orange)
                                Text("Nem sikerült generálni a QR kódot")
                                    .font(.custom("Lexend", size: 16))
                                    .foregroundColor(.red)
                            }
                            .padding()
                        }
                        
                        
                        // ID sor lenyílóval
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(isShowingFullID
                                     ? "Munka ID:"
                                     : "Munka ID: \(work.id.uuidString.prefix(8))...")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.gray)
                                .textSelection(.enabled)
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                
                                Spacer(minLength: 8)
                                
                                Button {
                                    withAnimation(.easeInOut) {
                                        isShowingFullID.toggle()
                                    }
                                } label: {
                                    Image(systemName: isShowingFullID ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .accessibilityLabel(isShowingFullID ? "ID összecsukása" : "ID lenyitása")
                            }
                            
                            if isShowingFullID {
                                // Opcionális: külön sorban monospaced stílussal
                                Text(work.id.uuidString)
                                    .font(.custom("Lexend", size: 14))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(4)
                    .cornerRadius(20)
                    
                    // Munka információk
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Munka adatai")
                            .font(.custom("Jellee", size: 22))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        InfoRowQR(icon: "briefcase", title: "Munka neve", value: work.title)
                        InfoRowQR(icon: "person", title: "Munkáltató", value: work.employerName)
                        InfoRowQR(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
                        InfoRowQRPayment(icon: "clock", title: "Fizetés típus", value: work.paymentType)
                        
                        if !work.location.isEmpty {
                            InfoRowQR(icon: "mappin.circle", title: "Helyszín", value: work.location)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(4)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Művelet gombok
                    VStack(spacing: 12) {
                        
                        Button(action: {
                            UIPasteboard.general.string = work.id.uuidString
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isCopied = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isCopied = false
                                }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: isCopied ? "checkmark.circle" : "doc.on.doc")
                                    .contentTransition(.symbolEffect(.replace))
                                    .font(.custom("Jellee", size: 20))
                                
                                
                                Text(isCopied ? "" : "ID másolása")
                                    .font(.custom("Jellee", size: 20))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isCopied ? Color.green : Color.blue)
                            .cornerRadius(20)
                        }
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle")
                                Text("Bezárás")
                                    .font(.custom("Jellee", size: 20))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarTitle("QR Kód", displayMode: .inline)
        .navigationBarBackButtonHidden(false)
    }
    
    private func generateQRCode(from work: WorkData) -> UIImage? {
        // JSON formátumban több adat
        let qrContent: [String: Any] = [
            "workId": work.id.uuidString,
            "title": work.title,
            "employerId": work.employerID.uuidString,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: qrContent),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        
        return generateQRCode(from: jsonString)
    }
    
    // String -> UIImage QR generator helper
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        // Optional: error correction level (L, M, Q, H)
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return nil }
        // Scale up the image to avoid blur
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

struct InfoRowQR: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.DesignSystem.fokekszin)
                    .frame(width: 20)
                
                Text(title)
                    .font(.custom("Lexend", size: 14))
                    .foregroundStyle(Color.DesignSystem.fenyozold)
            }
            
            Spacer()
            
            Text(value)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct InfoRowQRPayment: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.DesignSystem.fokekszin)
                    .frame(width: 20)
                
                Text(title)
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.DesignSystem.fokekszin)
            }
            
            Spacer()
            
            Text(value)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.green)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Work Detail View
struct WorkDetailView: View {
    @State private var Workend = false
    let work: WorkData
    let onStatusUpdate: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showingStatusUpdate = false
    @State private var newStatus = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(work.title)
                            .font(.custom("Jellee", size: 28))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        Text("Létrehozva: \(formattedDate(work.createdAt))")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    // Státusz szekció
                    statusSection
                    
                    // Fizetés szekció
                    paymentSection
                    
                    // Helyszín szekció
                    if !work.location.isEmpty {
                        locationSection
                    }
                    
                    // Készségek szekció
                    if !work.skills.isEmpty {
                        skillsSection
                    }
                    
                    // Leírás szekció
                    if let description = work.description, !description.isEmpty {
                        descriptionSection
                    }
                    
                    // Művelet gombok
                    actionButtons
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kész") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size:20))
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .sheet(isPresented: $showingStatusUpdate) {
                StatusUpdateView(
                    currentStatus: work.statusText,
                    onStatusUpdate: { newStatus in
                        updateWorkStatus(newStatus)
                    }
                )
            }
            .alert("Munka törlése", isPresented: $showingDeleteAlert) {
                Button("Mégse", role: .cancel) { }
                Button("Törlés", role: .destructive) {
                    deleteWork()
                }
            } message: {
                Text("Biztosan törölni szeretnéd ezt a munkát?")
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Állapot")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
            
            HStack {
                Text(work.statusText)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(statusColor)
                
                Spacer()
                
                Button("Módosítás") {
                    showingStatusUpdate = true
                }
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.blue)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
        }
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fizetés")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
            
            HStack {
                HStack {
                    Text("\(Int(work.wage)) Ft")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.green)
                    
                    Spacer()
                    Text(work.paymentType)
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Helyszín")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
            
            HStack {
                Label(work.location, systemImage: "mappin.circle.fill")
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.DesignSystem.fokekszin)

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)

        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Szükséges készségek")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
            
            ScrollView(.horizontal, showsIndicators: false) {

                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(work.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.custom("Lexend", size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.DesignSystem.fokekszin)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
            )
            .listRowInsets(EdgeInsets())
            .padding(4)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leírás")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
            
            Text(work.description ?? "")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 100, alignment: .init(horizontal: .leading, vertical: .top))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                        )
                )
                .listRowInsets(EdgeInsets())
                .padding(4)
            
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
//            if work.statusText != "Befejezve" {
//                Button("Munka befejezése") {
//                    updateWorkStatus("Befejezve")
//                }
//                .font(.custom("Jellee", size: 18))
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(Color.green)
//                .cornerRadius(20)
//            }
            
            Button(action: {
                updateWorkStatus("Befejezve")

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    Workend = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        Workend = false
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: Workend ? "checkmark.circle" : "forward.end.circle")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.custom("Jellee", size: 20))

                    
                    Text(Workend ? "Lezárva" : "Munka befejezése")
                        .font(.custom("Jellee", size: 20))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Workend ? Color.green : Color.blue)
                .cornerRadius(20)
            }
            
            Button("Munka törlése", role: .destructive) {
                showingDeleteAlert = true
            }
            .font(.custom("Jellee", size: 18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(20)
        }
    }
    
    private var statusColor: Color {
        switch work.statusText {
        case "Publikálva", "Nem kezdődött el":
            return .blue
        case "Folyamatban":
            return .orange
        case "Ellenőrzésre vár":
            return .purple
        case "Befejezve":
            return .green
        default:
            return .gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd. HH:mm"
        formatter.locale = Locale(identifier: "hu_HU")
        return formatter.string(from: date)
    }
    
    private func updateWorkStatus(_ status: String) {
        Task {
            do {
                try await WorkManager.shared.updateWorkStatus(
                    workId: work.id,
                    newStatus: status,
                    employerID: work.employerID
                )
                
                await MainActor.run {
                    onStatusUpdate()
                    dismiss()
                }
            } catch {
                print("❌ Hiba a státusz frissítésekor: \(error)")
            }
        }
    }
    
    private func deleteWork() {
        Task {
            do {
                try await WorkManager.shared.deleteWork(work)
                
                await MainActor.run {
                    onStatusUpdate()
                    dismiss()
                }
            } catch {
                print("❌ Hiba a munka törlésekor: \(error)")
            }
        }
    }
}

// MARK: - Status Update View
struct StatusUpdateView: View {
    let currentStatus: String
    let onStatusUpdate: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus = ""
    
    let statusOptions = ["Publikálva", "Nem kezdődött el", "Folyamatban", "Ellenőrzésre vár", "Befejezve"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Jelenlegi állapot")
                    .font(.custom("Jellee", size: 20))
                    .foregroundStyle(Color.DesignSystem.fokekszin)
                ) {
//                    Text(currentStatus)
                    Text(selectedStatus)
                        .font(.custom("Lexend", size: UIFontMetrics.default.scaledValue(for: 16)))                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                                )
                        )
                        .listRowInsets(EdgeInsets())
                        .padding(4)
                }
                
                
                Section(header: Text("Új állapot kiválasztása")
                    .font(.custom("Jellee", size: 20))
                    .foregroundStyle(Color.DesignSystem.fokekszin)) {
                    Picker("Állapot", selection: $selectedStatus) {
                        ForEach(statusOptions, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .pickerStyle(.wheel)
                    .font(.custom("Jellee", size:16))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                            )
                    )
                    .listRowInsets(EdgeInsets())
                    .padding(4)
                }
            }
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Mégse") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 20))
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.red, Color.orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mentés") {
                        if !selectedStatus.isEmpty {
                            onStatusUpdate(selectedStatus)
                            dismiss()
                        }
                    }
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))                    .disabled(selectedStatus.isEmpty)
                    .font(.custom("Lexend", size: 20))
                }
            }
            .onAppear {
                selectedStatus = currentStatus
            }
        }
    }
}

// MARK: - Work Applications View
struct WorkApplicationsView: View {
    let work: WorkData
    let applications: [WorkApplication]
    let onApplicationAction: (ApplicationAction) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if applications.isEmpty {
                    emptyStateView
                } else {
                    applicationsListView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kész") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 20))
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Még nincsenek jelentkezők")
                .font(.custom("Jellee", size: 24))
                .foregroundColor(.DesignSystem.fokekszin)
            
            Text("Várj a jelentkezőkre, vagy oszd meg a munkát")
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private var applicationsListView: some View {
        List {
            ForEach(applications) { application in
                ApplicationRowView(
                    application: application,
                    onAction: onApplicationAction
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Application Row View
struct ApplicationRowView: View {
    let application: WorkApplication
    let onAction: (ApplicationAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.applicantName)
                        .font(.custom("Jellee", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("Jelentkezett: \(formattedDate(application.applicationDate))")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                statusBadge
            }
            
            if application.status == .pending {
                HStack(spacing: 12) {
                    Button("Elfogadás") {
                        onAction(.accept(application.id))
                    }
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(8)
                    
                    Button("Elutasítás") {
                        onAction(.reject(application.id))
                    }
                    .font(.custom("Lexend", size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var statusBadge: some View {
        Text(statusText)
            .font(.custom("Lexend", size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch application.status {
        case .pending: return "Függőben"
        case .accepted: return "Elfogadva"
        case .rejected: return "Elutasítva"
        case .withdrawn: return "Visszavonva"
        }
    }
    
    private var statusColor: Color {
        switch application.status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        case .withdrawn: return .gray
        }
    }
    
    private func formattedDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MM.dd. HH:mm"
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Models
enum ApplicationAction {
    case accept(String)
    case reject(String)
    case startWork(String, String) // applicationId, employeeId
}

// WorkData.swift (hozzáadni, ha még nincs)
extension WorkData {
    static var mockWork: WorkData {
        WorkData(
            id: UUID(),
            title: "Mock Munka",
            employerName: "Ez egy mock munka",
            employerID: UUID(),
            employeeID: UUID(),
            wage: 1000,
            paymentType: "Készpénzzel",
            statusText: "Mock Munkáltató",
            startTime: Date(),
            endTime: Date(),
            duration: TimeInterval(),
            progress: 0.0,
            location: "Példa",
            skills: ["webdev", "wewdededededededced", "dhdhdhhd", "jdjdjdjdj", "dsjjsjdj"],
            category: nil,
            description: "Ez is pl",
            createdAt: Date()
        )
    }
}

// MARK: - ServerAuthManager Extension

// MARK: - Preview
#Preview {
    StartWorkView(work: WorkData.mockWork)
}

#Preview {
    WorkQRCodeView(work: WorkData.mockWork)
}

#Preview {
    WorkDetailView(work: WorkData.mockWork, onStatusUpdate: {})
}

#Preview {
    StatusUpdateView(currentStatus: "Publikálva", onStatusUpdate: {_ in })
}

