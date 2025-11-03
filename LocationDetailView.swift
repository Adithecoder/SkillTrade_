//
//  LocationDetailView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/30/25.
//
import SwiftUI
import MapKit
import DesignSystem

struct LocationDetailView: View {
    let location: String
    @Environment(\.dismiss) var dismiss
    @State private var region: MKCoordinateRegion
    @State private var annotationItems: [IdentifiablePointAnnotation] = []
    @State private var isLoading = true
    @State private var showError = false
    
    init(location: String) {
        self.location = location
        // Alapértelmezett régió (Budapest)
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Valódi MapKit térkép
                ZStack {
                    Map(coordinateRegion: $region, annotationItems: annotationItems) { annotation in
                        MapMarker(coordinate: annotation.coordinate, tint: .DesignSystem.fokekszin)
                    }
                    .cornerRadius(15)
                    .frame(height: 200)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.DesignSystem.fokekszin)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    geocodeLocation()
                }
                
                // Helyadat részletei
                VStack(alignment: .leading, spacing: 12) {
                    Text("Helyszín részletei")
                        .font(.custom("Jellee", size: 24))
                        .foregroundColor(.DesignSystem.fokekszin)
                    
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.DesignSystem.fokekszin)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location)
                                .font(.custom("Lexend", size: 18))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                            
                            if !annotationItems.isEmpty {
                                Text("\(region.center.latitude, specifier: "%.4f"), \(region.center.longitude, specifier: "%.4f")")
                                    .font(.custom("Lexend", size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.DesignSystem.fokekszin.opacity(0.1))
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.DesignSystem.fokekszin, lineWidth: 2)
                    )
                }
                .padding(.horizontal)
                
                if showError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Nem sikerült megjeleníteni a térképet")
                            .font(.custom("Lexend", size: 16))
                            .foregroundColor(.black)
                        
                        Text("A helyadat: \(location)")
                            .font(.custom("Lexend", size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Bezárás gomb
                Button(action: { dismiss() }) {
                    Text("Bezárás")
                        .font(.custom("Jellee", size: 18))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.DesignSystem.fokekszin)
                        .cornerRadius(15)
                }
                .padding(.horizontal)
            }
            .padding(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vissza") {
                        dismiss()
                    }
                    .font(.custom("Lexend", size: 20))
                    .foregroundColor(.DesignSystem.fokekszin)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !annotationItems.isEmpty {
                        Button(action: openInMaps) {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                .foregroundColor(.DesignSystem.fokekszin)
                        }
                    }
                }
            }
        }
    }
    
    private func geocodeLocation() {
        isLoading = true
        showError = false
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("Geocoding error: \(error.localizedDescription)")
                    showError = true
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    showError = true
                    return
                }
                
                // Frissítsd a térkép régiót
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                
                // Add hozzá az annotációt
                annotationItems = [IdentifiablePointAnnotation(coordinate: location.coordinate)]
            }
        }
    }
    
    private func openInMaps() {
        guard let coordinate = annotationItems.first?.coordinate else { return }
        
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}

#if DEBUG
struct LocationDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Rövid helynév
            LocationDetailView(location: "Budapest, V. kerület")
                .previewDisplayName("Rövid helynév")
            
            // Hosszú helynév
            LocationDetailView(location: "1234 Budapest, Példa utca 42., 2. emelet, 5. ajtó, Magyarország")
                .previewDisplayName("Hosszú helynév")
            
            // Külföldi cím
            LocationDetailView(location: "Vienna, Austria - Hauptstraße 123")
                .previewDisplayName("Külföldi cím")
            
            // Dark mode
            LocationDetailView(location: "Budapest, Margit-sziget")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}

// Frissített ModernServiceCard2 preview a helyadattal
struct ModernServiceCard2_WithLocation_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Szolgáltatás rövid hellyel
            ModernServiceCard2(
                service: Service(
                    advertiser: User.preview,
                    name: "iOS Fejlesztés",
                    description: "Professzionális iOS alkalmazás fejlesztés SwiftUI használatával",
                    rating: 4.8,
                    reviewCount: 23,
                    price: 50000,
                    location: "Budapest",
                    skills: ["Swift", "SwiftUI", "iOS"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .technology,
                    serviceOption: .free
                ),
                servicePrice: .constant(50000)
            )
            .previewDisplayName("Rövid hely")
            
            // Szolgáltatás hosszú hellyel
            ModernServiceCard2(
                service: Service(
                    advertiser: User.preview,
                    name: "Webdesign",
                    description: "Modern reszponzív webdesign készítése",
                    rating: 4.5,
                    reviewCount: 15,
                    price: 35000,
                    location: "1234 Budapest, Nagyon Hosszú Utca Név 123. 2. emelet 5. ajtó, Magyarország",
                    skills: ["HTML", "CSS", "JavaScript"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .technology,
                    serviceOption: .premium
                ),
                servicePrice: .constant(35000)
            )
            .previewDisplayName("Hosszú hely")
            
            // Dark mode
            ModernServiceCard2(
                service: Service(
                    advertiser: User.preview,
                    name: "Tanácsadás",
                    description: "Üzleti tanácsadás és stratégiai tervezés",
                    rating: 4.9,
                    reviewCount: 8,
                    price: 75000,
                    location: "Debrecen, Egyetem tér 1.",
                    skills: ["Üzleti stratégia", "Marketing"],
                    mediaURLs: [],
                    availability: ServiceAvailability(serviceId: UUID()),
                    typeofService: .business,
                    serviceOption: .free
                ),
                servicePrice: .constant(75000)
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}

// Teljes SearchView preview a helyadatokkal
struct SearchView2_LocationPreview: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SearchView2(initialSearchText: "")
                .environmentObject(UserManager.shared)
        }
    }
}
#endif
