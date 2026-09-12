// X100VIHelperClient.swift
// Implements PTPClientProtocol by spawning the x100vi_helper C executable.

import Foundation
import FujiRecipesCore

/// PTPClientProtocol implementation that spawns the x100vi_helper C executable.
/// The C helper uses libusb to send PTP containers directly to the X100VI.
///
/// Communication is line-delimited JSON (one request line, one response line).
/// Because the helper is a long-lived process, its stdout is consumed as an
/// `AsyncSequence` of lines; requests are funnelled through a single serial
/// worker so responses always match the order in which they were sent.
public final class X100VIHelperClient: PTPClientProtocol, @unchecked Sendable {
    public init() {}

    private var process: Process?
    private var inputPipe: Pipe?
    private var lineIterator: AsyncThrowingStream<String, any Error>.Iterator?
    private var requestStreamContinuation: AsyncStream<PendingRequest>.Continuation?
    private var requestProcessorTask: Task<Void, Never>?
    private var isConnectedFlag = false
    private var transactionID = 0
    private var _cameraInfo: PTPCameraInfo = PTPCameraInfo(model: "Not connected")

    // All mutable state is touched only inside the serial `queue`.  The public
    // `async` entry points dispatch to it; the request-processor task (which
    // owns the line iterator) runs on the cooperative thread pool.
    private let queue = DispatchQueue(label: "com.fujirecipes.x100vi-helper")

    public var isConnected: Bool {
        queue.sync { isConnectedFlag }
    }

    public var cameraInfo: PTPCameraInfo {
        get { queue.sync { _cameraInfo } }
        set { queue.sync { _cameraInfo = newValue } }
    }

    // MARK: - PTPClientProtocol

    public func connect() async throws {
        // ptpcamerad auto-respawns and grabs the USB interface on macOS.
        // Kill it before every connect so libusb can claim the device.
        #if os(macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["-9", "ptpcamerad"]
        try? task.run()
        task.waitUntilExit()
        #endif

        return try await withTimeout(timeout: 30) {
            try await self.connectInternal()
        }
    }

    private func connectInternal() async throws {
        guard let helperPath = findHelper() else {
            throw PTPError.connectionFailed("x100vi_helper not found")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: helperPath)

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.standardError

        try process.run()

        // Build an async line iterator over the helper's stdout.  We bridge
        // FileHandle's bytes.lines into an AsyncThrowingStream so the iterator
        // type is simple and Sendable-friendly.
        let (lines, linesContinuation) = AsyncThrowingStream<String, any Error>.makeStream()
        Task {
            do {
                for try await rawLine in stdoutPipe.fileHandleForReading.bytes.lines {
                    linesContinuation.yield(String(rawLine))
                }
                linesContinuation.finish()
            } catch {
                linesContinuation.finish(throwing: error)
            }
        }

        let (requestStream, requestContinuation) = AsyncStream<PendingRequest>.makeStream()

        self.queue.sync {
            self.process = process
            self.inputPipe = stdinPipe
            self.lineIterator = lines.makeAsyncIterator()
            self.requestStreamContinuation = requestContinuation
            self.isConnectedFlag = true
        }

        // Start the single worker that owns the iterator and serialises I/O.
        let processor = Task { [weak self] in
            guard let self else { return }
            await self.processRequests(from: requestStream)
        }
        self.queue.sync { self.requestProcessorTask = processor }

        // Verify the helper is alive.
        let response = try await sendCommand("ping", params: [:])
        guard response["success"] as? Bool == true else {
            throw PTPError.connectionFailed("Helper responded with error")
        }

        self.cameraInfo = PTPCameraInfo(
            model: "Fuji X100VI",
            vendorExtensionId: 0x0000000E
        )
    }

    public func disconnect() {
        queue.sync {
            isConnectedFlag = false
            requestStreamContinuation?.finish()
            requestStreamContinuation = nil
            requestProcessorTask?.cancel()
            requestProcessorTask = nil

            if let proc = process, proc.isRunning {
                proc.terminate()
                // Do not wait here: this runs inside queue.sync and could deadlock
                // if the helper is blocked reading.  A short async cleanup follows.
            }
            process = nil
            inputPipe = nil
            lineIterator = nil
        }
    }

    public func readProperty(_ code: UInt16) async throws -> PTPPropertyResponse {
        let response = try await sendCommand("read_property", params: ["code": Int(code)])

        guard response["success"] as? Bool == true,
              let result = response["result"] as? [String: Any] else {
            throw PTPError.readFailed(code, "Helper returned error")
        }

        if let errorCode = result["error_code"] as? Int {
            throw PTPError.readFailed(code, "Error code: \(String(format: "0x%04X", errorCode))")
        }

        if let raw = jsonUInt32(result["value"]) {
            return .uint32(raw)
        }
        if let raw = jsonInt32(result["value"]) {
            return .int32(raw)
        }
        if let string = result["value"] as? String {
            return .string(string)
        }
        if let string = result["display"] as? String {
            return .string(string)
        }
        if let array = result["value"] as? [UInt8] {
            return .data(Data(array))
        }

        return .unsupported
    }

    public func writeProperty(_ code: UInt16, value: Int32) async throws {
        let response = try await sendCommand("write_property", params: [
            "code": Int(code),
            "value": Int(value)
        ])

        guard response["success"] as? Bool == true else {
            throw PTPError.writeFailed(code, "Helper returned error")
        }
    }

    public func readPresetSlot(_ index: Int) async throws -> PTPClientPresetData {
        let response = try await sendCommand("read_preset_slot", params: ["index": index])

        guard response["success"] as? Bool == true,
              let result = response["result"] as? [String: Any],
              let properties = result["properties"] as? [String: [String: Any]] else {
            throw PTPError.invalidResponse("Invalid preset slot response")
        }

        var name = ""
        var imageQuality: UInt32?
        var imageSize: UInt32?
        var dynamicRange: UInt32?
        var filmSimulation: UInt32?
        var monoWarmCool: Int32?
        var monoMagentaGreen: Int32?
        var grainEffect: UInt32?
        var colorChrome: UInt32?
        var colorChromeFxBlue: UInt32?
        var smoothSkin: UInt32?
        var whiteBalance: UInt32?
        var wbShiftRed: Int32?
        var wbShiftBlue: Int32?
        var colorTemp: UInt32?
        var highlight: Int32?
        var shadow: Int32?
        var color: Int32?
        var sharpness: Int32?
        var clarity: Int32?
        var longExpNr: UInt32?
        var colorSpace: UInt32?

        for (key, value) in properties {
            guard let codeHex = key.components(separatedBy: "_").first,
                  let code = UInt16(codeHex.dropFirst(2), radix: 16) else { continue }

            switch code {
            case 0xD18D:
                if let display = value["display"] as? String, !display.isEmpty {
                    name = display
                }
            case 0xD18E: imageSize = jsonUInt32(value["raw"])
            case 0xD18F: imageQuality = jsonUInt32(value["raw"])
            case 0xD190: dynamicRange = jsonUInt32(value["raw"])
            case 0xD192: filmSimulation = jsonUInt32(value["raw"])
            case 0xD193: monoWarmCool = jsonInt32(value["raw"])
            case 0xD194: monoMagentaGreen = jsonInt32(value["raw"])
            case 0xD195: grainEffect = jsonUInt32(value["raw"])
            case 0xD196: colorChrome = jsonUInt32(value["raw"])
            case 0xD197: colorChromeFxBlue = jsonUInt32(value["raw"])
            case 0xD198: smoothSkin = jsonUInt32(value["raw"])
            case 0xD199: whiteBalance = jsonUInt32(value["raw"])
            case 0xD19A: wbShiftRed = jsonInt32(value["raw"])
            case 0xD19B: wbShiftBlue = jsonInt32(value["raw"])
            case 0xD19C: colorTemp = jsonUInt32(value["raw"])
            case 0xD19D: highlight = jsonInt32(value["raw"])
            case 0xD19E: shadow = jsonInt32(value["raw"])
            case 0xD19F: color = jsonInt32(value["raw"])
            case 0xD1A0: sharpness = jsonInt32(value["raw"])
            case 0xD1A2: clarity = jsonInt32(value["raw"])
            case 0xD1A3: longExpNr = jsonUInt32(value["raw"])
            case 0xD1A4: colorSpace = jsonUInt32(value["raw"])
            default: break
            }
        }

        return PTPClientPresetData(
            slot: index,
            name: name,
            imageQuality: imageQuality,
            imageSize: imageSize,
            dynamicRange: dynamicRange,
            filmSimulation: filmSimulation,
            monoWarmCool: monoWarmCool,
            monoMagentaGreen: monoMagentaGreen,
            grainEffect: grainEffect,
            colorChrome: colorChrome,
            colorChromeFxBlue: colorChromeFxBlue,
            smoothSkin: smoothSkin,
            whiteBalance: whiteBalance,
            wbShiftRed: wbShiftRed,
            wbShiftBlue: wbShiftBlue,
            colorTemp: colorTemp,
            highlight: highlight,
            shadow: shadow,
            color: color,
            sharpness: sharpness,
            clarity: clarity,
            longExpNr: longExpNr,
            colorSpace: colorSpace
        )
    }

    public func writePresetSlot(_ index: Int, data: PTPClientPresetData) async throws {
        var params: [String: any Sendable] = ["index": index]

        if !data.name.isEmpty { params["name"] = data.name }
        if let v = data.filmSimulation { params["film_simulation"] = Int(v) }
        if let v = data.dynamicRange { params["dynamic_range"] = Int(v) }
        if let v = data.grainEffect { params["grain_effect"] = Int(v) }
        if let v = data.colorChrome { params["color_chrome"] = Int(v) }
        if let v = data.colorChromeFxBlue { params["color_chrome_fx_blue"] = Int(v) }
        if let v = data.smoothSkin { params["smooth_skin"] = Int(v) }
        if let v = data.whiteBalance { params["white_balance"] = Int(v) }
        if let v = data.wbShiftRed { params["wb_shift_r"] = Int(v) }
        if let v = data.wbShiftBlue { params["wb_shift_b"] = Int(v) }
        if let v = data.colorTemp { params["color_temp"] = Int(v) }
        if let v = data.highlight { params["highlight"] = Int(v) }
        if let v = data.shadow { params["shadow"] = Int(v) }
        if let v = data.color { params["color"] = Int(v) }
        if let v = data.sharpness { params["sharpness"] = Int(v) }
        if let v = data.clarity { params["clarity"] = Int(v) }
        if let v = data.monoWarmCool { params["mono_warm_cool"] = Int(v) }
        if let v = data.monoMagentaGreen { params["mono_magenta_green"] = Int(v) }
        if let v = data.imageSize { params["image_size"] = Int(v) }
        if let v = data.imageQuality { params["image_quality"] = Int(v) }
        if let v = data.longExpNr { params["long_exp_nr"] = Int(v) }
        if let v = data.colorSpace { params["color_space"] = Int(v) }

        let response = try await sendCommand("write_preset_slot", params: params)

        guard response["success"] as? Bool == true else {
            throw PTPError.writeFailed(0xD18C, "Helper returned error")
        }
    }

    public func readNativeProfile() async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let profilePath = tempDir.appendingPathComponent("native_profile.dat").path

        let response = try await sendCommand("get_profile", params: ["output": profilePath])

        guard response["success"] as? Bool == true else {
            throw PTPError.readFailed(0xD185, "Helper returned error")
        }

        let url = URL(fileURLWithPath: profilePath)
        let profileData = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return profileData
    }

    public func writePTPSettings(from recipe: Recipe) async throws {
        if let fs = recipe.filmSimulation {
            try await writeProperty(0xD192, value: Int32(fs.rawValue))
        }
        if let dr = recipe.dynamicRange {
            try await writeProperty(0xD190, value: Int32(dr.rawValue))
        }
        if let grain = recipe.grainEffect {
            try await writeProperty(0xD195, value: Int32(grain.rawValue))
        }
        if let chrome = recipe.colorChrome {
            try await writeProperty(0xD196, value: Int32(chrome.rawValue))
        }
        if let chromeFx = recipe.colorChromeFxBlue {
            try await writeProperty(0xD197, value: Int32(chromeFx.rawValue))
        }
        if let smoothSkin = recipe.smoothSkin {
            try await writeProperty(0xD198, value: Int32(smoothSkin.rawValue))
        }
        if let wb = recipe.whiteBalanceMode {
            try await writeProperty(0xD199, value: Int32(wb.actualPTPValue))
        }
        if let ct = recipe.colorTempK {
            try await writeProperty(0xD19C, value: Int32(ct))
        }
        if let v = recipe.wbShiftRed {
            try await writeProperty(0xD19A, value: v)
        }
        if let v = recipe.wbShiftBlue {
            try await writeProperty(0xD19B, value: v)
        }
        if let v = recipe.highlight {
            try await writeProperty(0xD19D, value: v)
        }
        if let v = recipe.shadow {
            try await writeProperty(0xD19E, value: v)
        }
        if let v = recipe.color {
            try await writeProperty(0xD19F, value: v)
        }
        if let v = recipe.sharpness {
            try await writeProperty(0xD1A0, value: v)
        }
        if let v = recipe.clarity {
            try await writeProperty(0xD1A2, value: v)
        }
        if let v = recipe.highIsoNr {
            try await writeProperty(0xD1A1, value: v)
        }
    }

    public func convertRAF(_ raf: RAFFile, profileModifier: ((inout Data) -> Void)?) async throws -> JPEGFile? {
        // Profile modification is unsupported because the camera-verified
        // pipeline builds a default profile from scratch for X100VI.
        _ = profileModifier

        let tempDir = FileManager.default.temporaryDirectory
        let rafPath = tempDir.appendingPathComponent("input.RAF").path
        let jpegPath = tempDir.appendingPathComponent("output.jpg").path

        try raf.data.write(to: URL(fileURLWithPath: rafPath))

        defer {
            try? FileManager.default.removeItem(atPath: rafPath)
            try? FileManager.default.removeItem(atPath: jpegPath)
        }

        let response = try await sendCommand("convert_raf", params: [
            "input": rafPath,
            "output": jpegPath
        ])

        guard response["success"] as? Bool == true,
              let result = response["result"] as? [String: Any],
              let status = result["status"] as? String,
              status == "conversion_complete",
              let size = result["size"] as? Int,
              size > 0 else {
            let error = (response["result"] as? [String: Any])?["error"] as? String
                ?? response["error"] as? String
                ?? "unknown"
            throw PTPError.platformError("Conversion failed: \(error)")
        }

        let jpegData = try Data(contentsOf: URL(fileURLWithPath: jpegPath))
        return JPEGFile(
            name: "converted_\(raf.name)",
            data: jpegData,
            size: UInt32(size),
            storageID: 0,
            objectHandle: 0
        )
    }

    public func reconnect() async throws {
        let response = try await sendCommand("reconnect", params: [:])
        guard response["success"] as? Bool == true else {
            throw PTPError.connectionFailed("Reconnect failed")
        }
    }

    public func loadRAF(_ raf: RAFFile) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let rafPath = tempDir.appendingPathComponent("upload.RAF").path

        try raf.data.write(to: URL(fileURLWithPath: rafPath))
        defer { try? FileManager.default.removeItem(atPath: rafPath) }

        let response = try await sendCommand("load_raf", params: ["path": rafPath])
        guard response["success"] as? Bool == true else {
            throw PTPError.platformError("RAF load failed")
        }
    }

    public func triggerConversion() async throws {
        let response = try await sendCommand("trigger_conversion", params: [:])
        guard response["success"] as? Bool == true else {
            throw PTPError.platformError("Trigger conversion failed")
        }
    }

    public func setProfile(_ data: Data) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let profPath = tempDir.appendingPathComponent("profile.dat").path

        try data.write(to: URL(fileURLWithPath: profPath))
        defer { try? FileManager.default.removeItem(atPath: profPath) }

        let response = try await sendCommand("set_profile", params: ["path": profPath])
        guard response["success"] as? Bool == true else {
            throw PTPError.writeFailed(0xD185, "Helper returned error")
        }
    }

    public func waitConversionResult(outputName: String, timeoutMs: Int = 30000) async throws -> JPEGFile {
        let tempDir = FileManager.default.temporaryDirectory
        let jpegPath = tempDir.appendingPathComponent(outputName).path

        let response = try await sendCommand("wait_result", params: [
            "output": jpegPath,
            "timeout_ms": timeoutMs
        ])

        guard response["success"] as? Bool == true,
              let result = response["result"] as? [String: Any],
              let size = result["size"] as? Int,
              size > 0 else {
            throw PTPError.platformError("Wait result failed")
        }

        let jpegData = try Data(contentsOf: URL(fileURLWithPath: jpegPath))
        return JPEGFile(
            name: outputName,
            data: jpegData,
            size: UInt32(size),
            storageID: 0,
            objectHandle: 0
        )
    }

    public func capturePreview() async throws -> JPEGFile? {
        throw PTPError.platformError("Preview capture not yet implemented")
    }

    // MARK: - Command Communication

    private struct PendingRequest: Sendable {
        let command: String
        let params: [String: any Sendable]
        let continuation: CheckedContinuation<ResponseBox, any Error>
    }

    /// Serialise a command to the helper and return its parsed JSON response.
    /// The timeout applies to the end-to-end request/response cycle.
    @discardableResult
    private func sendCommand(_ command: String, params: [String: any Sendable], timeout: TimeInterval = 30) async throws -> [String: Any] {
        let box = try await withTimeout(timeout: timeout) {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ResponseBox, any Error>) in
                self.queue.sync {
                    guard let requestStreamContinuation = self.requestStreamContinuation else {
                        continuation.resume(throwing: PTPError.notConnected)
                        return
                    }
                    requestStreamContinuation.yield(PendingRequest(
                        command: command,
                        params: params,
                        continuation: continuation
                    ))
                }
            }
        }
        return box.dict
    }

    /// Non-Sendable JSON dictionaries from `JSONSerialization` cannot be returned
    /// directly from `withTimeout`'s `@Sendable` closure.  This box passes the
    /// dictionary across without claiming it is generally thread-safe.
    private final class ResponseBox: @unchecked Sendable {
        let dict: [String: Any]
        init(_ dict: [String: Any]) { self.dict = dict }
    }

    /// The single worker that owns the helper's stdout iterator and processes
    /// one request at a time.  This guarantees request/response ordering.
    private func processRequests(from stream: AsyncStream<PendingRequest>) async {
        for await request in stream {
            do {
                var (iterator, inputPipe, process) = self.queue.sync { () -> (AsyncThrowingStream<String, any Error>.Iterator, Pipe, Process) in
                    guard let iterator = self.lineIterator,
                          let inputPipe = self.inputPipe,
                          let process = self.process else {
                        fatalError("Request processor started before connect")
                    }
                    return (iterator, inputPipe, process)
                }

                guard process.isRunning else {
                    throw PTPError.notConnected
                }

                let id = self.queue.sync {
                    let current = self.transactionID
                    self.transactionID += 1
                    return current
                }

                var fullRequest: [String: Any] = [
                    "id": String(id),
                    "command": request.command
                ]
                for (key, value) in request.params {
                    fullRequest[key] = value
                }

                guard let data = try? JSONSerialization.data(withJSONObject: fullRequest),
                      let line = String(data: data, encoding: .utf8),
                      let lineData = (line + "\n").data(using: .utf8) else {
                    throw PTPError.invalidResponse("Failed to encode request")
                }

                inputPipe.fileHandleForWriting.write(lineData)

                guard let responseLine = try await iterator.next() else {
                    throw PTPError.invalidResponse("Helper closed stdout")
                }

                // Store the mutated iterator back (AsyncThrowingStream iterators
                // are value types that share read state via internal reference).
                self.queue.sync { self.lineIterator = iterator }

                guard let responseData = responseLine.data(using: String.Encoding.utf8),
                      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                    throw PTPError.invalidResponse("Failed to parse JSON: \(responseLine)")
                }

                request.continuation.resume(returning: ResponseBox(json))
            } catch {
                request.continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helper Discovery

    private func findHelper() -> String? {
        var possiblePaths: [String] = []

        // App bundle resources (macOS / iOS app sandbox).
        if let bundlePath = Bundle.main.resourcePath {
            possiblePaths.append(bundlePath + "/x100vi_helper")
        }

        // Development/project-relative search from this source file's directory.
        let sourceDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path
        possiblePaths.append("\(sourceDir)/poc-x100vi-reader/x100vi_helper")

        // System PATH lookup, plus common absolute locations.
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                possiblePaths.append("\(dir)/x100vi_helper")
            }
        }
        possiblePaths.append(contentsOf: [
            "/usr/local/bin/x100vi_helper",
            "/opt/homebrew/bin/x100vi_helper",
        ])

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
}

// MARK: - JSON Numeric Bridging Helpers

/// Extract a UInt32 from JSONSerialization output, which decodes numbers as
/// `Int`/`NSNumber` rather than Swift unsigned types.
private func jsonUInt32(_ value: Any?) -> UInt32? {
    if let int = value as? Int { return UInt32(int) }
    if let num = value as? NSNumber { return num.uint32Value }
    if let str = value as? String, let int = UInt32(str) { return int }
    return nil
}

/// Extract an Int32 from JSONSerialization output.
private func jsonInt32(_ value: Any?) -> Int32? {
    if let int = value as? Int { return Int32(int) }
    if let num = value as? NSNumber { return num.int32Value }
    if let str = value as? String, let int = Int32(str) { return int }
    return nil
}


