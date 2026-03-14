#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.riffit.app";

/// The "RiffitBackground" asset catalog color resource.
static NSString * const ACColorNameRiffitBackground AC_SWIFT_PRIVATE = @"RiffitBackground";

/// The "RiffitBorderDefault" asset catalog color resource.
static NSString * const ACColorNameRiffitBorderDefault AC_SWIFT_PRIVATE = @"RiffitBorderDefault";

/// The "RiffitBorderSubtle" asset catalog color resource.
static NSString * const ACColorNameRiffitBorderSubtle AC_SWIFT_PRIVATE = @"RiffitBorderSubtle";

/// The "RiffitDanger" asset catalog color resource.
static NSString * const ACColorNameRiffitDanger AC_SWIFT_PRIVATE = @"RiffitDanger";

/// The "RiffitDangerTint" asset catalog color resource.
static NSString * const ACColorNameRiffitDangerTint AC_SWIFT_PRIVATE = @"RiffitDangerTint";

/// The "RiffitElevated" asset catalog color resource.
static NSString * const ACColorNameRiffitElevated AC_SWIFT_PRIVATE = @"RiffitElevated";

/// The "RiffitPrimaryGhost" asset catalog color resource.
static NSString * const ACColorNameRiffitPrimaryGhost AC_SWIFT_PRIVATE = @"RiffitPrimaryGhost";

/// The "RiffitPrimaryText" asset catalog color resource.
static NSString * const ACColorNameRiffitPrimaryText AC_SWIFT_PRIVATE = @"RiffitPrimaryText";

/// The "RiffitPrimaryTint" asset catalog color resource.
static NSString * const ACColorNameRiffitPrimaryTint AC_SWIFT_PRIVATE = @"RiffitPrimaryTint";

/// The "RiffitSurface" asset catalog color resource.
static NSString * const ACColorNameRiffitSurface AC_SWIFT_PRIVATE = @"RiffitSurface";

/// The "RiffitTealTint" asset catalog color resource.
static NSString * const ACColorNameRiffitTealTint AC_SWIFT_PRIVATE = @"RiffitTealTint";

/// The "RiffitTextPrimary" asset catalog color resource.
static NSString * const ACColorNameRiffitTextPrimary AC_SWIFT_PRIVATE = @"RiffitTextPrimary";

/// The "RiffitTextSecondary" asset catalog color resource.
static NSString * const ACColorNameRiffitTextSecondary AC_SWIFT_PRIVATE = @"RiffitTextSecondary";

/// The "RiffitTextTertiary" asset catalog color resource.
static NSString * const ACColorNameRiffitTextTertiary AC_SWIFT_PRIVATE = @"RiffitTextTertiary";

#undef AC_SWIFT_PRIVATE
