#!/usr/bin/env swift

import Foundation

enum SignError: LocalizedError {
    case usage
    case invalidApp(String)
    case missingBundleIdentifier
    case invalidBundleIdentifier(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "usage: sign-local-app.swift APP_PATH"
        case .invalidApp(let path):
            return "app bundle not found: \(path)"
        case .missingBundleIdentifier:
            return "app bundle has no CFBundleIdentifier"
        case .invalidBundleIdentifier(let identifier):
            return "app bundle has an invalid CFBundleIdentifier: \(identifier)"
        case .commandFailed(let message):
            return message
        }
    }
}

func run(_ arguments: [String]) throws {
    let process = Process()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = arguments
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let output = String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? "codesign failed"
        throw SignError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

func sign(appPath: String) throws {
    let app = URL(fileURLWithPath: appPath).standardizedFileURL
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: app.path, isDirectory: &isDirectory),
          isDirectory.boolValue,
          app.pathExtension == "app" else {
        throw SignError.invalidApp(app.path)
    }

    let infoURL = app.appendingPathComponent("Contents/Info.plist")
    guard let info = NSDictionary(contentsOf: infoURL),
          let bundleIdentifier = info["CFBundleIdentifier"] as? String,
          !bundleIdentifier.isEmpty else {
        throw SignError.missingBundleIdentifier
    }

    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
    guard bundleIdentifier.unicodeScalars.allSatisfy(allowed.contains) else {
        throw SignError.invalidBundleIdentifier(bundleIdentifier)
    }

    let requirement = "=designated => identifier \"\(bundleIdentifier)\""
    try run([
        "--force",
        "--sign", "-",
        "--requirements", requirement,
        "--preserve-metadata=entitlements,flags",
        app.path
    ])
    try run(["--verify", "--deep", "--strict", app.path])
}

do {
    guard CommandLine.arguments.count == 2 else {
        throw SignError.usage
    }
    try sign(appPath: CommandLine.arguments[1])
} catch {
    FileHandle.standardError.write(Data("local signing failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
