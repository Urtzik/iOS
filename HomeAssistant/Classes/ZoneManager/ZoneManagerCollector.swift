import CoreLocation
import PromiseKit
import Shared

protocol ZoneManagerCollectorDelegate: AnyObject {
    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState)
    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent)
}

protocol ZoneManagerCollector: CLLocationManagerDelegate {
    var delegate: ZoneManagerCollectorDelegate? { get set }
}

class ZoneManagerCollectorImpl: NSObject, ZoneManagerCollector {
    weak var delegate: ZoneManagerCollectorDelegate?

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        delegate?.collector(self, didLog: .didError(error))
    }

    func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: Error
    ) {
        delegate?.collector(self, didLog: .didFailMonitoring(region, error))
    }

    func locationManager(
        _ manager: CLLocationManager,
        didStartMonitoringFor region: CLRegion
    ) {
        delegate?.collector(self, didLog: .didStartMonitoring(region))

        if Current.isCatalyst {
            Current.Log.info("not querying region state due to catalyst lacking persistent region monitoring")
        } else {
            manager.requestState(for: region)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didDetermineState state: CLRegionState,
        for region: CLRegion
    ) {
        let zone = Current.realm()
            .objects(RLMZone.self)
            .first(where: {
                $0.ID == region.identifier || $0.ID == region.identifier.components(separatedBy: "@").first
            })

        let event = ZoneManagerEvent(
            eventType: .region(region, state),
            associatedZone: zone
        )

        delegate?.collector(self, didCollect: event)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let event = ZoneManagerEvent(
            eventType: .locationChange(locations)
        )

        delegate?.collector(self, didCollect: event)
    }
}
