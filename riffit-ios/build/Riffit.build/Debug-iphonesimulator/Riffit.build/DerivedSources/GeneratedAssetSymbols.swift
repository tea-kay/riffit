import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "RiffitBackground" asset catalog color resource.
    static let riffitBackground = DeveloperToolsSupport.ColorResource(name: "RiffitBackground", bundle: resourceBundle)

    /// The "RiffitBorderDefault" asset catalog color resource.
    static let riffitBorderDefault = DeveloperToolsSupport.ColorResource(name: "RiffitBorderDefault", bundle: resourceBundle)

    /// The "RiffitBorderSubtle" asset catalog color resource.
    static let riffitBorderSubtle = DeveloperToolsSupport.ColorResource(name: "RiffitBorderSubtle", bundle: resourceBundle)

    /// The "RiffitDanger" asset catalog color resource.
    static let riffitDanger = DeveloperToolsSupport.ColorResource(name: "RiffitDanger", bundle: resourceBundle)

    /// The "RiffitDangerTint" asset catalog color resource.
    static let riffitDangerTint = DeveloperToolsSupport.ColorResource(name: "RiffitDangerTint", bundle: resourceBundle)

    /// The "RiffitElevated" asset catalog color resource.
    static let riffitElevated = DeveloperToolsSupport.ColorResource(name: "RiffitElevated", bundle: resourceBundle)

    /// The "RiffitPrimaryGhost" asset catalog color resource.
    static let riffitPrimaryGhost = DeveloperToolsSupport.ColorResource(name: "RiffitPrimaryGhost", bundle: resourceBundle)

    /// The "RiffitPrimaryText" asset catalog color resource.
    static let riffitPrimaryText = DeveloperToolsSupport.ColorResource(name: "RiffitPrimaryText", bundle: resourceBundle)

    /// The "RiffitPrimaryTint" asset catalog color resource.
    static let riffitPrimaryTint = DeveloperToolsSupport.ColorResource(name: "RiffitPrimaryTint", bundle: resourceBundle)

    /// The "RiffitSurface" asset catalog color resource.
    static let riffitSurface = DeveloperToolsSupport.ColorResource(name: "RiffitSurface", bundle: resourceBundle)

    /// The "RiffitTealTint" asset catalog color resource.
    static let riffitTealTint = DeveloperToolsSupport.ColorResource(name: "RiffitTealTint", bundle: resourceBundle)

    /// The "RiffitTextPrimary" asset catalog color resource.
    static let riffitTextPrimary = DeveloperToolsSupport.ColorResource(name: "RiffitTextPrimary", bundle: resourceBundle)

    /// The "RiffitTextSecondary" asset catalog color resource.
    static let riffitTextSecondary = DeveloperToolsSupport.ColorResource(name: "RiffitTextSecondary", bundle: resourceBundle)

    /// The "RiffitTextTertiary" asset catalog color resource.
    static let riffitTextTertiary = DeveloperToolsSupport.ColorResource(name: "RiffitTextTertiary", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

