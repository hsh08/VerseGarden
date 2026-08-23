import Photos
import SwiftUI
import UIKit

struct ShareCardStats {
    let monthTitle: String
    let todayCount: Int
    let streak: Int
    let monthTotalCount: Int
}

struct ShareCardDayData: Identifiable {
    let id: String
    let dayNumber: Int?
    let count: Int
    let isToday: Bool
    let isPlaceholder: Bool
}

struct MonthlyShareCardView: View {
    let stats: ShareCardStats
    let weekdaySymbols: [String]
    let heatmap: [ShareCardDayData]

    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    @State private var alertMessage: String?
    @State private var availableCardWidth: CGFloat = 360
    @Environment(\.displayScale) private var displayScale

    private let previewHorizontalPadding: CGFloat = 24
    private let exportWidth: CGFloat = 1080
    private let exportHeight: CGFloat = 1920

    private var previewWidth: CGFloat {
        max(min(availableCardWidth - (previewHorizontalPadding * 2), 320), 260)
    }

    private var previewScale: CGFloat {
        previewWidth / exportWidth
    }

    private var previewHeight: CGFloat {
        exportHeight * previewScale
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    shareCardContent
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, previewHorizontalPadding)
                .padding(.bottom, max(112, proxy.safeAreaInsets.bottom + 96))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("공유용 카드")
            .navigationBarTitleDisplayMode(.inline)
            .background(GardenTheme.background)
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, previewHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, max(20, proxy.safeAreaInsets.bottom + 12))
                    .background(GardenTheme.background)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
            .alert("안내", isPresented: alertBinding) {
                Button("확인", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                availableCardWidth = proxy.size.width
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                availableCardWidth = newWidth
            }
        }
    }

    private var shareCardContent: some View {
        ShareCardView(
            monthTitle: stats.monthTitle,
            weekdaySymbols: weekdaySymbols,
            heatmap: heatmap,
            todayCount: stats.todayCount,
            currentStreak: stats.streak,
            monthTotalCount: stats.monthTotalCount
        )
        .frame(width: exportWidth, height: exportHeight)
        .scaleEffect(previewScale, anchor: .top)
        .frame(width: previewWidth, height: previewHeight, alignment: .top)
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                saveImageToPhotos()
            } label: {
                Text("이미지 저장")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GardenTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                shareCardImage()
            } label: {
                Text("공유하기")
                    .font(.headline)
                    .foregroundStyle(GardenTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GardenTheme.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: exportCardContent)
        renderer.proposedSize = ProposedViewSize(width: exportWidth, height: exportHeight)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    private var exportCardContent: some View {
        ShareCardView(
            monthTitle: stats.monthTitle,
            weekdaySymbols: weekdaySymbols,
            heatmap: heatmap,
            todayCount: stats.todayCount,
            currentStreak: stats.streak,
            monthTotalCount: stats.monthTotalCount
        )
        .frame(width: exportWidth, height: exportHeight)
    }

    private func shareCardImage() {
        if let shareImage {
            self.shareImage = shareImage
            showingShareSheet = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let image = renderImage() else {
                alertMessage = "공유 이미지를 만드는 데 실패했습니다."
                return
            }

            shareImage = image
            showingShareSheet = true
        }
    }

    private func saveImageToPhotos() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let image = shareImage ?? renderImage() else {
                alertMessage = "저장 이미지를 만드는 데 실패했습니다."
                return
            }

            shareImage = image

            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        alertMessage = "사진 보관함에 저장했습니다."
                    case .denied, .restricted:
                        alertMessage = "사진 저장 권한이 필요합니다. 설정에서 사진 접근을 허용해 주세요."
                    case .notDetermined:
                        alertMessage = "사진 권한 확인 후 다시 시도해 주세요."
                    @unknown default:
                        alertMessage = "사진 저장 권한 상태를 확인할 수 없습니다."
                    }
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }
}

private struct ShareCardView: View {
    let monthTitle: String
    let weekdaySymbols: [String]
    let heatmap: [ShareCardDayData]
    let todayCount: Int
    let currentStreak: Int
    let monthTotalCount: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 18), count: 7)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.cardTint,
                    GardenTheme.background,
                    AppColors.grassLevel1.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.clear],
                    center: .topTrailing,
                    startRadius: 40,
                    endRadius: 520
                )
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("VerseGarden")
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                    Text(monthTitle)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(GardenTheme.primary.opacity(0.10))
                        .blur(radius: 36)
                        .padding(40)

                    VStack(alignment: .leading, spacing: 24) {
                        Text("이번 달 잔디")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))

                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            }

                            ForEach(heatmap) { day in
                                if !day.isPlaceholder, let dayNumber = day.dayNumber {
                                    ShareGrassCell(
                                        dayNumber: dayNumber,
                                        count: day.count,
                                        isToday: day.isToday
                                    )
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.clear)
                                        .frame(height: 112)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 34)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 44)

                HStack(spacing: 18) {
                    ShareStatCard(title: "오늘 필사", value: "\(todayCount)회")
                    ShareStatCard(title: "연속 기록", value: "\(currentStreak)일")
                    ShareStatCard(title: "이 달 총 필사", value: "\(monthTotalCount)회")
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 56)

                VStack(spacing: 12) {
                    Text("오늘도 한 구절, 천천히.")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("조용히 이어가는 말씀 루틴")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(GardenTheme.primary.opacity(0.72))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 72)
            .padding(.bottom, 116)
            .padding(.horizontal, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
    }
}

private struct ShareStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct ShareGrassCell: View {
    let dayNumber: Int
    let count: Int
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("\(dayNumber)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(count == 0 ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(shareFillColor(for: count))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(shareStrokeColor(for: count), lineWidth: isToday ? 3 : 1)
                }
                .frame(width: 54, height: 54)
                .shadow(color: GardenTheme.primary.opacity(count > 0 ? 0.10 : 0), radius: 10, y: 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 112, alignment: .top)
    }

    private func shareFillColor(for count: Int) -> Color {
        switch count {
        case 0:
            return GardenTheme.heatmapZero
        case 1:
            return GardenTheme.heatmapLow
        case 2:
            return GardenTheme.heatmapMid
        case 3:
            return GardenTheme.primary.opacity(0.82)
        default:
            return GardenTheme.heatmapHigh
        }
    }

    private func shareStrokeColor(for count: Int) -> Color {
        if isToday {
            return GardenTheme.primary.opacity(0.82)
        }
        return count == 0 ? Color.white.opacity(0.32) : Color.white.opacity(0.40)
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
