import UIKit
import HomeKit

// MARK: - Command parsing

enum Command {
    case list
    case get(deviceName: String)
    case set(deviceName: String, on: Bool)
    case toggle(deviceName: String)

    static func parse() -> Command {
        // Read command from file (since `open --args` is unreliable for Catalyst)
        let commandFile = "/tmp/homekit-bridge-command.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: commandFile)),
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

func writeOutput(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
          let str = String(data: data, encoding: .utf8) else { return }
    let outputPath = "/tmp/homekit-bridge-output.json"
    try? str.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

func log(_ msg: String) {
    FileHandle.standardError.write(Data("[HomeKitBridge] \(msg)\n".utf8))
}

// MARK: - App

@main
class AppDelegate: UIResponder, UIApplicationDelegate, HMHomeManagerDelegate {

    private var homeManager: HMHomeManager?
    private var command: Command = .list

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        command = Command.parse()
        log("Command: \(command)")
        homeManager = HMHomeManager()
        homeManager?.delegate = self

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            writeOutput(["error": "timeout", "message": "No HomeKit response after 10s"])
            exit(1)
        }
        return true
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        log("Homes loaded: \(manager.homes.count)")

        guard let home = manager.homes.first else {
            writeOutput(["error": "no_homes"])
            exit(1)
            return
        }

        switch command {
        case .list:
            handleList(home: home)
        case .get(let name):
            handleGet(home: home, deviceName: name)
        case .set(let name, let on):
            handleSet(home: home, deviceName: name, on: on)
        case .toggle(let name):
            handleToggle(home: home, deviceName: name)
        }
    }

    // MARK: - Handlers

    private func handleList(home: HMHome) {
        let devices: [[String: Any]] = home.accessories.compactMap { acc in
            guard let (svc, char) = findPowerState(accessory: acc) else { return nil }
            let room = home.rooms.first { $0.accessories.contains(acc) }
            return [
                "name": acc.name,
                "room": room?.name ?? "Default Room",
                "on": char.value as? Bool ?? false,
                "reachable": acc.isReachable,
                "serviceType": svc.serviceType
            ]
        }
        writeOutput(["ok": true, "devices": devices])
        exit(0)
    }

    private func handleGet(home: HMHome, deviceName: String) {
        guard let acc = findAccessory(home: home, name: deviceName) else {
            writeOutput(["error": "not_found", "message": "Device '\(deviceName)' not found"])
            exit(1)
            return
        }
        guard let (_, char) = findPowerState(accessory: acc) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"])
            exit(1)
            return
        }

        char.readValue { error in
            if let error = error {
                writeOutput(["error": "read_failed", "message": error.localizedDescription])
                exit(1)
            }
            let on = char.value as? Bool ?? false
            writeOutput(["ok": true, "device": deviceName, "on": on])
            exit(0)
        }
    }

    private func handleSet(home: HMHome, deviceName: String, on: Bool) {
        guard let acc = findAccessory(home: home, name: deviceName) else {
            writeOutput(["error": "not_found", "message": "Device '\(deviceName)' not found"])
            exit(1)
            return
        }
        guard let (_, char) = findPowerState(accessory: acc) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"])
            exit(1)
            return
        }

        char.writeValue(on) { error in
            if let error = error {
                writeOutput(["error": "write_failed", "message": error.localizedDescription])
                exit(1)
            }
            writeOutput(["ok": true, "device": deviceName, "on": on])
            exit(0)
        }
    }

    private func handleToggle(home: HMHome, deviceName: String) {
        guard let acc = findAccessory(home: home, name: deviceName) else {
            writeOutput(["error": "not_found", "message": "Device '\(deviceName)' not found"])
            exit(1)
            return
        }
        guard let (_, char) = findPowerState(accessory: acc) else {
            writeOutput(["error": "no_power_state", "message": "'\(deviceName)' has no Power State"])
            exit(1)
            return
        }

        char.readValue { error in
            if let error = error {
                writeOutput(["error": "read_failed", "message": error.localizedDescription])
                exit(1)
            }
            let currentOn = char.value as? Bool ?? false
            let newOn = !currentOn
            char.writeValue(newOn) { error in
                if let error = error {
                    writeOutput(["error": "write_failed", "message": error.localizedDescription])
                    exit(1)
                }
                writeOutput(["ok": true, "device": deviceName, "on": newOn, "toggled": true])
                exit(0)
            }
        }
    }

    // MARK: - Helpers

    private func findAccessory(home: HMHome, name: String) -> HMAccessory? {
        let lower = name.lowercased()
        return home.accessories.first { $0.name.lowercased() == lower }
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
