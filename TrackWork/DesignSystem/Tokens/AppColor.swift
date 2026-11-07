import SwiftUI

extension Color {
    enum ds {
        static let backgroundPrimary = Color("BackgroundPrimary")
        static let backgroundSecondary = Color("BackgroundSecondary")
        static let backgroundSoftBlue = Color("BackgroundSoftBlue")

        static let surfacePrimary = Color("SurfacePrimary")
        static let surfaceSecondary = Color("SurfaceSecondary")
        static let surfaceElevated = Color("SurfaceElevated")
        static let surfaceGlass = Color("SurfaceGlass")
        static let surfaceBlueTint = Color("SurfaceBlueTint")

        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        static let textInverse = Color("TextInverse")

        static let interactionPrimary = Color("InteractionPrimary")
        static let accentPrimary = Color("AccentPrimary")
        static let accentSecondary = Color("AccentSecondary")
        static let accentSoft = Color("AccentSoft")
        static let accentMuted = Color("AccentMuted")

        static let success = Color("Success")
        static let warning = Color("Warning")
        static let critical = Color("Critical")
        static let info = Color("Info")

        // Small chart marks use ink matched to each fill appearance and contrast setting.
        static let chartMarkInk = Color("ChartMarkInk")
        static let officeDay = Color("OfficeDay")
        // Dashed benchmark, distinct from attendance and warning/error states.
        static let requiredTarget = Color("RequiredTarget")
        static let homeDay = Color("HomeDay")
        static let leaveDay = Color("LeaveDay")
        static let publicHoliday = Color("PublicHoliday")
        static let complianceGood = Color("ComplianceGood")
        static let complianceWarning = Color("ComplianceWarning")
        static let complianceBad = Color("ComplianceBad")

        static let separator = Color("DSSeparator")
        static let borderSubtle = Color("BorderSubtle")
        static let shadowTint = Color("ShadowTint")
    }
}
