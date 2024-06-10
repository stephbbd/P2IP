import UIKit
import MapKit
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate, UITextFieldDelegate {
    
    // UI Elements
    @IBOutlet weak var startingPointTextField: UITextField!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var Km: UILabel!
    @IBOutlet weak var min: UILabel!
    @IBOutlet weak var distanceLet: UILabel!
    @IBOutlet weak var TimeLet: UILabel!
    @IBOutlet weak var arrivalTime: UILabel!
    @IBOutlet weak var arrivé: UILabel!
    @IBOutlet weak var okButton: UIButton!
    @IBOutlet weak var signaler: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var routeSelector: UISegmentedControl!
    @IBOutlet weak var distanceDurationLabel: UILabel!
    @IBOutlet weak var searchRouteButton: UIButton!
    
    // Properties
    let db = Firestore.firestore()
    let locationManager = CLLocationManager()
    var searchController: UISearchController!
    var isFirstTime = true
    var currentCoordinate: CLLocationCoordinate2D?
    var routes: [MKRoute] = []
    
    // Predefined destinations
    let destinations = [
        "Stade de France": CLLocationCoordinate2D(latitude: 48.924459, longitude: 2.360169),
        "Parc des Princes": CLLocationCoordinate2D(latitude: 48.841388, longitude: 2.253011),
        "Château de Versailles": CLLocationCoordinate2D(latitude: 48.804865, longitude: 2.120355)
    ]
    
    // Pôle Léonard de Vinci coordinates
    let originCoordinate = CLLocationCoordinate2D(latitude: 48.896720, longitude: 2.233640)
    
    // Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchController()
        startingPointTextField.delegate = self
        mapView.delegate = self
        mapView.showsUserLocation = true
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        hideAllControls()
        generateRandomStairs(count: 100)
        
        // Display routes to the predefined destinations
        for (destinationName, destinationCoordinate) in destinations {
            calculateRoute(from: originCoordinate, to: destinationCoordinate, transportType: .automobile, destinationName: destinationName)
            calculateRoute(from: originCoordinate, to: destinationCoordinate, transportType: .walking, destinationName: destinationName)
            calculateRoute(from: originCoordinate, to: destinationCoordinate, transportType: .transit, destinationName: destinationName)
        }
    }
    
    // Actions
    @IBAction func okButtonPressed(_ sender: UIButton) {
        showArrivalTime()
        distanceDurationLabel.isHidden = true
        okButton.isHidden = true
        arrivalTime.isHidden = false
        arrivé.isHidden = false
        distanceLet.isHidden = false
        TimeLet.isHidden = false
        Km.isHidden = false
        min.isHidden = false
        signaler.isHidden = false
    }
    
    @IBAction func reportIssueButtonPressed(_ sender: UIButton) {
        showReportIssueAlert()
    }
    
    @IBAction func searchRouteButtonPressed(_ sender: UIButton) {
        searchRoute()
    }
    
    @IBAction func routeSelectorChanged(_ sender: UISegmentedControl) {
        updateRouteDisplay()
    }
    
    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            currentCoordinate = location.coordinate
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
            generateRandomStairs(count: 100)
        }
    }
    
    // UISearchBarDelegate
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.isHidden = true
        signaler.isHidden = false
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            return
        }
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchText
        searchRequest.region = mapView.region
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            guard let response = response else {
                print("Erreur de recherche : \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }
            
            self.mapView.removeAnnotations(self.mapView.annotations)
            self.mapView.removeOverlays(self.mapView.overlays)
            self.routes.removeAll()
            
            if let firstItem = response.mapItems.first {
                let annotation = MKPointAnnotation()
                annotation.coordinate = firstItem.placemark.coordinate
                self.mapView.addAnnotation(annotation)
                
                DispatchQueue.main.async {
                    searchBar.isHidden = true
                    self.destinationTextField.isHidden = false
                    self.startingPointTextField.isHidden = false
                    self.destinationTextField.text = searchText
                    self.distanceDurationLabel.isHidden = true
                    self.displayUserLocation()
                    self.searchRouteButton.isHidden = false
                }
            }
        }
    }
    
    // MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = polyline.title == "Marche" ? UIColor.blue : UIColor.red
            renderer.lineWidth = 3
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        guard let customAnnotation = annotation as? CustomPointAnnotation else {
            return nil
        }
        
        let reuseIdentifier = "customAnnotationView"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        if (annotationView == nil) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        if let image = UIImage(named: customAnnotation.imageName) {
            annotationView?.image = image
        } else {
            annotationView?.image = UIImage(named: "defaultImage")
        }
        
        return annotationView
    }
    
    // Helper Functions
    func hideAllControls() {
        startingPointTextField.isHidden = true
        destinationTextField.isHidden = true
        hideSearchControls()
    }
    
    func showTextFields() {
        startingPointTextField.isHidden = false
        destinationTextField.isHidden = false
    }
    
    func hideSearchControls() {
        arrivalTime.isHidden = true
        arrivé.isHidden = true
        distanceLet.isHidden = true
        TimeLet.isHidden = true
        Km.isHidden = true
        min.isHidden = true
    }
    
    func showSearchControls() {
        arrivalTime.isHidden = true
        arrivé.isHidden = true
        distanceLet.isHidden = true
        TimeLet.isHidden = true
        Km.isHidden = true
        min.isHidden = true
        distanceDurationLabel.isHidden = false
        okButton.isHidden = false
    }
    
    func displayUserLocation() {
        if let userLocation = mapView.userLocation.location {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(userLocation) { (placemarks, error) in
                if let placemark = placemarks?.first {
                    self.startingPointTextField.text = placemark.name ?? "Unknown Location"
                }
            }
        }
    }
    
    // Calculate route from a given start point to a destination with a specific transport type
    func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: MKDirectionsTransportType, destinationName: String) {
        let startPlacemark = MKPlacemark(coordinate: start)
        let endPlacemark = MKPlacemark(coordinate: end)
        
        let startItem = MKMapItem(placemark: startPlacemark)
        let endItem = MKMapItem(placemark: endPlacemark)
        
        let request = MKDirections.Request()
        request.source = startItem
        request.destination = endItem
        request.transportType = transportType
        request.requestsAlternateRoutes = true
        
        fetchReports { (reportedIssues) in
            let directions = MKDirections(request: request)
            directions.calculate { (response, error) in
                guard let response = response, !response.routes.isEmpty else {
                    print("Erreur de calcul d'itinéraire : \(error?.localizedDescription ?? "Erreur inconnue")")
                    return
                }
                
                // Filter out routes that contain reported issues
                self.routes = response.routes.filter { !self.routeContainsReportedIssue(route: $0, reportedIssues: reportedIssues) }
                
                if self.routes.isEmpty {
                    print("Aucun itinéraire disponible sans problèmes signalés.")
                    return
                }
                
                self.mapView.removeOverlays(self.mapView.overlays)
                self.mapView.addOverlays(self.routes.map { $0.polyline })
                
                let firstRoute = self.routes[0]
                self.mapView.setVisibleMapRect(firstRoute.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
                
                self.showArrivalTime()
                
                // Display starting point and destination names in text fields
                self.startingPointTextField.text = "Pôle Léonard de Vinci"
                self.destinationTextField.text = destinationName
            }
        }
    }
    
    func updatedistanceDurationLabel(time: TimeInterval, distance: CLLocationDistance) {
        let timeString = String(format: "%.0f", time / 60)
        let distanceString = String(format: "%.2f", distance / 1000)
        
        let timeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let distanceAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.lightGray
        ]
        
        let attributedText = NSMutableAttributedString(string: "\(timeString) min\n", attributes: timeAttributes)
        attributedText.append(NSAttributedString(string: "\(distanceString) km", attributes: distanceAttributes))
        
        distanceDurationLabel.attributedText = attributedText
        distanceDurationLabel.numberOfLines = 0
    }
    
    func showArrivalTime() {
        guard !routes.isEmpty else { return }
        let route = routes[routeSelector.selectedSegmentIndex]

        let distance = route.distance / 1000
        let duration = route.expectedTravelTime / 60
        let arrivalDate = Date(timeIntervalSinceNow: route.expectedTravelTime)

        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        let arrivalTimeString = dateFormatter.string(from: arrivalDate)

        distanceLet.text = String(format: "%.2f km", distance)
        TimeLet.text = String(format: "%.0f min", duration)
        arrivalTime.text = arrivalTimeString
    }
    
    func showReportIssueAlert() {
        searchController.isActive = false
        let alertController = UIAlertController(title: "Signaler un problème", message: "Sélectionnez le type de problème à signaler :", preferredStyle: .actionSheet)

        let issues = [
            "Escalier",
            "Nouvel escalator",
            "Panne d'escalator",
            "Ascenseur",
            "Panne d'ascenseur"
        ]

        for issue in issues {
            let action = UIAlertAction(title: issue, style: .default) { _ in
                self.reportIssue(issue: issue)
            }
            alertController.addAction(action)
        }

        let cancelAction = UIAlertAction(title: "Annuler", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
    
    func reportIssue(issue: String) {
        guard let currentLocation = currentCoordinate else {
            print("Erreur : la localisation actuelle de l'utilisateur est introuvable")
            return
        }

        print("Problème signalé : \(issue) à la localisation (\(currentLocation.latitude), \(currentLocation.longitude))")
        
        let annotation: CustomPointAnnotation
        let subtitle = "Problème signalé: \(issue)"
        
        switch issue {
        case "Escalier":
            annotation = createAnnotation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, title: issue, subtitle: subtitle, imageName: "escalier")
        case "Nouvel escalator":
            annotation = createAnnotation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, title: issue, subtitle: subtitle, imageName: "escalator")
        case "Panne d'escalator":
            annotation = createAnnotation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, title: issue, subtitle: subtitle, imageName: "escalatorenpanne")
        case "Nouvel ascenseur":
            annotation = createAnnotation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, title: issue, subtitle: subtitle, imageName: "ascenseur")
        case "Panne d'ascenseur":
            annotation = createAnnotation(latitude: currentLocation.latitude, longitude: currentLocation.longitude, title: issue, subtitle: subtitle, imageName: "ascenseurenpanne")
        default:
            return
        }
        addReport(issue: issue, location: currentLocation)

        mapView.addAnnotation(annotation)
    }
    
    func createAnnotation(latitude: CLLocationDegrees, longitude: CLLocationDegrees, title: String, subtitle: String, imageName: String) -> CustomPointAnnotation {
        let annotation = CustomPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        annotation.title = title
        annotation.subtitle = subtitle
        annotation.imageName = imageName
        return annotation
    }
    
    func addReport(issue: String, location: CLLocationCoordinate2D) {
        let reportData: [String: Any] = [
            "issue": issue,
            "latitude": location.latitude,
            "longitude": location.longitude,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("reports").addDocument(data: reportData) { error in
            if let error = error {
                print("Erreur lors de l'ajout du signalement : \(error.localizedDescription)")
            } else {
                print("Signalement ajouté avec succès")
            }
        }
    }
    
    func generateRandomStairs(count: Int) {
        guard let currentLocation = currentCoordinate else {
            print("Erreur: la localisation actuelle de l'utilisateur est introuvable")
            return
        }

        for _ in 0..<count {
            let randomLatitude = currentLocation.latitude + Double.random(in: -0.005...0.005)
            let randomLongitude = currentLocation.longitude + Double.random(in: -0.005...0.005)
            let annotation = createAnnotation(latitude: randomLatitude, longitude: randomLongitude, title: "Escalier", subtitle: "Escalier aléatoire", imageName: "escalier")
            mapView.addAnnotation(annotation)
        }
    }

    func fetchReports(completion: @escaping ([CLLocationCoordinate2D]) -> Void) {
        db.collection("reports").getDocuments { querySnapshot, error in
            if let error = error {
                print("Erreur lors de la récupération des signalements : \(error.localizedDescription)")
                completion([])
            } else {
                var problemLocations: [CLLocationCoordinate2D] = []
                
                for document in querySnapshot!.documents {
                    let data = document.data()
                    let latitude = data["latitude"] as! CLLocationDegrees
                    let longitude = data["longitude"] as! CLLocationDegrees
                    problemLocations.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
                
                completion(problemLocations)
            }
        }
    }

    func routeContainsReportedIssue(route: MKRoute, reportedIssues: [CLLocationCoordinate2D]) -> Bool {
        let maxDistance: CLLocationDistance = 50.0
        
        for problemLocation in reportedIssues {
            let problemPoint = MKMapPoint(problemLocation)
            
            for step in route.steps {
                let polyline = step.polyline
                let closestPointOnPolyline = polyline.closestPoint(to: problemPoint)
                let distance = problemPoint.distance(to: closestPointOnPolyline)
                
                if distance <= maxDistance {
                    return true
                }
            }
        }
        
        return false
    }
}
