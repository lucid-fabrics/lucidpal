import AVFoundation
import Combine
import Foundation
import OSLog

private let audioLogger = Logger(subsystem: "com.pocketmind", category: "AudioRouteMonitor")

/// Monitors audio route changes to detect AirPods and HomePod connections.
@MainActor
final class AudioRouteMonitor: ObservableObject {
    @Published private(set) var isAirPodsConnected = false
    @Published private(set) var isHomePodConnected = false
    @Published private(set) var currentAudioRoute: String = ""

    private var routeChangeObserver: Any?

    init() {
        updateAudioRouteState()
        observeRouteChanges()
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Private Methods

    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason) else {
            return
        }

        audioLogger.debug("Audio route changed: \(String(describing: changeReason))")
        updateAudioRouteState()
    }

    private func updateAudioRouteState() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        var detectedAirPods = false
        var detectedHomePod = false
        var routeNames: [String] = []

        for output in outputs {
            routeNames.append(output.portName)

            // AirPods detection: port type is BluetoothA2DP or BluetoothHFP, name contains "AirPods"
            if (output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP),
               output.portName.contains("AirPods") {
                detectedAirPods = true
            }

            // HomePod detection: port type is AirPlay
            if output.portType == .airPlay {
                detectedHomePod = true
            }
        }

        isAirPodsConnected = detectedAirPods
        isHomePodConnected = detectedHomePod
        currentAudioRoute = routeNames.joined(separator: ", ")

        audioLogger.debug("Audio route updated: \(self.currentAudioRoute) | AirPods: \(detectedAirPods) | HomePod: \(detectedHomePod)")
    }
}
