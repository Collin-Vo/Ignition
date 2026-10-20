//
//  AppFolderWatcher.swift
//  Ignition
//

import Foundation
import CoreServices

/// Watches folders with FSEvents and calls `onChange` (on the main queue) when anything inside them changes
final class AppFolderWatcher {

    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// (Re)starts watching the given folders. Replaces any folders watched before.
    func watch(_ folders: [URL]) {
        stop()
        guard !folders.isEmpty else { return }

        var context = FSEventStreamContext(version: 0,
                                           info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil,
                                           release: nil,
                                           copyDescription: nil)

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<AppFolderWatcher>.fromOpaque(info).takeUnretainedValue()
            // The stream is scheduled on the main queue
            MainActor.assumeIsolated {
                watcher.onChange()
            }
        }

        // Installing an app writes thousands of files into its bundle, so the latency
        // coalesces those into a single callback instead of one reload per file
        guard let stream = FSEventStreamCreate(kCFAllocatorDefault,
                                               callback,
                                               &context,
                                               folders.map(\.path) as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                               1.0,
                                               FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer)) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
