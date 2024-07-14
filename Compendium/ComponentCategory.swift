//
//  ElectronicComponentType.swift
//  Compendium
//
//  Created by Purav Manot on 14/07/24.
//

import Foundation
import SwiftUIX

enum ComponentCategory: String, Codable {
    case passiveElements = "Passive Elements"
    case activeElements = "Active Elements"
    case electromechanicalDevices = "Electromechanical Devices"
    case sensingDevices = "Sensing Devices"
    case powerManagementDevices = "Power Management Devices"
    case connectivityHardware = "Connectivity Hardware"
    case displayTechnology = "Display Technology"
    case auxiliaryEquipment = "Auxiliary Equipment"
    case unknown = "Unknown"
    
    var symbolName: String {
        switch self {
            case .passiveElements:
                return "circle.lefthalf.fill"
            case .activeElements:
                return "cpu"
            case .electromechanicalDevices:
                return "hammer.fill"
            case .sensingDevices:
                return "sensor.tag.radiowaves.forward"
            case .powerManagementDevices:
                return "bolt.fill.batteryblock"
            case .connectivityHardware:
                return "cable.connector"
            case .displayTechnology:
                return "display"
            case .auxiliaryEquipment:
                return "gear"
            case .unknown:
                return "questionmark.circle.fill"
        }
    }
    
    var description: String {
        return self.rawValue
    }
}
