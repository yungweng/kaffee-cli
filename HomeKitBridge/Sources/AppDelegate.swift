import UIKit
import HomeKit

struct BridgePaths {
    let commandURL: URL
    let outputURL: URL

    static func resolve(from arguments: [String] = CommandLine.arguments) -> BridgePaths {
        let commandURL: URL
        let outputURL: URL

        if arguments.count >= 3 {
            commandURL = URL(fileURLWithPath: arguments[1])
            outputURL = URL(fileURLWithPath: arguments[2])
        } else {
            commandURL = URL(fileURLWithPath: "/tmp/homekit-bridge-command.json")
            outputURL = URL(fileURLWithPath: "/tmp/homekit-bridge-output.json")
        }

        return BridgePaths(commandURL: commandURL, outputURL: outputURL)
    }
}

// MARK: - Command parsing

enum Command {
    case list
    case get(deviceName: String)
    case set(deviceName: String, on: Bool)
    case toggle(deviceName: String)

    static func parse(commandURL: URL) -> Command {
        guard let data = try? Data(contentsOf: commandURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else {
            return .list
        }

        let device = json["device"] as? String ?? ""

        switch action {
        case "get":
            return .get(deviceName: device)
        case "set":
            let on = json["value"] as? Bool ?? true
            return .set(deviceName: device, on: on)
        case "toggle":
            return .toggle(deviceName: device)
        default:
            return .list
        }
    }
}

// MARK: - Output

func writeOutput(_ dict: [String: Any], to outputURL: URL) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
          let str = String(data: data, encoding: .utf8) else { return }
    try? str.write(to: outputURL, atomically: true, encoding: .utf8)
}

func log(_ msg: String) {
    FileHandle.standardError.write(Data("[HomeKitBridge] \(msg)\n".utf8))
}

// MARK: - App

@main
class AppDelegate: UIResponder, UIApplicationDelegate, HMHomeManagerDelegate {

    private var homeManager: HMHomeManager?
    private var command: Command = .list
    private let paths = BridgePaths.resolve()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        command = Command.parse(commandURL: paths.commandURL)
        log("Command: \(command)")
        homeManager = HMHomeManager()
        homeManager?.delegate = self

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            writeOutput(["error": "timeout", "message": "No HomeKit response after 10s"], to: self.paths.outputURL)
            exit(1)
        }
        return true
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        log("Homes loaded: \(manager.homes.count)")

        let homes = manager.homes

        guard !homes.isEmpty else {
            writeOutput(["error": "no_homes"], to: paths.outputURL)
            exit(1)
        }

        switch command {
        case .list:
            handleList(homes: homes)
        case .get(let name):
            handleGet(homes: homes, deviceName: name)
        case .set(let name, let on):
            handleSet(homes: homes, deviceName: name, on: on)
        case .toggle(let name):
            handleToggle(homes: homes, deviceName: name)
        }
    }

    // MARK: - Handlers

    private func handleList(homes: [HMHome]) {
        struct DeviceSnapshot {
            let sortKey: String
            let payload: [String: Any]
        }

        let candidates = homes.flatMap { home in
            home.accessories.compactMap { accessory -> (HMHome, HMAccessory, HMService, HMCharacteristic, String)? in
                guard let (service, characteristic) = findPowerState(accessory: accessory) else { return nil }
                let room = home.rooms.first { $0.accessories.contains(accessory) }
                return (home, accessory, service, characteristic, room?.name ?? "Default Room")
            }
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var snapshots: [DeviceSnapshot] = []
        var readFailures: [[String: Any]] = []

        for (home, accessory, service, characteristic, roomName) in candidates {
            group.enter()
            characteristic.readValue { error in
                var payload: [String: Any] = [
                    "home": home.name,
                    "name": accessory.name,
                    "room": roomName,
                    "reachable": accessory.isReachable,
                    "serviceType": service.serviceType
                ]

                if let error = error {
                    payload["on"] = NSNull()
                    payload["readError"] = error.localizedDescription
                } else {
                    payload["on"] = characteristic.value as? Bool ?? false
                }

                let snapshot = DeviceSnapshot(
                    sortKey: "\(home.name)\u{0}\(roomName)\u{0}\(accessory.name)",
                    payload: payload
                )

                lock.lock()
                snapshots.append(snapshot)
                if let error = error {
                    readFailures.append([
                        "home": home.name,
                        "name": accessory.name,
                        "room": roomName,
                        "message": error.localizedDescription
                    ])
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let devices = snapshots
                .sorted { $0.sortKey < $1.sortKey }
                .map(\.payload)
            writeOutput(["ok": true, "devices": devices, "readFailures": readFailures], to: self.paths.outputURL)
            exit(0)
        }
    }

    private func handleGet(homes: [HMHome], deviceName: String) {
        guard let match = findAccessory(homes: homes, name: deviceName) else {
            exit(1)
        }
        guard let (_, char) = findPowerState(accessory: match.accessory) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"], to: paths.outputURL)
            exit(1)
        }

        char.readValue { error in
            if let error = error {
                writeOutput(["error": "read_failed", "message": error.localizedDescription], to: self.paths.outputURL)
                exit(1)
            }
            let on = char.value as? Bool ?? false
            writeOutput(
                ["ok": true, "device": deviceName, "home": match.home.name, "room": match.roomName, "on": on],
                to: self.paths.outputURL
            )
            exit(0)
        }
    }

    private func handleSet(homes: [HMHome], deviceName: String, on: Bool) {
        guard let match = findAccessory(homes: homes, name: deviceName) else {
            exit(1)
        }
        guard let (_, char) = findPowerState(accessory: match.accessory) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"], to: paths.outputURL)
            exit(1)
        }

        char.writeValue(on) { error in
            if let error = error {
                writeOutput(["error": "write_failed", "message": error.localizedDescription], to: self.paths.outputURL)
                exit(1)
            }
            writeOutput(
                ["ok": true, "device": deviceName, "home": match.home.name, "room": match.roomName, "on": on],
                to: self.paths.outputURL
            )
            exit(0)
        }
    }

    private func handleToggle(homes: [HMHome], deviceName: String) {
        guard let match = findAccessory(homes: homes, name: deviceName) else {
            exit(1)
        }
        guard let (_, char) = findPowerState(accessory: match.accessory) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"], to: paths.outputURL)
            exit(1)
        }

        char.readValue { error in
            if let error = error {
                writeOutput(["error": "read_failed", "message": error.localizedDescription], to: self.paths.outputURL)
                exit(1)
            }
            let currentOn = char.value as? Bool ?? false
            let newOn = !currentOn
            char.writeValue(newOn) { error in
                if let error = error {
                    writeOutput(["error": "write_failed", "message": error.localizedDescription], to: self.paths.outputURL)
                    exit(1)
                }
                writeOutput(
                    [
                        "ok": true,
                        "device": deviceName,
                        "home": match.home.name,
                        "room": match.roomName,
                        "on": newOn,
                        "toggled": true
                    ],
                    to: self.paths.outputURL
                )
                exit(0)
            }
        }
    }

    // MARK: - Helpers

    private struct AccessoryMatch {
        let home: HMHome
        let accessory: HMAccessory
        let roomName: String
    }

    private func findAccessory(homes: [HMHome], name: String) -> AccessoryMatch? {
        let lower = name.lowercased()
        let matches = homes.flatMap { home in
            home.accessories.compactMap { accessory -> AccessoryMatch? in
                guard accessory.name.lowercased() == lower else { return nil }
                let room = home.rooms.first { $0.accessories.contains(accessory) }
                return AccessoryMatch(
                    home: home,
                    accessory: accessory,
                    roomName: room?.name ?? "Default Room"
                )
            }
        }

        if matches.isEmpty {
            writeOutput(["error": "not_found", "message": "Device '\(name)' not found"], to: paths.outputURL)
            return nil
        }

        if matches.count > 1 {
            let locations = matches.map { "\($0.home.name) / \($0.roomName)" }
            writeOutput(
                [
                    "error": "ambiguous_device",
                    "message": "Device '\(name)' matches multiple accessories",
                    "matches": locations
                ],
                to: paths.outputURL
            )
            return nil
        }

        return matches[0]
    }

    /// Find the Outlet/Switch/Lightbulb service with a Power State characteristic
    private func findPowerState(accessory: HMAccessory) -> (HMService, HMCharacteristic)? {
        // HAP type 0x25 = Power State
        let powerStateType = "00000025-0000-1000-8000-0026BB765291"
        for service in accessory.services {
            if let char = service.characteristics.first(where: { $0.characteristicType == powerStateType }) {
                return (service, char)
            }
        }
        return nil
    }
}
