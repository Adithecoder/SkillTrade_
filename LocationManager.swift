//
//  LocationManager.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import DesignSystem



// LocationManager a GPS helymeghatározáshoz
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // JAVÍTVA: Megfelelő completion handler tárolás
    private var pendingCompletion: ((CLLocation?, Error?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // Existing API: parameterless request that updates @Published currentLocation
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    // JAVÍTVA: Completion-based request - most már helyesen tárolja a completion handler-t
    func requestLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
        // Tárold el a completion handler-t
        pendingCompletion = completion
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Engedélyek ellenőrzése
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "LocationServicesDisabled", code: 1, userInfo: [NSLocalizedDescriptionKey: "Helyszolgáltatások nincsenek engedélyezve"]))
                self.pendingCompletion = nil
            }
            return
        }
        
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "LocationAccessDenied", code: 2, userInfo: [NSLocalizedDescriptionKey: "Helymeghatározás nincs engedélyezve"]))
                self.pendingCompletion = nil
            }
            return
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        @unknown default:
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "LocationUnknownError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ismeretlen engedélyezési állapot"]))
                self.pendingCompletion = nil
            }
        }
    }

    // CLLocationManagerDelegate - JAVÍTVA
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        // Update published property
        currentLocation = last

        // Fulfill completion if requested that way
        if let completion = pendingCompletion {
            completion(last, nil)
            pendingCompletion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        
        // Update published property
        currentLocation = nil

        // Fulfill completion if requested that way
        if let completion = pendingCompletion {
            completion(nil, error)
            pendingCompletion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("Authorization status changed to: \(authorizationStatus.rawValue)")

        // If we were waiting for authorization for a completion-based request
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // proceed with the pending request
            if pendingCompletion != nil {
                manager.requestLocation()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            // Permission denied
            if let completion = pendingCompletion {
                let error = NSError(
                    domain: "Location",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Helymeghatározás nem engedélyezett"]
                )
                completion(nil, error)
                pendingCompletion = nil
            }
        } else if authorizationStatus == .notDetermined {
            // do nothing, waiting for user
        }
    }
}

// MapLocationPicker a térképes helyválasztáshoz
struct MapLocationPicker: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedAddress: String

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402), // Budapest
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var annotation: IdentifiablePointAnnotation?

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, annotationItems: annotation != nil ? [annotation!] : []) { annotation in
                    MapMarker(coordinate: annotation.coordinate, tint: .red)
                }
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            // Convert tap to current center (simplified)
                            let location = CLLocationCoordinate2D(
                                latitude: region.center.latitude,
                                longitude: region.center.longitude
                            )
                            selectedCoordinate = location
                            annotation = IdentifiablePointAnnotation(coordinate: location)
                            reverseGeocode(location: location)
                        }
                )

                VStack {
                    Button(action: {
                        if let coordinate = selectedCoordinate {
                            selectedCoordinate = coordinate
                            reverseGeocode(location: coordinate)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text(NSLocalizedString("select_this_location", comment: ""))
                            .font(.custom("OrelegaOne-Regular", size: 18))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.DesignSystem.fokekszin)
                            .cornerRadius(10)
                    }
                    .padding()
                    .disabled(selectedCoordinate == nil)
                }
            }
            .navigationTitle(NSLocalizedString("select_location", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        geocoder.reverseGeocodeLocation(clLocation) { placemarks, _ in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    selectedAddress = formatAddress(from: placemark)
                }
            }
        }
    }

    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }

        return components.joined(separator: ", ")
    }
}

struct IdentifiablePointAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
