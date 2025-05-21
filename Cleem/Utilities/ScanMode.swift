import Foundation
import SwiftUI

// Camera scanning modes for ScanCameraView
public enum UtilityCameraMode {
    case food
    case barcode
    case label
    case gallery
}

// Scanning modes for FoodScanViewModel
public enum FoodScanMode: String {
    case normal
    case barcode
    case label
    case gallery
}

// Scanning modes for generic scanning operations
public enum AppScanMode {
    case food
    case barcode
    case label
    case gallery
    case nutrition
} 