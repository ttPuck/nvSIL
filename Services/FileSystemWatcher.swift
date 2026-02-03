
import Foundation

class FileSystemWatcher {
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let monitoredDirectory: URL
    private var fileDescriptor: Int32 = -1

    var onDirectoryChange: (() -> Void)?

    init(monitoredDirectory: URL) {
        self.monitoredDirectory = monitoredDirectory
    }

    func startWatching() {
        stopWatching()

        let path = monitoredDirectory.path
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )

        source.setEventHandler { [weak self] in
            DispatchQueue.main.async { self?.onDirectoryChange?() }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source.resume()
        dispatchSource = source
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    deinit {
        stopWatching()
    }
}
