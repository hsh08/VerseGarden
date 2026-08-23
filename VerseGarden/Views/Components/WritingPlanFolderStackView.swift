import SwiftUI

struct WritingPlanFolderStackView: View {
    let plans: [ScriptureWritingPlan]
    let selectedPlan: ScriptureWritingPlan?
    var size: CGSize = CGSize(width: 70, height: 56)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WritingPlanFolderIcon(
                color: selectedPlan.map { folderColor(for: $0, index: selectedIndex) } ?? GardenTheme.primary.opacity(0.52),
                isSelected: true
            )
            .frame(width: size.width, height: size.height)

            if plans.count > 1 {
                Text("\(plans.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(GardenTheme.secondary)
                    .clipShape(Circle())
                    .offset(x: 6, y: -7)
            }
        }
        .frame(width: size.width + 8, height: size.height + 8, alignment: .center)
    }

    private var selectedIndex: Int {
        guard let selectedPlan,
              let index = plans.firstIndex(where: { $0.id == selectedPlan.id }) else {
            return 0
        }
        return index
    }
}

struct WritingPlanFolderIcon: View {
    let color: Color
    var isSelected = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(isSelected ? 0.96 : 0.76))
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(isSelected ? 0.92 : 0.70))
                        .frame(width: 28, height: 13)
                        .offset(x: 7, y: -5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.78 : 0.48), lineWidth: 1)
                }
                .shadow(color: color.opacity(isSelected ? 0.16 : 0.08), radius: 8, x: 0, y: 4)

            Image(systemName: "pencil.line")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(9)
        }
    }
}

func folderColor(for plan: ScriptureWritingPlan, index: Int) -> Color {
    if let folderColorRaw = plan.folderColorRaw,
       let folderColor = WritingPlanFolderColor(rawValue: folderColorRaw) {
        return folderColor.color
    }

    let palette: [Color] = [
        GardenTheme.primary,
        GardenTheme.tertiary,
        GardenTheme.secondary,
        Color(hex: 0x8FA9C7),
        Color(hex: 0xB89B72)
    ]
    let stableIndex = abs(plan.id.uuidString.hashValue + index) % palette.count
    return palette[stableIndex]
}
