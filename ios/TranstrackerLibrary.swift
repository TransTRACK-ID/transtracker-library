import Foundation
import CoreLocation

@objc(TranstrackerLibrary)
class TranstrackerLibrary: RCTEventEmitter, CLLocationManagerDelegate {

    @objc(multiply:withB:withResolver:withRejecter:)
    func multiply(a: Float, b: Float, resolve:RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) -> Void {
        resolve(a*b)
    }

    let locationManager = CLLocationManager()
    var imeiUser: String = "";
    var heading: Double = 0;

    override func supportedEvents() -> [String]! {
        return ["onLocationChanged"]
    }

    @objc(initiateService:)
    func initiateService(imei: String) {
        // locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        imeiUser = imei

        let status: CLAuthorizationStatus

        if #available(iOS 14, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if(status == .denied || status == .restricted || !CLLocationManager.locationServicesEnabled()){
            return
        }

        if(status == .notDetermined){
            locationManager.requestAlwaysAuthorization()

            // if you want the app to retrieve location data even in background, use requestAlwaysAuthorization
            // locationManager?.requestAlwaysAuthorization()
            return
        }

        // at this point the authorization status is authorized
        // request location data once
        // locationManager!.startUpdatingLocation()
        // sendEvent(withName:"onLocationChanged", body:["latitude": 0.0, "longitude": 0.0, "speed": 0.0]);
    }

    @objc(startService:)
    func startService(_ onFailureCallback: RCTResponseSenderBlock) -> Void {
        locationManager.startUpdatingLocation()
    }

    @objc(stopService:)
    func stopService(_ onFailureCallback: RCTResponseSenderBlock) -> Void {
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[locations.count - 1]
        let coordinate = location.coordinate

        sendEvent(withName:"onLocationChanged", body:["latitude": coordinate.latitude, "longitude": coordinate.longitude, "speed": location.speed, "bearing": self.heading]);

        let apiWithParams =
        "http://telematics.transtrack.id:6055?" +
        "altitude=\(location.altitude)" +
        "&odometer=&" +
        "bearing=\(self.heading)" +
        "&lon=\(coordinate.longitude)" +
        "&id=\(self.imeiUser)" +
        "&hdop=1" +
        "&ignition=true" +
        "&lat=\(coordinate.latitude)" +
        "&speed=\(location.speed)" +
        "&timestamp=\(Date().millisecondsSince1970)"

        let url = URL(string: apiWithParams)!


        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("error=\(String(describing: error))")
                return
            }

            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
            }

            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
        task.resume()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        self.heading = Double(round(1 * heading.trueHeading) / 1)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("location manager authorization status changed")

        switch status {
        case .authorizedAlways:
            print("user allow app to get location data when app is active or in background")
        case .authorizedWhenInUse:
            print("user allow app to get location data only when app is active")
        case .denied:
            print("user tap 'disallow' on the permission dialog, cant get location data")
        case .restricted:
            print("parental control setting disallow location data")
        case .notDetermined:
            print("the location permission dialog haven't shown before, user haven't tap allow/disallow")
        default:
            print("ok")
        }
    }
}

extension Date {
    var millisecondsSince1970: Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
