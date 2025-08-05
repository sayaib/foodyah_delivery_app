import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize location manager
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    
    // Request location permissions immediately to ensure the prompt appears
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
      self?.requestLocationPermissions()
    }
    
    // Register for local notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Location Permission Methods
  
  private func requestLocationPermissions() {
    print("Requesting location permissions from AppDelegate")
    
    guard let locationManager = locationManager else {
      print("Location manager not initialized")
      return
    }
    
    let status = CLLocationManager.authorizationStatus()
    print("Current location authorization status: \(status.rawValue)")
    
    switch status {
    case .notDetermined:
      // Request "when in use" permission first
      locationManager.requestWhenInUseAuthorization()
      print("Requested 'When In Use' authorization")
    case .authorizedWhenInUse:
      // If already authorized for when in use, request always permission
      locationManager.requestAlwaysAuthorization()
      print("Requested 'Always' authorization")
    default:
      print("No need to request permissions, current status: \(status.rawValue)")
    }
  }
  
  // MARK: - CLLocationManagerDelegate
  
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    print("Location authorization status changed to: \(status.rawValue)")
    
    switch status {
    case .notDetermined:
      print("Location permission status: Not Determined")
    case .restricted:
      print("Location permission status: Restricted")
    case .denied:
      print("Location permission status: Denied")
    case .authorizedWhenInUse:
      print("Location permission status: Authorized When In Use")
      // If we get 'when in use' permission, request 'always' permission after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.locationManager?.requestAlwaysAuthorization()
        print("Automatically requesting 'Always' authorization after receiving 'When In Use'")
      }
    case .authorizedAlways:
      print("Location permission status: Authorized Always")
    @unknown default:
      print("Location permission status: Unknown")
    }
  }
}
