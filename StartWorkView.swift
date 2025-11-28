// StartWorkView.swift

import SwiftUI
import CodeScanner
import DesignSystem
internal import AVFoundation

struct StartWorkView: View {
    @StateObject private var workManager = WorkManager.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var serverAuthManager = ServerAuthManager.shared
    @State private var showingTrackingView = false
    @State private var navigateToTrackingView = false

    @State private var selectedWork: WorkData?
    @State private var selectedWorkInfos: WorkData?

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
    
    @State private var completionCode = "" // Új: lezárási kód
        @State private var showingCompletionDialog = false // Új: lezárási dialógus
        @State private var workStartTime: Date? // Új: munka kezdési ideje
        @State private var elapsedTime: TimeInterval = 0 // Új: eltelt idő
        @State private var timer: Timer? // Új: időzítő
    
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

            .sheet(item: $selectedWorkInfos) { work in
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
            // Add hozzá a .sheet modifierekhez
            .sheet(isPresented: $showingCompletionDialog) {
                WorkCompletionView(
                    work: selectedWork ?? work,
                    completionCode: completionCode,
                    onComplete: { code in
                        verifyAndCompleteWork(code: code)
                    }
                )
            }
            // StartWorkView body részéhez add hozzá ezt a sheet-et a többi sheet mellé:
            .sheet(isPresented: $showingTrackingView) {
                if let work = selectedWork {
                    WorkTrackingView(work: work)
                }
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
            // Navigáció a QR kód view-hoz
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
    private func verifyAndCompleteWork(code: String) {
        guard code == completionCode else {
            errorMessage = "Hibás lezárási kód!"
            showingError = true
            return
        }
        
        Task {
            do {
                if let work = selectedWork {
                    try await WorkManager.shared.updateWorkStatus(
                        workId: work.id,
                        newStatus: "Befejezve",
                        employerID: work.employerID
                    )
                    
                    await MainActor.run {
                        stopTimer()
                        refreshWorks()
                        showingCompletionDialog = false
                        errorMessage = "Munka sikeresen befejezve!"
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "✕ Hiba a munka befejezésekor: \(error.localizedDescription)"
                    showingError = true
                }
            }
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
                    .font(.custom("Lexend", size: 20))
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
                    VStack(spacing: 8) {
                        // Eltelt idő megjelenítése folyamatban lévő munkáknál
                        if work.statusText == "Folyamatban" {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                Text("Folyamatban: \(formattedElapsedTime(elapsedTime))")
                                    .font(.custom("Lexend", size: 14))
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
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
                            },
                            onShowQRCode2: {
                                selectedWork = work
                                navigateToQRCode = true
                            },
                            onDelete: {
                                deleteWork(work)
                            },
                            onComplete: { // Új callback a befejezéshez
                                selectedWork = work
                                generateCompletionCode()
                                showingCompletionDialog = true
                            }
                        )
                        .id(refreshID)
                    }
                }
            }
            .padding()
        }
    }
    
    private func generateCompletionCode() {
        // 6 számjegyű véletlenszerű kód generálása
        completionCode = String(format: "%06d", Int.random(in: 100000...999999))
        
        // Kód mentése a szerverre
        if let work = selectedWork {
            Task {
                do {
                    try await serverAuthManager.saveCompletionCode(
                        workId: work.id,
                        completionCode: completionCode
                    )
                    
                    await MainActor.run {
                        errorMessage = "✅ Lezárási kód generálva: \(completionCode)\n\nAdd meg ezt a kódot a munkavállalónak!"
                        showingError = true
                        
                        // DEBUG: Konzolra kiírás
                        print("🔐 LEZÁRÁSI KÓD GENERÁLVA:")
                        print("   - Munka ID: \(work.id)")
                        print("   - Munka cím: \(work.title)")
                        print("   - Lezárási kód: \(completionCode)")
                        print("   - Idő: \(Date())")
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "✕ Hiba a kód mentésekor: \(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
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
                    // Munka indítása és kezdési idő mentése
                    if let work = selectedWork {
                        try await serverAuthManager.updateWorkStatus(
                            workId: work.id,
                            status: "Folyamatban",
                            employerID: work.employerID
                        )
                        // Kezdési idő mentése
                        await MainActor.run {
                            workStartTime = Date()
                            startTimer()
                        }
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
    
    // Időzítő indítása
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = workStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    // Időzítő leállítása
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
        workStartTime = nil
    }

    // Formázott idő string
    private func formattedElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
struct WorkCompletionView: View {
    let work: WorkData
    let completionCode: String
    let onComplete: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var enteredCode = ""
    @State private var isVerifying = false
    
    var body: some View {
        NavigationView {
            
            VStack(spacing: 30) {
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
                    
                    Text("Munkáid kezelése")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                    }) {
                        Image(systemName: "lock")
                            .font(.system(size: 16))
                            .foregroundStyle( Color.DesignSystem.fokekszin )
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("Munka lezárása")
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    Text("A munka lezárásához add meg a lezárási kódot")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    Text("Lezárási kód:")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.primary)
                    
                    Text(completionCode)
                        .font(.custom("Jellee", size: 32))
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                VStack(spacing: 12) {
                    Text("Add meg a kódot:")
                        .font(.custom("Lexend", size: 14))
                        .foregroundColor(.gray)
                    
                    TextField("XXXXXX", text: $enteredCode)
                        .font(.custom("Jellee", size: 24))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onChange(of: enteredCode) { newValue in
                            // Csak számok és max 6 karakter
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            enteredCode = String(filtered.prefix(6))
                        }
                }
                
                Spacer()
                
                Button(action: {
                    isVerifying = true
                    onComplete(enteredCode)
                }) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Munka lezárása")
                            .font(.custom("Lexend", size: 20))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(enteredCode.count == 6 ? Color.green : Color.gray)
                    .cornerRadius(20)
                }
                .disabled(enteredCode.count != 6 || isVerifying)
                
                Button("Mégse") {
                    dismiss()
                }
                .font(.custom("Lexend", size: 16))
                .foregroundColor(.red)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)

        }
    }
}

// Módosított WorkCardView

// Módosított WorkCardView
struct WorkCardView: View {
    let work: WorkData
    let onTap: () -> Void
    let onApplicationsTap: () -> Void
    let onShowQRCode: () -> Void
    let onShowQRCode2: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    @State private var feedbackMessage = ""
    @State private var applicationCount = 0
    @State private var isLoadingApplications = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingStatusUpdate = false
    @State private var showingDeleteAlert = false
    @State private var completionCode = ""
    @State private var isLoadingCode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack {
                NavigationLink(destination: WorkDetailView(
                    work: work,
                    onStatusUpdate: { }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.title)
                            .font(.custom("Jellee", size: 20))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .lineLimit(2)
                        
                        // Egyéb tartalom...
                    }
                }
                

                Spacer()
                
                Button(action: {
                    showingStatusUpdate = true

                }) {
                    HStack {
                        statusBadge

                        Image(systemName: "pencil.circle.fill")
                            .font(.custom("Lexend", size: 20))
                    }
                    .foregroundColor(.white)
                    
                }
                .padding(6)
                .background(statusColor)
                .cornerRadius(15)

//                Button(action: {
//                    showingDeleteAlert = true
//                }) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "trash.circle.fill")
//                    }
//                    .foregroundColor(.white)
//                    .padding(6)
//                    .background(Color.red)
//                    .cornerRadius(10)
//                }
            }
            
            // Munka részletek
            HStack(spacing: 16) {
                HStack {
                    Text("\(Int(work.wage)) Ft")
                        .font(.custom("Jellee", size: 18))
                        .foregroundColor(.DesignSystem.fenyozold)
                    
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
            
            // LEZÁRÁSI KÓD - CSAK FOLYAMATBAN LÉVŐ MUNKÁKNAK
            if work.statusText == "Folyamatban" {
                completionCodeSection
            }
            
            // Művelet gombok
            actionButtons
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(statusColor.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(statusColor, lineWidth: 2)
                )
        )
        .listRowInsets(EdgeInsets())
        .padding(4)
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            // Csak a szükséges adatokat töltjük be
            loadApplicationCount()
        }
        .task {
            // Külön task a kód betöltésére
            await loadCompletionCode()
        }
        .alert("Hiba", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Munka törlése", isPresented: $showingDeleteAlert) {
            Button("Mégse", role: .cancel) { }
            Button("Törlés", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Biztosan törölni szeretnéd ezt a munkát?")
        }
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateView(
                currentStatus: work.statusText,
                onStatusUpdate: { newStatus in
                    updateWorkStatus(newStatus)
                },
                onDelete: {
                    onDelete()
                }
            )
        }
    }
    
    // MARK: - Külön view komponensek a komplexitás csökkentésére
    
    private var completionCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
                
                Text("Lezárási kód")
                    .font(.custom("Lexend", size: 12))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Spacer()
                
                if completionCode.isEmpty && !isLoadingCode {
                    Button(action: {
                        generateNewCode()
                    }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Generálás")
                                .font(.custom("Lexend", size: 12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(15)
                    }
                } else if isLoadingCode {
                    HStack {
                        Text("Kód betöltése...")
                            .font(.custom("Lexend", size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack {
                        Button(action: {
                            UIPasteboard.general.string = completionCode
                            showFeedbackMessage("✓ Kód kimásolva: \(completionCode)")
                        }) {
                            Text(completionCode)
                                .font(.custom("Jellee", size: 16))
                                .foregroundColor(.green)
                                .monospacedDigit()
                        }
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = completionCode
                            showFeedbackMessage("✓ Kód kimásolva: \(completionCode)")
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(.DesignSystem.fokekszin)
                                .font(.system(size: 16))
                        }
                        
                        if isLoadingCode {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !completionCode.isEmpty {
                            Button(action: {
                                generateNewCode()
                            }) {
                                Image(systemName: "plus.arrow.trianglehead.clockwise")
//                                Text("Új kód")
                                    .font(.system(size: 16))
                                    .foregroundColor(.DesignSystem.fokekszin)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    
                }
                

                
            }
            
            if completionCode.isEmpty && !isLoadingCode {

                EmptyView()
            } else if isLoadingCode {
                HStack {
                    Text("Kód betöltése...")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Csak akkor add meg ezt a kódot a munkavállalónak, ha befejezte a munkát.")
                    .font(.custom("Lexend", size: 10))
                    .foregroundColor(.red)
            }

            
            if !feedbackMessage.isEmpty {
                 HStack {
                     Text(feedbackMessage)
                         .font(.custom("Lexend", size: 12))
                         .foregroundColor(feedbackMessage.hasPrefix("✓") ? .green : .red)
                     Spacer()
                 }
                 .padding(8)
                 .background(feedbackMessage.hasPrefix("✓") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                 .cornerRadius(15)
                 .transition(.opacity)
                 .onAppear {
                     // 3 másodperc után eltűnik az üzenet
                     DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                         withAnimation(.easeOut(duration: 0.3)) {
                             feedbackMessage = ""
                         }
                     }
                 }
             }
         }
         .padding(8)
         .background(Color.gray.opacity(0.05))
         .cornerRadius(8)
     }
    private func showFeedbackMessage(_ message: String) {
        withAnimation(.easeIn(duration: 0.2)) {
            feedbackMessage = message
        }
        
        // Automatikus eltűnés 3 másodperc után
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                feedbackMessage = ""
            }
        }
    }
    private var actionButtons: some View {
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
            
            // Nyomonkövetés gomb - csak folyamatban lévő munkáknál
            if work.statusText == "Folyamatban" {
                NavigationLink(destination: WorkTrackingView(work: work)) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
//                        Text("Nyomonkövetés")
//                            .font(.custom("Lexend", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(10)
                }
            }
            
            // Befejezés gomb - csak folyamatban lévő munkáknál
//            if work.statusText == "Folyamatban" {
//                Button(action: onComplete) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "checkmark.circle.fill")
//                        Text("Befejezés")
//                            .font(.custom("Lexend", size: 14))
//                    }
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    .background(Color.green)
//                    .cornerRadius(10)
//                }
//            }
            
            Spacer()
            
            // WorkCardView actionButtons részében
            Button(action: {
                onShowQRCode2()
            }) {
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
    
    // MARK: - Függvények
    
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
                    print("❌ Hiba a jelentkezések számának lekérésekor: \(error)")
                }
            }
        }
    }
    
    private func loadCompletionCode() async {
        await MainActor.run {
            isLoadingCode = true
        }
        
        do {
            let code = try await ServerAuthManager.shared.getCompletionCode(workId: work.id)
            await MainActor.run {
                self.completionCode = code
                self.isLoadingCode = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingCode = false
                print("❌ Nincs lezárási kód: \(error)")
            }
        }
    }
    
    private func generateNewCode() {
        let newCode = String(format: "%06d", Int.random(in: 100000...999999))
        
        Task {
            await MainActor.run {
                isLoadingCode = true
            }
            
            do {
                try await ServerAuthManager.shared.saveCompletionCode(
                    workId: work.id,
                    completionCode: newCode
                )
                await MainActor.run {
                    self.completionCode = newCode
                    self.isLoadingCode = false
                    showFeedbackMessage("✓ Új kód generálva: \(newCode)")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCode = false
                    showFeedbackMessage("✕ Hiba a kód mentésekor: \(error.localizedDescription)")
                }
            }
        }
    }
    
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
    @State private var completionCode = ""
    @State private var isLoadingCode = false
    @State private var feedbackMessage = ""

    init(work: WorkData) {
        self.work = work
    }
    
    var body: some View {
        ZStack {
            // Háttér
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
                VStack(spacing: 30) {
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
                        
                        Text("Munka adatai")
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                        }) {
                            Image(systemName: "info")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.DesignSystem.fokekszin)
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    ScrollView {
                        
                        
                        
                        Text("Munka QR Kódja")
                            .font(.custom("Jellee", size: 22))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        
                        
                        
                        VStack(spacing: 20) {
                            
                            
                            
                            if let qrCodeImage = generateQRCode(from: work.id.uuidString) {
                                
                                if work.statusText == "Folyamatban" {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                                            .frame(width: 200, height: 200)
                                        
                                        ZStack {
                                            Image(uiImage: qrCodeImage)
                                                .interpolation(.none)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 200, height: 200)
                                                .padding()
                                                .cornerRadius(20)
                                                .opacity(0.2)
                                            
                                            Text("A munka éppen folyamatban van. Amint a munkát a munkavállalóval sikeresen lezártátok, a munka QR kódja ismét megjelenik.")
                                                .multilineTextAlignment(.center)
                                                .font(.custom("Lexend", size: 12))
                                                .padding(10)
                                                .background(Color.gray.opacity(0.5))
                                                .cornerRadius(15)
                                            
                                                .padding()
                                                .foregroundColor(.DesignSystem.bordosszin) // vagy más szín, ha kell
                                        }
                                        .frame(width: 200, height: 200)
                                    }
                                }
                                else{
                                    
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 3)
                                            .frame(width: 200, height: 200)
                                        
                                        ZStack {
                                            Image(uiImage: qrCodeImage)
                                                .interpolation(.none)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 200, height: 200)
                                                .padding()
                                                .cornerRadius(15)
     
                                        }
                                        .frame(width: 200, height: 200)
                                    }
                                }
                                
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
                            
                            if work.statusText == "Folyamatban" {
                                
                            }
                            else{
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
                        // A felirat külön
                        Text("Munka adatai")
                            .font(.custom("Jellee", size: 22))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // A tartalom
                        VStack(alignment: .leading, spacing: 16) {
                            InfoRowQR(icon: "briefcase", title: "Munka neve", value: work.title)
                            InfoRowQR(icon: "person", title: "Munkáltató", value: work.employerName)
                            InfoRowQR(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
                            InfoRowQRPayment(icon: "creditcard", title: "Fizetés típus", value: work.paymentType)
                            
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
                        
                        if work.statusText == "Folyamatban" {
                            
                        }
                        else {
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
                                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                            .contentTransition(.symbolEffect(.replace))
                                            .font(.custom(isCopied ? "Jellee" : "Lexend", size: 20))
                                        Text(isCopied ? "" : "ID másolása")
                                            .font(.custom("Lexend", size: 20))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(isCopied ? Color.green : Color.blue)
                                    .cornerRadius(20)
                                }
                                
                            }
                            .padding(.horizontal, 20)
                        }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarBackButtonHidden(true)
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
    
    private func generateCompletionCode() {
        let newCode = String(format: "%06d", Int.random(in: 100000...999999))
        
        Task {
            await MainActor.run {
                isLoadingCode = true
            }
            
            do {
                try await ServerAuthManager.shared.saveCompletionCode(
                    workId: work.id,
                    completionCode: newCode
                )
                
                await MainActor.run {
                    self.completionCode = newCode
                    self.isLoadingCode = false
                    showFeedbackMessage("✓ Lezárási kód generálva: \(newCode)")
                    
                    // DEBUG információ
                    print("🔐 LEZÁRÁSI KÓD GENERÁLVA:")
                    print("   - Munka ID: \(work.id)")
                    print("   - Munka cím: \(work.title)")
                    print("   - Lezárási kód: \(newCode)")
                    print("   - Idő: \(Date())")
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCode = false
                    showFeedbackMessage("✕ Hiba a kód mentésekor: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showFeedbackMessage(_ message: String) {
        withAnimation(.easeIn(duration: 0.2)) {
            feedbackMessage = message
        }
        
        // Automatikus eltűnés 3 másodperc után
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                feedbackMessage = ""
            }
        }
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
                .foregroundColor(.DesignSystem.fenyozold)
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
            
                VStack(alignment: .leading, spacing: 20) {
                    // Header
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
                        
                        Text("\(work.title) adatai")
                            .font(.custom("Lexend", size: 18))
                            .foregroundColor(.DesignSystem.fokekszin)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                        }) {
                            Image(systemName: "info")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.DesignSystem.fokekszin)
                                .padding(8)
                                .background(Color.DesignSystem.fokekszin.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    ScrollView {

                    VStack(alignment: .leading, spacing: 8) {
                        Text(work.title)
                            .font(.custom("Jellee", size: 28))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
//                        Text("Létrehozva: \(formattedDate(work.createdAt))")
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

            .sheet(isPresented: $showingStatusUpdate) {
                StatusUpdateView(
                    currentStatus: work.statusText,
                    onStatusUpdate: { newStatus in
                        updateWorkStatus(newStatus)
                    },
                    onDelete: {
                        deleteWork()
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
        .navigationBarBackButtonHidden(true)

    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Állapot")
                .font(.custom("Jellee", size: 20))
                .foregroundColor(.DesignSystem.fokekszin)
                .padding(.horizontal)
            
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
                .padding(.horizontal)

            
            HStack {
                HStack {
                    Text("\(Int(work.wage)) Ft")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fenyozold)
                    
                    Spacer()
                    Text(work.paymentType)
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fenyozold)
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
                .padding(.horizontal)

            
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
                .padding(.horizontal)

            
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
                .padding(.horizontal)

            
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
//                  HStack(spacing: 12) {
//                      Image(systemName: Workend ? "checkmark.circle" : // "forward.end.circle")
//                          .contentTransition(.symbolEffect(.replace))
//                          .font(.custom("Jellee", size: 20))
//
//
//                      Text(Workend ? "Lezárva" : "Munka befejezése")
//                          .font(.custom("Lexend", size: 20))
//                  }
//                  .foregroundColor(.white)
//                  .frame(maxWidth: .infinity)
//                  .padding(.vertical, 16)
//                  .background(Workend ? Color.green : Color.blue)
//                  .cornerRadius(20)
            }
            
            Button(action: {
                showingDeleteAlert = true

            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Munka törlése")
                        .font(.custom("Lexend", size: 20))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background( Color.red)
                .cornerRadius(20)
            }

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
    
    public func deleteWork() {
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

struct StatusUpdateView: View {
    let currentStatus: String
    let onStatusUpdate: (String) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus = ""
    @State private var showingDeleteAlert = false

    let statusOptions = ["Publikálva", "Nem kezdődött el", "Folyamatban", "Ellenőrzésre vár", "Befejezve"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
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
                
                Text("Munkaállapot kezelése")
                    .font(.custom("Lexend", size: 18))
                    .foregroundColor(.DesignSystem.fokekszin)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    if !selectedStatus.isEmpty {
                        onStatusUpdate(selectedStatus)
                        dismiss()
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .padding(8)
                        .background(Color.DesignSystem.fokekszin.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(selectedStatus.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .background(Color.white)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Jelenlegi állapot szekció
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jelenlegi állapot")
                            .font(.custom("Jellee", size: 20))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        Text(selectedStatus)
                            .font(.custom("Lexend", size: UIFontMetrics.default.scaledValue(for: 16)))
                            .foregroundColor(.primary)
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
                    }
                    .padding(.horizontal, 4)
                    
                    // Új állapot kiválasztása szekció
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Új állapot kiválasztása")
                            .font(.custom("Jellee", size: 20))
                            .foregroundColor(.DesignSystem.fokekszin)
                        
                        VStack {
                            Picker("Állapot", selection: $selectedStatus) {
                                ForEach(statusOptions, id: \.self) { status in
                                    Text(status).tag(status)
                                }
                            }
                            .pickerStyle(.wheel)
                            .font(.custom("Jellee", size: 16))
                        }
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
                    }
                    .padding(.horizontal, 4)
                    
                    Button(action: {
                        if !selectedStatus.isEmpty {
                            onStatusUpdate(selectedStatus)
                            dismiss()
                        }

                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Új státusz mentése")
                                .font(.custom("Lexend", size: 20))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background( Color.yellow)
                        .cornerRadius(20)
                    }
                    .padding(.bottom, -10)

                    Button(action: {
                        showingDeleteAlert = true

                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Munka törlése")
                                .font(.custom("Lexend", size: 20))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background( Color.red)
                        .cornerRadius(20)
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true) // Biztonsági okokból elrejtjük a system navigation bárt
        .onAppear {
            selectedStatus = currentStatus
        }
        .alert("Munka törlése", isPresented: $showingDeleteAlert) {
            Button("Mégse", role: .cancel) { }
            Button("Törlés", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Biztosan törölni szeretnéd ezt a munkát?")
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
            VStack{
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
                    
                    Text("Jelentkezéseid")
                        .font(.custom("Lexend", size: 18))
                        .foregroundColor(.DesignSystem.fokekszin)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                    }) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16))
                            .foregroundStyle( Color.DesignSystem.fokekszin )
                            .padding(8)
                            .background(Color.DesignSystem.fokekszin.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                Group {
                    if applications.isEmpty {
                        emptyStateView
                    } else {
                        applicationsListView
                    }
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

// WorkTrackingView.swift - Új fájl
import SwiftUI

struct WorkTrackingView: View {
    let work: WorkData
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var userManager = UserManager.shared
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isWorkStarted = false
    @State private var isWorkPaused = false
    @State private var totalPausedTime: TimeInterval = 0
    @State private var pauseStartTime: Date?
    @State private var workStartTime: Date?

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 24) {
                    // Header
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
                        VStack(spacing: 4) {
                            Text("'\(work.title)'")
                                .font(.custom("Lexend", size: 20))
                                .foregroundColor(.DesignSystem.fokekszin)
                                .fontWeight(.bold)
                                
                            Text("Nyomonkövetése")
                                .font(.custom("Lexend", size: 14))
                                .foregroundColor(.DesignSystem.descriptions)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        
                        // Üres hely a bal oldali gomb miatt
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 32, height: 32)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 24) {

                            timerSection
                                .padding(.top, 15)
                            
                            actionButtons

                            VStack(spacing: 16) {
                                
                                
                                Text("Fizetési összegzés")
                                    .font(.custom("Jellee", size: 22))
                                    .foregroundColor(.DesignSystem.fokekszin)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.top, 20)
                                    .padding(.vertical, -20)
                                
                            }
                            paymentInfoCard

                            
                            workInfoCard

                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startTracking()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var workInfoCard: some View {
        VStack(spacing: 20) {
            // Header with status
            headerWithStatus
            
            Divider()
                .background(Color.DesignSystem.fokekszin.opacity(0.2))
            
            // Work details in grid
            workDetailsGrid
            
            // Location
            locationView
            
            // Skills
            skillsView
        }
        .padding(24)
        .background(cardBackground)
    }
    
    private var headerWithStatus: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(work.title)
                    .font(.custom("Jellee", size: 24))
                    .foregroundColor(.DesignSystem.fokekszin)
                
                Text(work.employerName)
                    .font(.custom("Lexend", size: 16))
                    .foregroundColor(.DesignSystem.descriptions)
            }
            
            Spacer()
            
            StatusBadge(status: work.statusText)
                .scaleEffect(1.1)
        }
    }
    
    private var workDetailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            InfoItem(icon: "dollarsign.circle", title: "Fizetés", value: "\(Int(work.wage)) Ft")
            InfoItem(icon: "creditcard", title: "Fizetés típus", value: work.paymentType)
        }
    }
    
    private var locationView: some View {
        Group {
            if !work.location.isEmpty {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.DesignSystem.fokekszin)
                        .font(.system(size: 18))
                    Text(work.location)
                        .font(.custom("Lexend", size: 15))
                        .foregroundColor(.DesignSystem.descriptions)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var skillsView: some View {
        Group {
            if !work.skills.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Szükséges készségek")
                        .font(.custom("Lexend", size: 16))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    skillsScrollView
                }
            }
        }
    }
    
    private var skillsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(work.skills, id: \.self) { skill in
                    Text(skill)
                        .font(.custom("Lexend", size: 13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.fokekszin.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.DesignSystem.fokekszin.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(.DesignSystem.fokekszin)
                }
            }
        }
    }
    
    // Helper properties
    private var statusColor: Color {
        if !isWorkStarted { return .gray }
        return isWorkPaused ? .orange : .DesignSystem.fenyozold
    }
    
    private var statusText: String {
        if !isWorkStarted { return "Nem indult el" }
        return isWorkPaused ? "Szünetel" : "Folyamatban"
    }
    
    private var timerSection: some View {
        VStack(spacing: 24) {
            // Circular Timer with Continuous Progress Line
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.DesignSystem.fokekszin.opacity(0.1), lineWidth: 12)
                    .frame(width: 220, height: 220)
                
                // Completed minutes - full circles with different colors
                ForEach(0..<Int(elapsedTime / 60), id: \.self) { minuteIndex in
                    Circle()
                        .trim(from: 0, to: 1.0)
                        .stroke(
                            colorForMinute(minuteIndex: minuteIndex),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                }
                
                // Current minute progress - the moving line
                Circle()
                    .trim(from: 0, to: CGFloat(elapsedTime.truncatingRemainder(dividingBy: 60)) / 60.0)
                    .stroke(isWorkPaused ? .orange : colorForMinute(minuteIndex: Int(elapsedTime / 60)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: elapsedTime)
                
                // Timer text
                VStack(spacing: 8) {
                    Text(formattedTime(elapsedTime))
                        .font(.custom("Lexend", size: 36))
                        .foregroundColor(isWorkPaused ? .orange : colorForMinute(minuteIndex: Int(elapsedTime / 60)))
                        .monospacedDigit()
                    
                    // Status indicator with pulse animation
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isWorkStarted ? (isWorkPaused ? 1 : 1.2) : 1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isWorkStarted && !isWorkPaused)
                        
                        Text(statusText)
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(statusColor)
                    }
                }
            }
            
            // Minute progress indicators
            minuteProgressView
            
            // Time info in modern pill style
            HStack(spacing: 16) {
                timeInfoPill(title: "Kezdés", time: workStartTime != nil ? formattedTime(workStartTime!) : "--:--")
                
                timeInfoPill(title: "Jelenlegi", time: formattedCurrentTime())
            }
        }
    }
    
    private var minuteProgressView: some View {
        HStack(spacing: 4) {
            ForEach(0..<6, id: \.self) { minute in
                RoundedRectangle(cornerRadius: 2)
                    .fill(minute < Int(elapsedTime / 60) ? colorForMinute(minuteIndex: minute) : Color.DesignSystem.fokekszin.opacity(0.2))
                    .frame(width: 20, height: 4)
                    .scaleEffect(minute == Int(elapsedTime / 60) ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: elapsedTime)
            }
        }
    }
    
    private func colorForMinute(minuteIndex: Int) -> Color {
        let colors: [Color] = [
            Color.DesignSystem.fenyozold,
            Color.red,
            Color.indigo,
            Color.blue,
            Color.green
        ]
        
        return colors[minuteIndex % colors.count]
    }
    
    private func timeInfoPill(title: String, time: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.custom("Lexend", size: 12))
                .foregroundColor(.DesignSystem.descriptions)
            
            Text(time)
                .font(.custom("Lexend", size: 14))
                .foregroundColor(.DesignSystem.fokekszin)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.DesignSystem.fokekszin.opacity(0.08))
        .cornerRadius(12)
    }
    

    
    private var statusColor2: Color {
        if !isWorkStarted { return .gray }
        return isWorkPaused ? .orange : .DesignSystem.fenyozold
    }
    
    private var statusText2: String {
        if !isWorkStarted { return "Nem indult el" }
        return isWorkPaused ? "Szünetel" : "Folyamatban"
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if !isWorkStarted {
                startButton
            } else {
                HStack(spacing: 12) {
                    pauseResumeButton
                    stopButton
                }
            }
            
            paymentButton
        }
    }
    
    private var startButton: some View {
        Button(action: {
            startWorkTimer()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                Text("Időzítő Indítása")
                    .font(.custom("Lexend", size: 18))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color.DesignSystem.fenyozold, Color.DesignSystem.fokekszin],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .DesignSystem.fenyozold.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var pauseResumeButton: some View {
        Button(action: {
            togglePause()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isWorkPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.title3)
                Text(isWorkPaused ? "Folytatás" : "Szünet")
                    .font(.custom("Lexend", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isWorkPaused ? Color.DesignSystem.fenyozold : Color.orange)
            .cornerRadius(16)
            .shadow(color: (isWorkPaused ? Color.DesignSystem.fenyozold : Color.orange).opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private var stopButton: some View {
        Button(action: {
            stopWorkTimer()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "stop.circle.fill")
                    .font(.title3)
                Text("Leállítás")
                    .font(.custom("Lexend", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.orange],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(16)
            .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private var paymentButton: some View {
        Group {
            let paymentType = work.paymentType.lowercased()
            let isCashPayment = paymentType == "készpénz" || paymentType.contains("készpénz")
            
            if !isCashPayment {
                // Nem készpénzes fizetés - megjelenik a gomb
                Button(action: {
                    processPayment()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .font(.title3)
                        
                        Text("Fizetés Kezdeményezése")
                            .font(.custom("Lexend", size: 18))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.DesignSystem.fokekszin, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .DesignSystem.fokekszin.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(!isWorkStarted)
                .opacity(isWorkStarted ? 1.0 : 0.6)
            } else {
                // Készpénz esetén információs üzenet
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Készpénzes fizetés")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    Text("A fizetést készpénzben kell rendezni a munka befejezésekor.")
                        .font(.custom("Lexend", size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    private var paymentInfoCard: some View {
        VStack(spacing: 20) {
            
            VStack(spacing: 16) {
                paymentRow(title: "Összes idő:", value: formattedTime(elapsedTime), isHighlighted: false)
                paymentRow(title: "Órabér:", value: "\(Int(work.wage)) Ft/óra", isHighlighted: false)
                
                Divider()
                    .background(Color.DesignSystem.fokekszin.opacity(0.2))
                
                paymentRow(title: "Becsült kereset:", value: "\(Int(calculateEarnings())) Ft", isHighlighted: true)
            }
        }
        .padding(24)
        .background(cardBackground)
    }
    
    private func headerWithIcon(title: String, icon: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("Jellee", size: 22))
                .foregroundColor(.DesignSystem.fokekszin)
            
            Spacer()
            
            Image(systemName: icon)
                .foregroundColor(.DesignSystem.fenyozold)
        }
    }
    
    private func paymentRow(title: String, value: String, isHighlighted: Bool) -> some View {
        HStack {
            Text(title)
                .font(.custom("Lexend", size: isHighlighted ? 16 : 14))
                .foregroundColor(isHighlighted ? .DesignSystem.fokekszin : .DesignSystem.descriptions)
            
            Spacer()
            
            Text(value)
                .font(.custom(isHighlighted ? "Lexend" : "Jellee", size: isHighlighted ? 20 : 14))
                .foregroundColor(isHighlighted ? .DesignSystem.fenyozold : .DesignSystem.fokekszin)
                .fontWeight(isHighlighted ? .bold : .semibold)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.DesignSystem.fokekszin.opacity(0.15), lineWidth: 1)
            )
    }
    

    
    // MARK: - Időzítő funkciók
    
    private func startTracking() {
        // Ha a munka már folyamatban van, automatikusan indítsuk az időzítőt
        if work.statusText == "Folyamatban" && !isWorkStarted {
            startWorkTimer()
        }
    }
    
    private func startWorkTimer() {
        isWorkStarted = true
        isWorkPaused = false
        workStartTime = Date()
        startTimer()
    }
    
    private func stopWorkTimer() {
        isWorkStarted = false
        isWorkPaused = false
        stopTimer()
        elapsedTime = 0
        totalPausedTime = 0
        pauseStartTime = nil
        workStartTime = nil
    }
    
    private func togglePause() {
        if isWorkPaused {
            // Folytatás
            if let pauseStart = pauseStartTime {
                totalPausedTime += Date().timeIntervalSince(pauseStart)
                pauseStartTime = nil
            }
            isWorkPaused = false
            startTimer()
        } else {
            // Szünet
            isWorkPaused = true
            pauseStartTime = Date()
            stopTimer()
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if !isWorkPaused {
                elapsedTime += 1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func calculateEarnings() -> Double {
        let totalWorkTime = elapsedTime - totalPausedTime
        let totalHours = totalWorkTime / 3600
        return totalHours * Double(work.wage)
    }
    
    private func processPayment() {
        // Fizetés szimuláció
        let earnings = calculateEarnings()
        print("💰 Fizetés kezdeményezve: \(Int(earnings)) Ft")
        
        // Itt később implementálhatod a valós fizetési integrációt
    }
    
    // MARK: - Segéd függvények
    
    private func formattedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formattedCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

#Preview {
    WorkTrackingView(work: WorkData.mockWork)
}

// WorkTimerManager.swift - Valós idejű időzítő kezelés
import Foundation
import Combine

class WorkTimerManager: ObservableObject {
    static let shared = WorkTimerManager()
    
    @Published var activeWorkTimers: [UUID: WorkTimer] = [:]
    
    struct WorkTimer {
        let workId: UUID
        var elapsedTime: TimeInterval
        var isRunning: Bool
        var lastUpdate: Date
    }
    
    func startTimer(for workId: UUID) {
        activeWorkTimers[workId] = WorkTimer(
            workId: workId,
            elapsedTime: 0,
            isRunning: true,
            lastUpdate: Date()
        )
    }
    
    func pauseTimer(for workId: UUID) {
        if var timer = activeWorkTimers[workId] {
            timer.isRunning = false
            activeWorkTimers[workId] = timer
        }
    }
    
    func resumeTimer(for workId: UUID) {
        if var timer = activeWorkTimers[workId] {
            timer.isRunning = true
            timer.lastUpdate = Date()
            activeWorkTimers[workId] = timer
        }
    }
    
    func stopTimer(for workId: UUID) {
        activeWorkTimers.removeValue(forKey: workId)
    }
    
    func getElapsedTime(for workId: UUID) -> TimeInterval {
        guard let timer = activeWorkTimers[workId] else { return 0 }
        
        if timer.isRunning {
            return timer.elapsedTime + Date().timeIntervalSince(timer.lastUpdate)
        } else {
            return timer.elapsedTime
        }
    }
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
            paymentType: "Bankkártya",
            statusText: "Folyamatban",
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

// MARK: - Preview for WorkApplicationsView
#Preview {
    WorkApplicationsView(
        work: WorkData.mockWork,
        applications: [
            WorkApplication(
                id: "1",
                workId: "232323",
                applicantId: "23222",
                applicantName: "John Doe",
                applicationDate: "2023-10-01T10:00:00Z",
                status: .pending
            ),
            WorkApplication(
                id: "2",
                workId: "UUID()",
                applicantId: "UUID()",
                applicantName: "Jane Smith",
                applicationDate: "2023-10-01T11:30:00Z",
                status: .accepted
            ),
            WorkApplication(
                id: "3",
                workId: "UUID()",
                applicantId: "UUID()",
                applicantName: "Bob Johnson",
                applicationDate: "2023-10-01T12:15:00Z",
                status: .rejected
            )
        ],
        onApplicationAction: { action in
            print("Application action: \(action)")
        }
    )
}


#Preview("Empty State") {
    WorkApplicationsView(
        work: WorkData.mockWork,
        applications: [],
        onApplicationAction: { action in
            print("Application action: \(action)")
        }
    )
}

#Preview {
    WorkQRCodeView(work: WorkData.mockWork)
}
#Preview {
    WorkCompletionView(work: WorkData.mockWork, completionCode: "123321", onComplete: { _ in })
}


#Preview {
    WorkDetailView(work: WorkData.mockWork, onStatusUpdate: {})
}

#Preview {
    StatusUpdateView(currentStatus: "Publikálva", onStatusUpdate: {_ in }, onDelete: {})
}

