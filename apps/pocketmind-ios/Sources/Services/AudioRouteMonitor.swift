import AVFoundation
import Combine
import Foundation
import OSLog

private let audioLogger = Logger(subsystem: "com.pocketmind", category: "AudioRouteMonitor")

@MainActor
protocol AudioRouteMonitorProtocol: AnyObject {
    var isAirPodsConnected: Bool { get }
    var isAirPodsConnectedPublisher: AnyPublisher<Bool, Never> { get }
}

/// Monitors audio route changes to detect AirPods and HomePod connections.
@MainActor
final class AudioRouteMonitor: ObservableObject, AudioRouteMonitorProtocol {
    @Published private(set) var isAirPodsConnected = false
    @Published private(set) var isHomePodConnected = false
    @Published private(set) var currentAudioRoute: String = ""

    var isAirPodsConnectedPublisher: AnyPublisher<Bool, Never> { $isAirPodsConnected.eraseToAnyPublisher() }

    nonisolated(unsafe) private var routeChangeObserver: Any?

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
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleRouteChange()
            }
        }
    }

    private func handleRouteChange() {
        audioLogger.debug("Audio route changed")
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
