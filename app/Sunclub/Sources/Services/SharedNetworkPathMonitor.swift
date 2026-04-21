import Foundation
import Network

/// Exposes the current `NWPath` so services like `UVIndexService`
/// can honor Low Data Mode (`path.isConstrained`) and Cellular
/// expensive-network flags (`path.isExpensive`) before triggering
/// a WeatherKit fetch.
final class SharedNetworkPathMonitor: @unchecked Sendable {
    static let shared = SharedNetworkPathMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.sunclub.networkPathMonitor")
    private let lock = NSLock()
    private var cachedPath: NWPath?

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.cachedPath = path
            self.lock.unlock()
        }
        self.monitor.start(queue: queue)
    }

    var currentPath: NWPath? {
        lock.lock()
        defer { lock.unlock() }
        return cachedPath ?? monitor.currentPath
    }
}
