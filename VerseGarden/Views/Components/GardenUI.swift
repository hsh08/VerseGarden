import SwiftUI

enum AppColors {
    static let primaryGreen = Color(hex: 0x6F8F72)
    static let deepGreen = Color(hex: 0x2F4F3A)
    static let forestGreen = Color(hex: 0x4F7554)
    static let sageGreen = Color(hex: 0x8FAA8A)
    static let softBrown = Color(hex: 0x8A6A4F)
    static let background = Color(hex: 0xFAF7EF)
    static let cardBackground = Color(hex: 0xFFFDF8)
    static let cardTint = Color(hex: 0xF2F6EC)
    static let primaryText = Color(hex: 0x1F241F)
    static let secondaryText = Color(hex: 0x697266)
    static let subtleText = Color(hex: 0x929A8F)
    static let border = Color(hex: 0xDDE7D7)
    static let destructiveRed = Color(hex: 0xDC2626)
    static let destructiveFill = Color(hex: 0xFEE2E2)
    static let grassInactive = Color(hex: 0xE2E8E0)
    static let grassLevel1 = Color(hex: 0xBCCFBE)
    static let grassLevel2 = Color(hex: 0x7EA688)
    static let grassLevel3 = Color(hex: 0x2F855A)
    static let grassLevel4 = Color(hex: 0x14532D)

    static let surface = cardBackground
    static let primary = primaryGreen
    static let secondary = deepGreen
    static let accent = softBrown
    static let textPrimary = primaryText
    static let textSecondary = secondaryText
    static let muted = subtleText
    static let success = forestGreen
    static let warning = Color(hex: 0xB7791F)
}

enum AppSpacing {
    static let xsmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 18
    static let section: CGFloat = 24
    static let screenHorizontal: CGFloat = 20
    static let tabBarBottomPadding: CGFloat = 104
}

enum AppRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let card: CGFloat = 24
    static let large: CGFloat = 28
    static let button: CGFloat = 22
}

enum AppTypography {
    static let sectionTitle = Font.title3.bold()
    static let cardTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let description = Font.subheadline
    static let caption = Font.caption.weight(.semibold)
}

enum AppShadows {
    static let cardColor = AppColors.deepGreen.opacity(0.06)
    static let cardRadius: CGFloat = 12
    static let cardY: CGFloat = 6
    static let elevatedColor = AppColors.deepGreen.opacity(0.09)
    static let elevatedRadius: CGFloat = 18
    static let elevatedY: CGFloat = 8
}

enum GardenTheme {
    static let primary = AppColors.primaryGreen
    static let secondary = AppColors.deepGreen
    static let tertiary = AppColors.softBrown
    static let background = AppColors.background
    static let cardBackground = AppColors.cardBackground
    static let softFill = AppColors.cardTint
    static let softStroke = AppColors.border
    static let mutedSuccess = AppColors.forestGreen
    static let heatmapZero = AppColors.grassInactive
    static let heatmapLow = AppColors.grassLevel1
    static let heatmapMid = AppColors.grassLevel2
    static let heatmapHigh = AppColors.grassLevel4
    static let cornerRadius: CGFloat = AppRadius.card
    static let innerPadding: CGFloat = AppSpacing.large
    static let sectionSpacing: CGFloat = AppSpacing.section
}

struct GardenCard<Content: View>: View {
    let content: Content
    var accentGradient: LinearGradient?

    init(accentGradient: LinearGradient? = nil, @ViewBuilder content: () -> Content) {
        self.accentGradient = accentGradient
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GardenTheme.innerPadding)
            .background(
                ZStack {
                    GardenTheme.cardBackground
                    if let accentGradient {
                        accentGradient.opacity(0.22)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: GardenTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GardenTheme.cornerRadius, style: .continuous)
                    .stroke(AppColors.border.opacity(0.72), lineWidth: 0.8)
            }
            .shadow(color: AppShadows.cardColor, radius: AppShadows.cardRadius, x: 0, y: AppShadows.cardY)
    }
}

typealias VGCard<Content: View> = GardenCard<Content>

private struct GardenCardSurfaceModifier: ViewModifier {
    let background: Color
    let border: Color
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 0.8)
            }
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
}

extension View {
    func gardenCardSurface(
        background: Color = GardenTheme.cardBackground,
        border: Color = AppColors.border.opacity(0.72),
        cornerRadius: CGFloat = GardenTheme.cornerRadius,
        shadowColor: Color = AppShadows.cardColor,
        shadowRadius: CGFloat = AppShadows.cardRadius,
        shadowY: CGFloat = AppShadows.cardY
    ) -> some View {
        modifier(
            GardenCardSurfaceModifier(
                background: background,
                border: border,
                cornerRadius: cornerRadius,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius,
                shadowY: shadowY
            )
        )
    }
}

struct GardenSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.description)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}

typealias VGSectionHeader = GardenSectionHeader

struct GardenStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    var accent: Color = GardenTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AppCard<Content: View>: View {
    let content: Content
    var accentGradient: LinearGradient?

    init(accentGradient: LinearGradient? = nil, @ViewBuilder content: () -> Content) {
        self.accentGradient = accentGradient
        self.content = content()
    }

    var body: some View {
        GardenCard(accentGradient: accentGradient) {
            content
        }
    }
}

struct AppSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        GardenSectionHeader(title, subtitle: subtitle)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        GardenPrimaryButton(title: title, icon: icon, disabled: disabled, action: action)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                }
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(disabled ? AppColors.subtleText : GardenTheme.primary)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(disabled ? AppColors.grassInactive.opacity(0.55) : GardenTheme.softFill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(disabled ? AppColors.border.opacity(0.5) : GardenTheme.softStroke, lineWidth: 1)
            }
        }
        .disabled(disabled)
        .buttonStyle(GardenAccentButtonStyle())
    }
}

typealias VGSecondaryButton = SecondaryButton

struct DestructiveButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                }
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(AppColors.destructiveRed)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(AppColors.destructiveFill.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.destructiveRed.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(GardenAccentButtonStyle())
    }
}

struct AppInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .padding(14)
                .background(GardenTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(isFocused ? GardenTheme.primary.opacity(0.48) : AppColors.border, lineWidth: 1)
                }
        }
    }
}

struct AppTextArea: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 140
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(GardenTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(isFocused ? GardenTheme.primary.opacity(0.48) : AppColors.border, lineWidth: 1)
                }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 44, height: 44)
                .background(GardenTheme.softFill)
                .clipShape(Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.large)
    }
}

typealias VGEmptyStateView = EmptyStateView

struct GardenAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct GardenPrimaryButtonLabel: View {
    let title: String
    let icon: String?

    var body: some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
            }
            Text(title)
                .font(.headline)
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(minHeight: 54)
        .padding(.horizontal, 18)
        .background(
            LinearGradient(
                colors: [GardenTheme.primary, GardenTheme.secondary.opacity(0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .shadow(color: AppShadows.elevatedColor, radius: 10, x: 0, y: 5)
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct GardenPrimaryButton: View {
    let title: String
    let icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GardenPrimaryButtonLabel(title: title, icon: icon)
                .opacity(disabled ? 0.65 : 1)
        }
        .disabled(disabled)
        .buttonStyle(GardenAccentButtonStyle())
    }
}

typealias VGPrimaryButton = GardenPrimaryButton
