import SwiftUI

struct TodayQuietTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @EnvironmentObject private var qtStore: QTStore

    let todayVerse: TodayVerseContent?
    let planLaunchVerse: LocalBibleVerse?
    let planLaunchContext: WritingContext?
    let isPlanPaused: Bool
    let isWritingCompleted: Bool
    let qtContentOverride: QTContent?

    init(
        todayVerse: TodayVerseContent?,
        planLaunchVerse: LocalBibleVerse?,
        planLaunchContext: WritingContext?,
        isPlanPaused: Bool,
        isWritingCompleted: Bool,
        qtContentOverride: QTContent? = nil
    ) {
        self.todayVerse = todayVerse
        self.planLaunchVerse = planLaunchVerse
        self.planLaunchContext = planLaunchContext
        self.isPlanPaused = isPlanPaused
        self.isWritingCompleted = isWritingCompleted
        self.qtContentOverride = qtContentOverride
    }

    @State private var reflectionAnswer = ""
    @State private var applicationText = ""
    @State private var prayerText = ""
    @State private var completionMessage: String?
    @State private var hasLoadedRecord = false

    private let calendar = Calendar.current

    private var qtContent: QTContent {
        if let qtContentOverride {
            return qtContentOverride
        }

        return QTContent(
            date: Date(),
            calendar: calendar,
            todayVerse: todayVerse,
            fallbackVerse: writingVerse
        )
    }

    private var writingVerse: LocalBibleVerse? {
        if let verseId = qtContentOverride?.verseId,
           let remoteVerse = BibleDataService.shared.getVerse(id: verseId) {
            return remoteVerse
        }
        return planLaunchVerse ?? todayVerse?.verse
    }

    private var canComplete: Bool {
        !reflectionAnswer.trimmedForQT.isEmpty
            || !applicationText.trimmedForQT.isEmpty
            || !prayerText.trimmedForQT.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard
                scriptureCard
                reflectionCard
                applicationCard
                prayerCard
                completeQuietTimeCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("오늘의 QT")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .task(id: qtContent.id) {
            loadRecord()
        }
        .onChange(of: reflectionAnswer) { _, _ in
            persistDraftIfLoaded()
        }
        .onChange(of: applicationText) { _, _ in
            persistDraftIfLoaded()
        }
        .onChange(of: prayerText) { _, _ in
            persistDraftIfLoaded()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘의 QT")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primaryText)
            Text(qtContent.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
            Text(qtContent.date.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scriptureCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 16) {
                GardenSectionHeader("오늘의 말씀", subtitle: qtContent.reference)

                if !qtContent.verseLines.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(qtContent.verseLines) { line in
                            scriptureVerseLine(line)
                        }
                    }
                } else {
                    Text(qtContent.verseText)
                        .font(.body)
                        .foregroundStyle(AppColors.primaryText)
                        .lineSpacing(6)
                }

                HStack(spacing: 10) {
                    if let verse = writingVerse {
                        NavigationLink {
                            VerseDetailView(verse: verse)
                        } label: {
                            compactActionButton(title: "말씀 자세히 보기", icon: "book.pages.fill")
                        }
                        .buttonStyle(.plain)
                    }

                    writingStep
                }
            }
        }
    }

    private var reflectionCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("말씀을 묵상해요", subtitle: qtContent.devotionalText)

                promptText(qtContent.reflectionPrompt)
                AppTextArea(
                    title: "여기에 묵상을 적어보세요",
                    text: $reflectionAnswer,
                    minHeight: 108
                )
            }
        }
    }

    private var applicationCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("오늘 나에게")
                promptText(qtContent.applicationPrompt)
                AppTextArea(
                    title: "오늘의 적용을 적어보세요",
                    text: $applicationText,
                    minHeight: 100
                )
            }
        }
    }

    private var prayerCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("기도로 마무리해요")
                promptText(qtContent.prayerPrompt)
                AppTextArea(
                    title: "기도를 적어보세요",
                    text: $prayerText,
                    minHeight: 100
                )
            }
        }
    }

    private var completeQuietTimeCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader("오늘의 아멘", subtitle: "완료하면 오늘의 Garden에 QT 기록이 심겨요.")

                if let completionMessage {
                    Text(completionMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GardenTheme.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GardenTheme.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                }

                Button {
                    completeQuietTime()
                } label: {
                    GardenPrimaryButtonLabel(title: "QT 완료하고 Garden에 심기", icon: "checkmark.seal.fill")
                        .opacity(canComplete ? 1 : 0.62)
                }
                .buttonStyle(.plain)
                .disabled(!canComplete)

                Text("묵상, 적용, 기도 중 하나 이상을 남기면 완료할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var writingStep: some View {
        if isWritingCompleted {
            compactActionButton(
                title: "오늘 말씀 필사 완료",
                icon: "checkmark.circle.fill",
                tint: GardenTheme.secondary
            )
        } else if isPlanPaused {
            NavigationLink {
                MyPlansView()
            } label: {
                compactActionButton(
                    title: "필사 플랜 다시 열기",
                    icon: "pause.circle.fill",
                    tint: GardenTheme.primary
                )
            }
            .buttonStyle(.plain)
        } else if let planLaunchContext, let planLaunchVerse {
            NavigationLink {
                WriteView(
                    localVerse: planLaunchVerse,
                    sourceType: .plan,
                    writingContext: planLaunchContext
                )
            } label: {
                compactActionButton(
                    title: "오늘 말씀 필사하기",
                    icon: "pencil.line",
                    tint: GardenTheme.primary
                )
            }
            .buttonStyle(.plain)
        } else if let writingVerse {
            NavigationLink {
                WriteView(localVerse: writingVerse)
            } label: {
                compactActionButton(
                    title: "오늘 말씀 필사하기",
                    icon: "pencil.line",
                    tint: GardenTheme.primary
                )
            }
            .buttonStyle(.plain)
        } else {
            compactActionButton(
                title: "필사 말씀 준비 중",
                icon: "lock.fill",
                tint: AppColors.subtleText
            )
            .opacity(0.72)
        }
    }

    private func scriptureVerseLine(_ line: QTVerseLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(line.verseNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 24, alignment: .trailing)
            Text(line.text)
                .font(.body)
                .foregroundStyle(AppColors.primaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promptText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GardenTheme.primary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func compactActionButton(
        title: String,
        icon: String,
        tint: Color = GardenTheme.primary
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .gardenCardSurface(
            background: GardenTheme.softFill.opacity(0.9),
            border: tint.opacity(0.18),
            cornerRadius: AppRadius.button,
            shadowRadius: 0,
            shadowY: 0
        )
    }

    private func questionRow(_ question: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(GardenTheme.primary)
                .padding(.top, 2)
            Text(question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.primaryText)
        }
        .padding(12)
        .background(GardenTheme.softFill.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    private func loadRecord() {
        let record = qtStore.record(for: qtContent)
        reflectionAnswer = record.reflectionAnswer
        applicationText = record.applicationText
        prayerText = record.prayerText
        hasLoadedRecord = true
    }

    private func persistDraftIfLoaded() {
        guard hasLoadedRecord else { return }
        qtStore.saveDraft(
            for: qtContent,
            reflectionAnswer: reflectionAnswer,
            applicationText: applicationText,
            prayerText: prayerText
        )
    }

    private func completeQuietTime() {
        guard canComplete else { return }
        let completedRecord = qtStore.complete(
            content: qtContent,
            reflectionAnswer: reflectionAnswer,
            applicationText: applicationText,
            prayerText: prayerText
        )

        gardenActivityStore.addActivity(
            type: .qtCompleted,
            title: GardenActivityType.qtCompleted.displayTitle,
            verseId: completedRecord.verseId,
            reference: completedRecord.reference,
            contentPreview: completedRecord.reflectionAnswer.trimmedForQT.isEmpty
                ? completedRecord.verseText
                : completedRecord.reflectionAnswer,
            sourceId: completedRecord.id,
            createdAt: completedRecord.completedAt ?? Date()
        )

        completionMessage = "오늘의 QT가 Garden에 심겼어요."

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            dismiss()
        }
    }
}

private extension String {
    var trimmedForQT: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
