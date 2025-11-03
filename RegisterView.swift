    import SwiftUI
    import DesignSystem
    import Combine
    // MARK: - Register View Model
    class RegisterViewModel: ObservableObject {
        @Published var name = ""
        @Published var username = ""
        @Published var email = ""
        @Published var password = ""
        @Published var confirmPassword = ""
        @Published var isLoading = false
        @Published var error: String? = nil
        @Published var isRegistered = false
        @Published var acceptedTerms = false
        @Published var acceptedAge = false
        @Published var age = "" // Új életkor mező
        
        private let userManager = UserManager.shared
        
        var isValid: Bool {
            !name.isEmpty &&
            !username.isEmpty &&
            !email.isEmpty &&
            !password.isEmpty &&
            password == confirmPassword &&
            acceptedTerms &&
            acceptedAge &&
            !age.isEmpty && // Életkor ellenőrzése
            Int(age) != nil // Ellenőrizzük, hogy szám-e
        }
        
        func register() {
                isLoading = true
                
                guard isValid else {
                    error = "Kérünk, töltsd ki az összes mezőt helyesen"
                    isLoading = false
                    return
                }
                
                guard let ageInt = Int(age) else {
                    error = "Érvényes életkort adj meg"
                    isLoading = false
                    return
                }
                
                guard ageInt >= 16 else {
                    error = "A regisztrációhoz legalább 16 évesnek kell lenned"
                    isLoading = false
                    return
                }
                
                // Lokális regisztráció (eredeti)
                userManager.register(name: name, email: email, username: username, password: password)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isRegistered = true
                    self.isLoading = false
                }
            }
        }

    // MARK: - Register View
struct RegisterView: View {
    @StateObject private var viewModel = RegisterViewModel()
    @StateObject private var serverAuth = ServerAuthManager.shared // Új szerver auth
    
    @Environment(\.dismiss) var dismiss
    @State private var showTerms = false
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Regisztrálj!")
                        .font(.custom("Jellee", size: 36))
                        .bold()
                        .padding(.bottom)
                    
                    VStack(spacing: 20) {
                        // Name and Age fields
                        HStack{
                            TextField("Teljes név", text: $viewModel.name)
                                .padding(10)
                                .font(.custom("Jellee", size: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                                .cornerRadius(15)
                            
                            // Életkor mező - szám billentyűzettel
                            TextField("Életkor", text: $viewModel.age)
                                .padding(10)
                                .font(.custom("Jellee", size: 16))
                                .keyboardType(.numberPad) // Csak szám billentyűzet
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                                .cornerRadius(15)
                        }
                        
                        TextField("Felhasználónév", text: $viewModel.username)
                            .padding(10)
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        // Email field
                        TextField("E-mail cím", text: $viewModel.email)
                            .font(.custom("Jellee", size: 16))
                            .padding(10)
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                        
                        // Password fields
                        SecureField("Jelszó", text: $viewModel.password)
                            .padding(10)
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                        SecureField("Jelszó megerősítése", text: $viewModel.confirmPassword)
                            .padding(10)
                            .font(.custom("Jellee", size: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 5))
                            .cornerRadius(15)
                        
                        // Terms checkboxes
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "16.circle")
                                    .font(.title2)
                                    .foregroundStyle(Color.DesignSystem.bordosszin)
                                Text("Kijelentem, hogy elmúltam legalább 16 éves.")
                                    .font(.custom("Lexend", size: 11))
                                    .foregroundColor(.DesignSystem.bordosszin)
                                    .padding(.horizontal, 10)
                                
                                Spacer()
                                
                                Toggle("", isOn: $viewModel.acceptedAge)
                                    .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.bordosszin))
                                    .labelsHidden()
                                    .frame(width: 30)
                            }
                            
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "book.pages")
                                    .font(.title2)
                                    .foregroundStyle(Color.DesignSystem.descriptions)
                                Button(action: { showTerms = true }) {
                                    Text("Elfogadom a felhasználási feltételeket és az adatvédelmi irányelveket.")
                                        .font(.custom("Lexend", size: 11))
                                        .foregroundStyle(Color.DesignSystem.descriptions)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 10)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $viewModel.acceptedTerms)
                                        .toggleStyle(SwitchToggleStyle(tint: .DesignSystem.descriptions))
                                        .labelsHidden()
                                        .frame(width: 30)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom,20)
                        
                        // Error message
                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.custom("Lexend", size: 14))
                        }
                        
                        // Register button
                        Button(action: register) {
                            if viewModel.isLoading || serverAuth.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Regisztráció")
                                    .font(.custom("Lexend", size: 20))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin.opacity(0.8), .DesignSystem.descriptions.opacity(0.8)]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        .cornerRadius(20)
                        .disabled(!viewModel.isValid || viewModel.isLoading)
                        .shadow(color: Color.DesignSystem.fokekszin, radius: 16, x: 4, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]), startPoint: .leading, endPoint: .trailing), lineWidth: 2))
                    }
                    .padding(.horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Mégse") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 17))
                    .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.DesignSystem.fokekszin, .DesignSystem.descriptions]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing))
                }
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
        .alert("Sikeres regisztráció", isPresented: $viewModel.isRegistered) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Kérlek jelentkezz be a folytatáshoz!")
        }
        .alert("Szerver hiba", isPresented: .init(
            get: { serverAuth.error != nil },
            set: { if !$0 { serverAuth.error = nil } }
        )) {
            Button("OK") { serverAuth.error = nil }
        } message: {
            Text(serverAuth.error ?? "Ismeretlen hiba")
        }
        .alert("Sikeres regisztráció", isPresented: .init(
            get: { viewModel.isRegistered || serverAuth.isAuthenticated },
            set: { _ in }
        )) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Kérlek jelentkezz be a folytatáshoz!")
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Registration Error"),
                message: Text(UserManager.shared.error?.localizedDescription ?? "Unknown error")
            )
        }
        .interactiveDismissDisabled(viewModel.isLoading)
    }
    
    private func register() {
        guard let ageInt = Int(viewModel.age) else { return }
        
        // Először próbáljuk a szerveres regisztrációt
        serverAuth.register(
            name: viewModel.name,
            email: viewModel.email,
            username: viewModel.username,
            password: viewModel.password,
            age: ageInt
        ) { success in
            if success {
                // Szerveres regisztráció sikeres
                DispatchQueue.main.async {
                    viewModel.isRegistered = true
                }
            } else {
                // Ha a szerveres regisztráció nem sikerül, akkor lokális
                viewModel.register()
            }
        }
    }
}

    // MARK: - Terms View
    struct TermsView: View {
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Group {
                            Text("Felhasználási feltételek")
                                .font(.title)
                                .bold()
                            
                            Text("Az alkalmazás használatával elfogadod az alábbi feltételeket...")
                            
                            Text("1. Általános rendelkezések")
                                .font(.headline)
                            Text("Az alkalmazás használata során...")
                            
                            Text("2. Adatvédelem")
                                .font(.headline)
                            Text("Személyes adataid kezelése...")
                        }
                        .padding(.bottom, 8)
                    }
                    .padding()
                }
                .navigationBarItems(trailing: Button("Bezárás") {
                    dismiss()
                })
            }
        }
    }

    // MARK: - Preview Provider
    struct RegisterView_Previews: PreviewProvider {
        static var previews: some View {
            RegisterView()
        }
    }
