import SwiftUI

// MARK: - Foundation tokens

/// Semantic colours for VerseGarden's warm paper and restrained botanical palette.
/// Keep feature views on these roles rather than introducing new raw hex values.
enum AppColors {
    // Semantic release palette
    static let background = Color(hex: 0xFAF7EF)
    static let surface = Color(hex: 0xFFFDF8)
    static let surfaceSecondary = Color(hex: 0xF2F6EC)
    static let textPrimary = Color(hex: 0x1F241F)
    static let textSecondary = Color(hex: 0x697266)
    static let textTertiary = Color(hex: 0x929A8F)
    static let gardenPrimary = Color(hex: 0x6F8F72)
    static let gardenSecondary = Color(hex: 0x8FAA8A)
    static let gardenDeep = Color(hex: 0x2F4F3A)
    static let scriptureAccent = Color(hex: 0x8A6A4F)
    static let success = Color(hex: 0x4F7554)
    static let divider = Color(hex: 0xDDE7D7)
    static let destructive = Color(hex: 0xB94744)
    static let destructiveSurface = Color(hex: 0xFCE9E7)
    static let selected = Color(hex: 0xE7F0E3)
    static let scripturePaper = Color(hex: 0xF8F2E7)
    static let scripturePaperEdge = Color(hex: 0xEFE3D1)
    static let scriptureHighlight = Color(hex: 0xC9DCC0)
    static let oldTestamentText = Color(hex: 0x47684F)
    static let oldTestamentSurface = Color(hex: 0xEDF3E9)
    static let oldTestamentSelected = Color(hex: 0xDCE9D8)
    static let oldTestamentBorder = Color(hex: 0xC9DBC4)
    static let newTestamentText = Color(hex: 0x98655F)
    static let newTestamentSurface = Color(hex: 0xF8ECE9)
    static let newTestamentSelected = Color(hex: 0xEED9D4)
    static let newTestamentBorder = Color(hex: 0xE6C9C3)

    // Garden activity palette
    static let grassInactive = Color(hex: 0xE2E8E0)
    static let grassLevel1 = Color(hex: 0xBCCFBE)
    static let grassLevel2 = Color(hex: 0x7EA688)
    static let grassLevel3 = Color(hex: 0x2F855A)
    static let grassLevel4 = Color(hex: 0x14532D)
    static let warning = Color(hex: 0xB7791F)

    // Legacy names retained for gradual screen migration.
    static let primaryGreen = gardenPrimary
    static let deepGreen = gardenDeep
    static let forestGreen = success
    static let sageGreen = gardenSecondary
    static let softBrown = scriptureAccent
    static let cardBackground = surface
    static let cardTint = surfaceSecondary
    static let primaryText = textPrimary
    static let secondaryText = textSecondary
    static let subtleText = textTertiary
    static let border = divider
    static let destructiveRed = destructive
    static let destructiveFill = destructiveSurface
    static let primary = gardenPrimary
    static let secondary = gardenDeep
    static let accent = scriptureAccent
    static let muted = textTertiary
}

enum AppSpacing {
    static let xsmall: CGFloat = 6
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 18
    static let section: CGFloat = 24

    static let screenHorizontal: CGFloat = 20
    static let cardPadding: CGFloat = large
    static let compactElement: CGFloat = small
    static let editorPadding: CGFloat = medium
    static let bottomSheetPadding: CGFloat = large
    static let tabBarBottomPadding: CGFloat = 104
}

enum AppRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let card: CGFloat = 24
    static let large: CGFloat = 28
    static let button: CGFloat = 22

    static let control = medium
    static let sheet = large
}

enum AppTypography {
    static let screenTitle = Font.largeTitle.weight(.bold)
    static let navigationTitle = Font.headline.weight(.semibold)
    static let sectionTitle = Font.title3.weight(.bold)
    static let cardTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let description = Font.subheadline
    static let caption = Font.caption.weight(.semibold)
    static let button = Font.headline.weight(.semibold)

    // Korean long-form reading is clearest in the platform's native sans treatment.
    static let scripture = Font.body.weight(.regular)
    static let scriptureVerseNumber = Font.caption2.weight(.medium)
    static let scriptureReference = Font.subheadline.weight(.semibold)
    static let scriptureLineSpacing: CGFloat = 7
}

enum AppShadows {
    static let cardColor = AppColors.gardenDeep.opacity(0.045)
    static let cardRadius: CGFloat = 8
    static let cardY: CGFloat = 3
    static let elevatedColor = AppColors.gardenDeep.opacity(0.07)
    static let elevatedRadius: CGFloat = 12
    static let elevatedY: CGFloat = 5
}

/// Legacy feature-facing theme. New shared components use `AppColors` semantic roles.
enum GardenTheme {
    static let primary = AppColors.gardenPrimary
    static let secondary = AppColors.gardenDeep
    static let tertiary = AppColors.scriptureAccent
    static let background = AppColors.background
    static let cardBackground = AppColors.surface
    static let softFill = AppColors.surfaceSecondary
    static let softStroke = AppColors.divider
    static let mutedSuccess = AppColors.success
    static let heatmapZero = AppColors.grassInactive
    static let heatmapLow = AppColors.grassLevel1
    static let heatmapMid = AppColors.grassLevel2
    static let heatmapHigh = AppColors.grassLevel4
    static let cornerRadius: CGFloat = AppRadius.card
    static let innerPadding: CGFloat = AppSpacing.cardPadding
    static let sectionSpacing: CGFloat = AppSpacing.section
}

// MARK: - Surfaces

enum VGCardStyle {
    case standard
    case secondary
    case selected

    fileprivate var background: Color {
        switch self {
        case .standard: AppColors.surface
        case .secondary: AppColors.surfaceSecondary
        case .selected: AppColors.selected
        }
    }

    fileprivate var border: Color {
        switch self {
        case .standard: AppColors.divider.opacity(0.72)
        case .secondary: AppColors.divider.opacity(0.52)
        case .selected: AppColors.gardenPrimary.opacity(0.34)
        }
    }
}

struct VGCard<Content: View>: View {
    let content: Content
    var style: VGCardStyle
    var accentGradient: LinearGradient?

    init(
        style: VGCardStyle = .standard,
        accentGradient: LinearGradient? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.accentGradient = accentGradient
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.cardPadding)
            .background {
                ZStack {
                    style.background
                    if let accentGradient {
                        accentGradient.opacity(0.18)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(style.border, lineWidth: 0.8)
            }
            .shadow(color: AppShadows.cardColor, radius: AppShadows.cardRadius, x: 0, y: AppShadows.cardY)
    }
}

/// Backwards-compatible name used by existing feature screens.
typealias GardenCard<Content: View> = VGCard<Content>

private struct VGCardSurfaceModifier: ViewModifier {
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
        background: Color = AppColors.surface,
        border: Color = AppColors.divider.opacity(0.72),
        cornerRadius: CGFloat = AppRadius.card,
        shadowColor: Color = AppShadows.cardColor,
        shadowRadius: CGFloat = AppShadows.cardRadius,
        shadowY: CGFloat = AppShadows.cardY
    ) -> some View {
        modifier(
            VGCardSurfaceModifier(
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

// MARK: - Text and scripture

struct VGSectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.description)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

typealias GardenSectionHeader = VGSectionHeader

/// A scripture context surface for Home, Prayer, QT, Profile, and saved content.
/// It intentionally does not model reader rows or navigation.
struct VGVerseCard: View {
    let reference: String
    let text: String
    var isCompact = false

    init(reference: String, text: String, isCompact: Bool = false) {
        self.reference = reference
        self.text = text
        self.isCompact = isCompact
    }

    var body: some View {
        VGCard(style: .secondary) {
            VStack(alignment: .leading, spacing: isCompact ? AppSpacing.small : AppSpacing.medium) {
                Text(reference)
                    .font(AppTypography.scriptureReference)
                    .foregroundStyle(AppColors.scriptureAccent)

                Text(text)
                    .font(isCompact ? AppTypography.description : AppTypography.scripture)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(isCompact ? 4 : AppTypography.scriptureLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct GardenStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    var accent: Color = GardenTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.description)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.medium)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
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
        VGCard(accentGradient: accentGradient) {
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
        VGSectionHeader(title, subtitle: subtitle)
    }
}

// MARK: - Buttons

struct VGButtonLabel: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let foreground: Color

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            if isLoading {
                ProgressView()
                    .tint(foreground)
            } else if let icon {
                Image(systemName: icon)
                    .font(.title3)
            }

            Text(title)
                .font(AppTypography.button)
            Spacer(minLength: 0)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, AppSpacing.large)
    }
}

struct VGPrimaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VGButtonLabel(title: title, icon: icon, isLoading: isLoading, foreground: .white)
                .background(
                    LinearGradient(
                        colors: [AppColors.gardenPrimary, AppColors.gardenDeep.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                .shadow(color: AppShadows.elevatedColor, radius: AppShadows.elevatedRadius, x: 0, y: AppShadows.elevatedY)
                .opacity(disabled || isLoading ? 0.62 : 1)
        }
        .disabled(disabled || isLoading)
        .buttonStyle(GardenAccentButtonStyle())
        .accessibilityLabel(title)
    }
}

struct VGSecondaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VGButtonLabel(
                title: title,
                icon: icon,
                isLoading: isLoading,
                foreground: disabled || isLoading ? AppColors.textTertiary : AppColors.gardenPrimary
            )
            .background(disabled || isLoading ? AppColors.grassInactive.opacity(0.55) : AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(disabled || isLoading ? AppColors.divider.opacity(0.5) : AppColors.divider, lineWidth: 1)
            }
        }
        .disabled(disabled || isLoading)
        .buttonStyle(GardenAccentButtonStyle())
        .accessibilityLabel(title)
    }
}

struct VGDestructiveButton: View {
    let title: String
    var icon: String?
    var disabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            VGButtonLabel(title: title, icon: icon, isLoading: isLoading, foreground: AppColors.destructive)
                .background(AppColors.destructiveSurface.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                        .stroke(AppColors.destructive.opacity(0.2), lineWidth: 1)
                }
                .opacity(disabled || isLoading ? 0.62 : 1)
        }
        .disabled(disabled || isLoading)
        .buttonStyle(GardenAccentButtonStyle())
        .accessibilityLabel(title)
    }
}

/// Legacy component names retained so later phases can migrate screens independently.
typealias GardenPrimaryButton = VGPrimaryButton
typealias SecondaryButton = VGSecondaryButton
typealias DestructiveButton = VGDestructiveButton

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var disabled = false
    let action: () -> Void

    var body: some View {
        VGPrimaryButton(title: title, icon: icon, disabled: disabled, action: action)
    }
}

struct GardenPrimaryButtonLabel: View {
    let title: String
    let icon: String?

    var body: some View {
        VGButtonLabel(title: title, icon: icon, isLoading: false, foreground: .white)
            .background(
                LinearGradient(
                    colors: [AppColors.gardenPrimary, AppColors.gardenDeep.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .shadow(color: AppShadows.elevatedColor, radius: AppShadows.elevatedRadius, x: 0, y: AppShadows.elevatedY)
    }
}

// MARK: - Inputs and states

struct AppInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .padding(AppSpacing.editorPadding)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .stroke(isFocused ? AppColors.gardenPrimary.opacity(0.48) : AppColors.divider, lineWidth: 1)
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
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .padding(AppSpacing.compactElement)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .stroke(isFocused ? AppColors.gardenPrimary.opacity(0.48) : AppColors.divider, lineWidth: 1)
                }
        }
    }
}

struct VGEmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColors.gardenPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceSecondary)
                .clipShape(Circle())
            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(message)
                .font(AppTypography.description)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.cardPadding)
    }
}

typealias EmptyStateView = VGEmptyStateView

struct GardenAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
