import Foundation

public enum RestoreImageCacheError: Error, Equatable, CustomStringConvertible {
    case downloadFailed(statusCode: Int)
    case incompleteDownload(expected: Int64, received: Int64)

    public var description: String {
        switch self {
        case .downloadFailed(let statusCode):
            "The restore image download failed (HTTP \(statusCode))."
        case .incompleteDownload(let expected, let received):
            "The restore image download was incomplete (\(received) of \(expected) bytes)."
        }
    }
}

/// Downloaded macOS restore images, kept in `~/Library/Caches/Ampoule/RestoreImages` for reuse.
public enum RestoreImageCache {
    public static var defaultDirectory: URL {
        URL.cachesDirectory.appending(path: "Ampoule/RestoreImages", directoryHint: .isDirectory)
    }

    /// Returns a local copy of `remoteURL`, downloading it unless it's already cached.
    ///
    /// A file only appears under its final name once the download is complete and its size checks out.
    /// `progress` receives (bytes written, bytes expected) on an arbitrary thread. Cancelling the task cancels the download.
    public static func localCopy(
        of remoteURL: URL,
        in directory: URL = defaultDirectory,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws -> URL {
        let destination = directory.appending(path: remoteURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let partial = directory.appending(path: ".\(remoteURL.lastPathComponent).\(UUID().uuidString).partial")

        let download = Download(destination: partial, progress: progress)
        do {
            try await download.run(remoteURL)
            try FileManager.default.moveItem(at: partial, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        return destination
    }
}

/// One download with progress reporting. The finished file is moved to `destination` inside the
/// delegate callback, because URLSession deletes its temporary file as soon as the callback returns.
private final class Download: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: @Sendable (Int64, Int64) -> Void
    // Written once by the delegate queue before the continuation resumes, read after.
    private var completion: Result<Void, Error> = .success(())
    private var continuation: CheckedContinuation<Void, Error>?
    private let lock = NSLock()

    init(destination: URL, progress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func run(_ url: URL) async throws {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: url)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { self.continuation = continuation }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                throw RestoreImageCacheError.downloadFailed(statusCode: statusCode)
            }
            let expected = downloadTask.countOfBytesExpectedToReceive
            let received = Int64(try location.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            if expected > 0, received != expected {
                throw RestoreImageCacheError.incompleteDownload(expected: expected, received: received)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            completion = .success(())
        } catch {
            completion = .failure(error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let result = error.map { Result<Void, Error>.failure($0) } ?? completion
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}
