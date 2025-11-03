//
//  LocationPickerView.swift
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/25/25.
//


//
//  LocationPickerView.swift
//  SocialM
//
//  Created by Czeglédi Ádi on 10/21/25.
//

//   import SwiftUI
//   import Combine
//   import MapKit
//   import CoreLocation
//
//   struct LocationPickerView: View {
//       @Binding var selectedLocation: String?
//       @Binding var isPresented: Bool
//
//       @State private var isFetchingLocation = false
//       @State private var searchText = ""
//       @State private var searchResults: [MKMapItem] = []
//       @State private var isSearching = false
//
//       @StateObject private var locationManager = LocationManager()
//
//       var body: some View {
//           NavigationView {
//               VStack(spacing: 0) {
//                   // Fejléc
//                   Text("Hely hozzáadása")
//                       .font(.custom("Jellee", size: 18))
//                       .fontWeight(.semibold)
//                       .padding(.bottom, 20)
//
//                   if isFetchingLocation {
//                       locationLoadingView
//                   } else {
//                       locationOptionsView
//                   }
//
//                   // Keresőmező
//                   VStack(spacing: 12) {
//                       HStack {
//                           Image(systemName: "magnifyingglass.circle.fill")
//                               .resizable()
//                               .scaledToFit()
//                               .frame(maxHeight: 30)
//                               .foregroundStyle(LinearGradient(gradient: Gradient(colors: [.indigo, //   .blue]), startPoint: .leading, endPoint: .trailing))
//                               .symbolEffect(.bounce.down.wholeSymbol, options: .nonRepeating)
//                               .padding(.horizontal,5)
//
//                           TextField("Keresés helyre...", text: $searchText)
//                               .font(.custom("Jellee", size: 16))
//                               .onChange(of: searchText) { newValue in
//                                   performSearch(query: newValue)
//                               }
//                       }
//                       .padding()
//                       .overlay(
//                           RoundedRectangle(cornerRadius: 20)
//                               .stroke(LinearGradient(gradient: Gradient(colors: [.indigo, .blue]), //   startPoint: .leading, endPoint: .trailing), lineWidth: 6)
//                       )
//                       .background(Color(.indigo.opacity(0.1)))
//                       .cornerRadius(20)
//                       .padding(.horizontal)
//
//                       // Keresési eredmények
//                       if !searchResults.isEmpty {
//                           List {
//                               ForEach(searchResults, id: \.self) { mapItem in
//                                   Button(action: {
//                                       selectLocation(mapItem)
//                                   }) {
//                                       VStack(alignment: .leading) {
//                                           Text(mapItem.name ?? "Ismeretlen hely")
//                                               .font(.custom("Lexend", size: 18))
//                                               .foregroundStyle(.indigo)
//                                           Text(mapItem.placemark.title ?? "")
//                                               .font(.custom("Jellee", size:14))
//                                               .foregroundColor(.gray)
//                                       }
//                                   }
//                               }
//                           }
//                           .frame(height: 120)
//                       } else if isSearching {
//                           ProgressView()
//                               .padding()
//                       }
//                   }
//
//                   Spacer()
//
//                   // Gombok
//                   VStack(spacing: 12) {
//                       Button("Hely hozzáadása") {
//                           isPresented = false
//                       }
//                       .font(.custom("Jellee", size: 16))
//                       .fontWeight(.semibold)
//                       .foregroundColor(.white)
//                       .frame(maxWidth: .infinity)
//                       .padding()
//                       .background(selectedLocation != nil ? Color.indigo : Color.gray)
//                       .cornerRadius(15)
//                       .disabled(selectedLocation == nil)
//
//                       Button("Mégse") {
//                           isPresented = false
//                       }
//                       .font(.custom("Jellee", size: 16))
//                       .foregroundColor(.gray)
//                       .frame(maxWidth: .infinity)
//                       .padding()
//                       .background(Color(.systemGray6))
//                       .cornerRadius(12)
//                   }
//                   .padding()
//               }
//           }
//           .presentationDetents([.medium, .large])
//       }
//
//       private var locationLoadingView: some View {
//           VStack(spacing: 20) {
//               ProgressView()
//                   .scaleEffect(1.5)
//                   .tint(.indigo)
//
//               Text("Helymeghatározás...")
//                   .font(.custom("Jellee", size: 16))
//                   .fontWeight(.medium)
//                   .foregroundColor(.primary)
//
//               Text("Kérjük várjon, amíg megtaláljuk a pontos helyét")
//                   .font(.custom("Lexend", size: 18))
//                   .foregroundColor(.secondary)
//                   .multilineTextAlignment(.center)
//           }
//           .frame(height: 150)
//           .padding()
//       }
//
//       private var locationOptionsView: some View {
//           VStack(alignment: .leading, spacing: 16) {
//               Button(action: {
//                   fetchCurrentLocation()
//               }) {
//                   HStack {
//                       Image(systemName: "location.circle.fill")
//                           .foregroundColor(.white)
//                           .font(.title2)
//
//                       VStack(alignment: .leading, spacing: 4) {
//                           Text("Jelenlegi helyem")
//                               .font(.custom("Lexend", size: 16))
//                               .fontWeight(.medium)
//                               .foregroundColor(.white)
//                           Text("Automatikus helymeghatározás")
//                               .font(.custom("Lexend", size: 18))
//                               .foregroundColor(.white.opacity(0.8))
//                       }
//
//                       Spacer()
//
//                       Image(systemName: "chevron.right")
//                           .foregroundColor(.white)
//                   }
//                   .padding()
//                   .background(LinearGradient(
//                       gradient: Gradient(colors: [.indigo, .blue]),
//                       startPoint: .leading,
//                       endPoint: .trailing
//                   ))
//                   .cornerRadius(20)
//               }
//
//               Text("Vagy keresés:")
//                   .font(.custom("Jellee", size: 18))
//                   .foregroundColor(.primary)
//                   .padding(.top, 8)
//                   .padding(.bottom, 8)
//           }
//           .padding(.horizontal)
//       }
//
//       private func fetchCurrentLocation() {
//           isFetchingLocation = true
//
//           locationManager.requestLocation { location, error in
//               DispatchQueue.main.async {
//                   isFetchingLocation = false
//
//                   if let error = error {
//                       print("Hiba a helymeghatározás során: \(error.localizedDescription)")
//                       return
//                   }
//
//                   if let location = location {
//                       // Geocoding: koordináták átalakítása címré
//                       let geocoder = CLGeocoder()
//                       geocoder.reverseGeocodeLocation(location) { placemarks, error in
//                           DispatchQueue.main.async {
//                               if let placemark = placemarks?.first {
//                                   // Csak város és kerület/járás megjelenítése
//                                   let city = placemark.locality ?? "" // Város
//                                   let subLocality = placemark.subLocality ?? "" // Kerület/járás
//                                   let administrativeArea = placemark.administrativeArea ?? "" // Megye
//
//                                   // Összeállítjuk a megjelenítendő szöveget
//                                   var locationParts: [String] = []
//
//                                   if !subLocality.isEmpty {
//                                       locationParts.append(subLocality)
//                                   }
//
//                                   if !city.isEmpty {
//                                       locationParts.append(city)
//                                   } else if !administrativeArea.isEmpty {
//                                       // Ha nincs város, de van megye
//                                       locationParts.append(administrativeArea)
//                                   }
//
//                                   if locationParts.isEmpty {
//                                       // Ha egyik sem elérhető, koordinátákat használjuk
//                                       selectedLocation = String(format: "%.4f, %.4f",
//                                                               location.coordinate.latitude,
//                                                               location.coordinate.longitude)
//                                   } else {
//                                       selectedLocation = locationParts.joined(separator: ", ")
//                                   }
//
//                               } else {
//                                   // Ha nem sikerül a geocoding, koordinátákat használjuk
//                                   selectedLocation = String(format: "%.4f, %.4f",
//                                                           location.coordinate.latitude,
//                                                           location.coordinate.longitude)
//                               }
//                           }
//                       }
//                   }
//               }
//           }
//       }
//
//       private func performSearch(query: String) {
//           guard !query.isEmpty else {
//               searchResults = []
//               isSearching = false
//               return
//           }
//
//           isSearching = true
//
//           let request = MKLocalSearch.Request()
//           request.naturalLanguageQuery = query
//           request.resultTypes = [.pointOfInterest, .address]
//
//           let search = MKLocalSearch(request: request)
//           search.start { response, error in
//               DispatchQueue.main.async {
//                   isSearching = false
//
//                   if let error = error {
//                       print("Search error: \(error.localizedDescription)")
//                       return
//                   }
//
//                   searchResults = response?.mapItems ?? []
//               }
//           }
//       }
//
//       private func selectLocation(_ mapItem: MKMapItem) {
//           let locationName = mapItem.name ?? "Ismeretlen hely"
//           let address = mapItem.placemark.title ?? ""
//
//           selectedLocation = "\(locationName), \(address)"
//           searchText = ""
//           searchResults = []
//       }
//   }
//
//   // MARK: - Location Manager (javított verzió)
//   class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//       private let locationManager = CLLocationManager()
//       private var completion: ((CLLocation?, Error?) -> Void)?
//       private var isRequestingLocation = false
//
//       override init() {
//           super.init()
//           locationManager.delegate = self
//           locationManager.desiredAccuracy = kCLLocationAccuracyBest
//       }
//
//       func requestLocation(completion: @escaping (CLLocation?, Error?) -> Void) {
//           guard !isRequestingLocation else { return }
//
//           self.completion = completion
//           self.isRequestingLocation = true
//
//           let status = locationManager.authorizationStatus
//
//           switch status {
//           case .notDetermined:
//               print("Engedély kérése...")
//               locationManager.requestWhenInUseAuthorization()
//           case .authorizedWhenInUse, .authorizedAlways:
//               print("Helymeghatározás indítása...")
//               locationManager.requestLocation()
//           case .denied, .restricted:
//               print("Helymeghatározás nem engedélyezett")
//               let error = NSError(domain: "Location", code: 1,
//                                 userInfo: [NSLocalizedDescriptionKey: "Helymeghatározás nem //   engedélyezett. Kérjük, engedélyezze a Beállítások //   alkalmazásban."])
//               completion(nil, error)
//               self.completion = nil
//               self.isRequestingLocation = false
//           @unknown default:
//               let error = NSError(domain: "Location", code: 2,
//                                 userInfo: [NSLocalizedDescriptionKey: "Ismeretlen engedélyezési //   státusz"])
//               completion(nil, error)
//               self.completion = nil
//               self.isRequestingLocation = false
//           }
//       }
//
//       func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//           print("Hely adatok érkeztek: \(locations.count)")
//           completion?(locations.first, nil)
//           completion = nil
//           isRequestingLocation = false
//       }
//
//       func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//           print("Helymeghatározási hiba: \(error.localizedDescription)")
//           completion?(nil, error)
//           completion = nil
//           isRequestingLocation = false
//       }
//
//       func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//           print("Engedély státusz változott: \(manager.authorizationStatus.rawValue)")
//
//           if manager.authorizationStatus == .authorizedWhenInUse ||
//              manager.authorizationStatus == .authorizedAlways {
//               if isRequestingLocation {
//                   print("Engedély megadva, helymeghatározás indítása...")
//                   manager.requestLocation()
//               }
//           } else if manager.authorizationStatus == .denied || manager.authorizationStatus == //   .restricted {
//               if isRequestingLocation {
//                   let error = NSError(domain: "Location", code: 1,
//                                     userInfo: [NSLocalizedDescriptionKey: "Helymeghatározás nem //   engedélyezett"])
//                   completion?(nil, error)
//                   completion = nil
//                   isRequestingLocation = false
//               }
//           }
//       }
//   }
//
//   // MARK: - Preview
//   #Preview {
//       LocationPickerView(
//           selectedLocation: .constant(nil),
//           isPresented: .constant(true)
//       )
//   }
//
