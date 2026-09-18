import SwiftUI

struct BibleReadingLocation: Hashable {
    let book: String
    let chapter: Int
}

private enum BibleReadingLocationStore {
    private static let bookKey = "versegarden.bibleReader.lastReadBook"
    private static let chapterKey = "versegarden.bibleReader.lastReadChapter"

    static func restoredLocation(using service: BibleDataService) -> BibleReadingLocation {
        let defaults = UserDefaults.standard
        let savedBook = defaults.string(forKey: bookKey) ?? ""
        let savedChapter = defaults.integer(forKey: chapterKey)

        if service.getChapters(book: savedBook).contains(savedChapter) {
            return BibleReadingLocation(book: savedBook, chapter: savedChapter)
        }

        if let todayVerse = TodayVerseService.todayVerse(bibleService: service)?.verse {
            return BibleReadingLocation(book: todayVerse.book, chapter: todayVerse.chapter)
        }

        let firstBook = service.allBooks().first ?? "창세기"
        let firstChapter = service.getChapters(book: firstBook).first ?? 1
        return BibleReadingLocation(book: firstBook, chapter: firstChapter)
    }

    static func save(_ location: BibleReadingLocation) {
        UserDefaults.standard.set(location.book, forKey: bookKey)
        UserDefaults.standard.set(location.chapter, forKey: chapterKey)
    }
}

private enum BibleReaderSheet: Identifiable {
    case selector
    case search

    var id: String {
        switch self {
        case .selector: "selector"
        case .search: "search"
        }
    }
}

private enum BibleReaderDragIntent: Equatable {
    case idle
    case horizontalSwipe
    case verticalScroll
}

private struct BiblePaperSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.scripturePaper, AppColors.background, AppColors.scripturePaper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [AppColors.surface.opacity(0.42), .clear],
                center: .top,
                startRadius: 24,
                endRadius: 520
            )
            LinearGradient(
                colors: [AppColors.scripturePaperEdge.opacity(0.16), .clear, AppColors.scripturePaperEdge.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
    }
}

/// The reader-first entry point for the Bible tab. It keeps only one chapter in
/// the view hierarchy and uses the existing bundled Bible data service.
struct BibleReaderView: View {
    @EnvironmentObject private var likedVerseStore: LikedVerseStore

    private let service: BibleDataService
    private let previewLikedVerseIDs: Set<String>
    @State private var book: String
    @State private var chapter: Int
    @State private var chapterVerses: [LocalBibleVerse]
    @State private var highlightedVerseID: String?
    @State private var transientHighlightVerseID: String?
    @State private var transientHighlightOpacity = 0.0
    @State private var highlightTask: Task<Void, Never>?
    @State private var presentedSheet: BibleReaderSheet?
    @State private var selectedVerse: LocalBibleVerse?
    @State private var pendingWritingVerse: LocalBibleVerse?
    @State private var fullScreenWritingVerse: LocalBibleVerse?
    @State private var dragIntent: BibleReaderDragIntent = .idle
    @State private var suppressVerseTap = false

    init(
        service: BibleDataService = .shared,
        previewLocation: BibleReadingLocation? = nil,
        previewHighlightedVerseID: String? = nil,
        previewLikedVerseIDs: Set<String> = []
    ) {
        self.service = service
        self.previewLikedVerseIDs = previewLikedVerseIDs
        let initialLocation = previewLocation ?? BibleReadingLocationStore.restoredLocation(using: service)
        _book = State(initialValue: initialLocation.book)
        _chapter = State(initialValue: initialLocation.chapter)
        _chapterVerses = State(
            initialValue: service.getVerses(
                book: initialLocation.book,
                chapter: initialLocation.chapter
            )
        )
        _highlightedVerseID = State(initialValue: previewHighlightedVerseID)
        _transientHighlightVerseID = State(initialValue: previewHighlightedVerseID)
        _transientHighlightOpacity = State(initialValue: previewHighlightedVerseID == nil ? 0 : 0.52)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    readerHeader
                        .id(readerTopID)

                    readerContent
                    chapterNavigation
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.top, AppSpacing.large)
                .padding(.bottom, AppSpacing.tabBarBottomPadding)
            }
            .background(BiblePaperSurface())
            .simultaneousGesture(chapterSwipeGesture)
            .onChange(of: readingLocation) { _, location in
                handleReadingLocationChange(location, using: proxy)
            }
            .onChange(of: highlightedVerseID) { _, verseID in
                scrollToHighlightedVerseIfVisible(verseID, using: proxy, activatesHighlight: true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: AppSpacing.xsmall) {
                    Button {
                        presentedSheet = .search
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("성경 검색")

                    NavigationLink {
                        WritingPlanHubView()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("필사 플랜")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .padding(2)
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .selector:
                NavigationStack {
                    BibleReaderSelectorView(book: $book, chapter: $chapter, service: service)
                }
                .presentationDetents([.medium, .large])
            case .search:
                NavigationStack {
                    BibleReaderSearchView(service: service) { verse in
                        open(verse)
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(item: $selectedVerse, onDismiss: presentPendingWriting) { verse in
            NavigationStack {
                BibleReaderVerseSheet(verse: verse) {
                    pendingWritingVerse = verse
                    selectedVerse = nil
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $fullScreenWritingVerse) { verse in
            NavigationStack {
                WriteView(localVerse: verse, showsFullScreenCloseButton: true)
            }
        }
    }

    private var readingLocation: BibleReadingLocation {
        BibleReadingLocation(book: book, chapter: chapter)
    }

    private var readerTopID: String {
        "bible-reader-top-\(book)-\(chapter)"
    }

    private var readerHeader: some View {
        Button {
            presentedSheet = .selector
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(book)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.scriptureAccent)

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text("\(chapter)장")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.scriptureAccent)
                }

                HStack(spacing: AppSpacing.xsmall) {
                    Text("\(BibleDataService.translationSourceTitle) · \(testamentTitle)")
                    Spacer(minLength: AppSpacing.small)
                    Text("책·장 선택")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

                Rectangle()
                    .fill(AppColors.scriptureAccent.opacity(0.3))
                    .frame(height: 1)
                    .padding(.top, AppSpacing.xsmall)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GardenAccentButtonStyle())
        .accessibilityLabel("현재 본문 \(book) \(chapter)장. 책과 장 선택")
        .accessibilityHint("두 번 탭하여 성경 책과 장을 변경합니다")
    }

    private var testamentTitle: String {
        service.firstVerse(book: book)?.testament == BibleTestament.new.rawValue ? "신약" : "구약"
    }

    @ViewBuilder
    private var readerContent: some View {
        if chapterVerses.isEmpty {
            VGEmptyStateView(
                icon: "book.closed",
                title: "본문을 열 수 없어요",
                message: "다른 책이나 장을 선택해 다시 시도해보세요."
            )
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(chapterVerses) { verse in
                    Button {
                        guard !suppressVerseTap else { return }
                        selectedVerse = verse
                    } label: {
                        verseRow(verse)
                    }
                    .buttonStyle(.plain)
                    .id(verse.id)
                }
            }
            .padding(.vertical, AppSpacing.xsmall)
        }
    }

    private func verseRow(_ verse: LocalBibleVerse) -> some View {
        let isLiked = previewLikedVerseIDs.contains(verse.id) || likedVerseStore.isLiked(verse)

        return scriptureText(for: verse)
            .lineSpacing(AppTypography.scriptureLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.trailing, isLiked ? 24 : 0)
            .overlay(alignment: .topTrailing) {
                if isLiked {
                Image(systemName: "heart.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.scriptureAccent.opacity(0.88))
                        .padding(.top, 2)
                    .accessibilityHidden(true)
                }
            }
        .padding(.vertical, 5)
        .padding(.horizontal, AppSpacing.xsmall)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(
                    transientHighlightVerseID == verse.id
                        ? AppColors.scriptureHighlight.opacity(transientHighlightOpacity)
                        : .clear
                )
        }
        .overlay(alignment: .leading) {
            if transientHighlightVerseID == verse.id {
                Capsule()
                    .fill(AppColors.scriptureAccent.opacity(transientHighlightOpacity))
                    .frame(width: 3, height: 28)
                    .padding(.leading, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verse.referenceText). \(verse.text)\(isLiked ? ". 저장됨." : "")")
        .accessibilityHint("두 번 탭하여 말씀 상세를 엽니다")
    }

    private func scriptureText(for verse: LocalBibleVerse) -> Text {
        let verseNumber = Text("\(verse.verse)\u{2002}")
            .font(AppTypography.scriptureVerseNumber)
            .foregroundColor(AppColors.textTertiary)
        let verseBody = Text(verse.text)
            .font(AppTypography.scripture)
            .foregroundColor(AppColors.textPrimary)
        return Text("\(verseNumber)\(verseBody)")
    }

    private var chapterNavigation: some View {
        HStack(spacing: AppSpacing.small) {
            chapterNavigationButton(direction: .previous)
            chapterNavigationButton(direction: .next)
        }
        .padding(.top, AppSpacing.medium)
    }

    private func chapterNavigationButton(direction: ChapterDirection) -> some View {
        let target = service.adjacentChapter(book: book, chapter: chapter, offset: direction.offset)

        return Button {
            guard let target else { return }
            changeChapter(to: target.book, chapter: target.chapter)
        } label: {
            HStack(spacing: AppSpacing.xsmall) {
                if direction == .previous {
                    Image(systemName: "chevron.left")
                }
                Text(direction.title)
                    .font(AppTypography.button)
                if direction == .next {
                    Image(systemName: "chevron.right")
                }
            }
            .foregroundStyle(target == nil ? AppColors.textTertiary : AppColors.gardenPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(target == nil ? AppColors.surfaceSecondary.opacity(0.48) : AppColors.surfaceSecondary.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .stroke(AppColors.divider.opacity(target == nil ? 0.42 : 0.76), lineWidth: 1)
            }
        }
        .buttonStyle(GardenAccentButtonStyle())
        .disabled(target == nil)
        .accessibilityLabel(target == nil ? "\(direction.title), 사용할 수 없음" : direction.title)
    }

    private var chapterSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                updateDragIntent(for: value.translation)
            }
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                defer {
                    DispatchQueue.main.async {
                        dragIntent = .idle
                        suppressVerseTap = false
                    }
                }

                guard dragIntent == .horizontalSwipe,
                      abs(horizontalDistance) > 72,
                      abs(horizontalDistance) > abs(verticalDistance) * 2 else {
                    return
                }

                let direction: ChapterDirection = horizontalDistance < 0 ? .next : .previous
                guard let target = service.adjacentChapter(book: book, chapter: chapter, offset: direction.offset) else {
                    return
                }
                changeChapter(to: target.book, chapter: target.chapter)
            }
    }

    private func updateDragIntent(for translation: CGSize) {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard max(horizontalDistance, verticalDistance) >= 24 else { return }

        if horizontalDistance > verticalDistance * 1.2 {
            dragIntent = .horizontalSwipe
            suppressVerseTap = true
        } else if verticalDistance > horizontalDistance {
            dragIntent = .verticalScroll
            suppressVerseTap = true
        }
    }

    private func changeChapter(
        to newBook: String,
        chapter newChapter: Int,
        highlightedVerseID targetVerseID: String? = nil
    ) {
        if let targetVerseID {
            highlightedVerseID = targetVerseID
        } else {
            clearSearchHighlight()
        }
        guard newBook != book || newChapter != chapter else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            book = newBook
            chapter = newChapter
        }
    }

    private func open(_ verse: LocalBibleVerse) {
        changeChapter(
            to: verse.book,
            chapter: verse.chapter,
            highlightedVerseID: verse.id
        )
    }

    private func scrollAfterLocationChange(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let highlightedVerseID {
                scrollToHighlightedVerseIfVisible(highlightedVerseID, using: proxy, activatesHighlight: true)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(readerTopID, anchor: .top)
                }
            }
        }
    }

    private func handleReadingLocationChange(
        _ location: BibleReadingLocation,
        using proxy: ScrollViewProxy
    ) {
        chapterVerses = service.getVerses(book: location.book, chapter: location.chapter)
        if let highlightedVerseID,
           let highlightedVerse = service.getVerse(id: highlightedVerseID),
           highlightedVerse.book != location.book || highlightedVerse.chapter != location.chapter {
            clearSearchHighlight()
        }
        BibleReadingLocationStore.save(location)
        scrollAfterLocationChange(using: proxy)
    }

    private func scrollToHighlightedVerseIfVisible(
        _ verseID: String?,
        using proxy: ScrollViewProxy,
        activatesHighlight: Bool
    ) {
        guard let verseID,
              let verse = service.getVerse(id: verseID),
              verse.book == book,
              verse.chapter == chapter else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(verseID, anchor: .center)
            }
            if activatesHighlight {
                beginSearchHighlight(afterScrollingTo: verseID)
            }
        }
    }

    private func beginSearchHighlight(afterScrollingTo verseID: String) {
        highlightTask?.cancel()

        highlightTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled, highlightedVerseID == verseID else { return }

                transientHighlightVerseID = verseID
                transientHighlightOpacity = 0
                withAnimation(.easeOut(duration: 0.18)) {
                    transientHighlightOpacity = 0.38
                }

                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled, transientHighlightVerseID == verseID else { return }

                withAnimation(.easeInOut(duration: 0.24)) {
                    transientHighlightOpacity = 0.52
                }

                try await Task.sleep(nanoseconds: 480_000_000)
                guard !Task.isCancelled, transientHighlightVerseID == verseID else { return }

                withAnimation(.easeOut(duration: 0.96)) {
                    transientHighlightOpacity = 0
                }

                try await Task.sleep(nanoseconds: 960_000_000)
                guard !Task.isCancelled, transientHighlightVerseID == verseID else { return }
                transientHighlightVerseID = nil
                highlightedVerseID = nil
            } catch {
                return
            }
        }
    }

    private func clearSearchHighlight() {
        highlightTask?.cancel()
        highlightTask = nil
        transientHighlightVerseID = nil
        transientHighlightOpacity = 0
        highlightedVerseID = nil
    }

    private func presentPendingWriting() {
        guard let pendingWritingVerse else { return }
        self.pendingWritingVerse = nil
        fullScreenWritingVerse = pendingWritingVerse
    }
}

private enum ChapterDirection {
    case previous
    case next

    var offset: Int { self == .previous ? -1 : 1 }
    var title: String { self == .previous ? "이전 장" : "다음 장" }
}

private struct BibleReaderVerseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore

    let verse: LocalBibleVerse
    let onWrite: () -> Void

    private var isSaved: Bool { likedVerseStore.isLiked(verse) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(verse.referenceText)
                        .font(AppTypography.scriptureReference)
                        .foregroundStyle(AppColors.scriptureAccent)
                    Text(verse.text)
                        .font(.title3.weight(.regular))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineSpacing(AppTypography.scriptureLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(BibleDataService.translationSourceTitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Rectangle()
                    .fill(AppColors.scriptureAccent.opacity(0.28))
                    .frame(height: 1)

                Button(action: onWrite) {
                    Label("필사하기", systemImage: "pencil")
                        .font(AppTypography.description.weight(.semibold))
                        .foregroundStyle(AppColors.gardenDeep)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .stroke(AppColors.gardenPrimary.opacity(0.28), lineWidth: 0.8)
                        }
                }
                .buttonStyle(GardenAccentButtonStyle())

                HStack(spacing: AppSpacing.small) {
                    Button {
                        likedVerseStore.toggleLike(verse)
                    } label: {
                        Label(isSaved ? "저장됨" : "저장", systemImage: isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(isSaved ? AppColors.scriptureAccent : AppColors.gardenDeep)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .buttonStyle(GardenAccentButtonStyle())
                    .accessibilityLabel(isSaved ? "저장한 말씀에서 제거" : "말씀 저장")

                    ShareLink(item: verse.shareText) {
                        Label("공유", systemImage: "square.and.arrow.up")
                            .foregroundStyle(AppColors.gardenDeep)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }
                    .accessibilityLabel("말씀 공유")
                }
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.large)
        }
        .navigationTitle("말씀")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .background(BiblePaperSurface())
        .onAppear {
            gardenActivityStore.addActivity(
                type: .verseRead,
                title: GardenActivityType.verseRead.displayTitle,
                verseId: verse.id,
                reference: verse.referenceText,
                contentPreview: verse.text
            )
        }
    }
}

private enum BibleReaderSelectorStep {
    case books
    case chapters
}

private struct BibleReaderBookCategory: Identifiable {
    let title: String
    let bookNames: Set<String>

    var id: String { title }
}

private struct BibleReaderTestamentPalette {
    let accent: Color
    let surface: Color
    let selectedSurface: Color
    let border: Color

    init(testament: BibleTestament) {
        switch testament {
        case .old:
            accent = AppColors.oldTestamentText
            surface = AppColors.oldTestamentSurface
            selectedSurface = AppColors.oldTestamentSelected
            border = AppColors.oldTestamentBorder
        case .new:
            accent = AppColors.newTestamentText
            surface = AppColors.newTestamentSurface
            selectedSurface = AppColors.newTestamentSelected
            border = AppColors.newTestamentBorder
        }
    }
}

private enum BibleReaderBookAbbreviations {
    static let values: [String: String] = [
        "창세기": "창", "출애굽기": "출", "레위기": "레", "민수기": "민", "신명기": "신",
        "여호수아": "수", "사사기": "삿", "룻기": "룻", "사무엘상": "삼상", "사무엘하": "삼하",
        "열왕기상": "왕상", "열왕기하": "왕하", "역대상": "대상", "역대하": "대하", "에스라": "스",
        "느헤미야": "느", "에스더": "에", "욥기": "욥", "시편": "시", "잠언": "잠", "전도서": "전", "아가": "아",
        "이사야": "사", "예레미야": "렘", "예레미야애가": "애", "에스겔": "겔", "다니엘": "단",
        "호세아": "호", "요엘": "욜", "아모스": "암", "오바댜": "옵", "요나": "욘", "미가": "미", "나훔": "나",
        "하박국": "합", "스바냐": "습", "학개": "학", "스가랴": "슥", "말라기": "말",
        "마태복음": "마", "마가복음": "막", "누가복음": "눅", "요한복음": "요", "사도행전": "행",
        "로마서": "롬", "고린도전서": "고전", "고린도후서": "고후", "갈라디아서": "갈", "에베소서": "엡",
        "빌립보서": "빌", "골로새서": "골", "데살로니가전서": "살전", "데살로니가후서": "살후",
        "디모데전서": "딤전", "디모데후서": "딤후", "디도서": "딛", "빌레몬서": "몬",
        "히브리서": "히", "야고보서": "약", "베드로전서": "벧전", "베드로후서": "벧후",
        "요한일서": "요일", "요한이서": "요이", "요한삼서": "요삼", "유다서": "유", "요한계시록": "계"
    ]

    static func abbreviation(for book: String) -> String {
        guard let abbreviation = values[book] else {
            preconditionFailure("Missing Bible book abbreviation metadata for \(book)")
        }
        return abbreviation
    }

    static func validate(canonicalBooks: [String]) {
        let canonicalSet = Set(canonicalBooks)
        precondition(canonicalSet.count == 66, "Expected 66 canonical Bible books")
        precondition(Set(values.keys) == canonicalSet, "Bible book abbreviation metadata must match canonical book names")
        let categorySet = Set(BibleTestament.allCases.flatMap { $0.readerCategories.flatMap(\.bookNames) })
        precondition(categorySet == canonicalSet, "Bible book categories must match canonical book names")
    }
}

private struct BibleReaderBookItem: View {
    let book: String
    let palette: BibleReaderTestamentPalette
    let isCurrentBook: Bool
    let action: () -> Void

    private var abbreviation: String { BibleReaderBookAbbreviations.abbreviation(for: book) }
    private var abbreviationFontSize: CGFloat { abbreviation.count > 2 ? 11 : 13 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                Text(abbreviation)
                    .font(.system(size: abbreviationFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.accent)
                    .frame(width: 44, height: 44)
                    .background(isCurrentBook ? palette.selectedSurface : palette.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(palette.border.opacity(isCurrentBook ? 0.9 : 0.55), lineWidth: 0.8)
                    }
                    .accessibilityHidden(true)

                Text(book)
                    .font(AppTypography.description.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, AppSpacing.small)
            .background(isCurrentBook ? palette.selectedSurface.opacity(0.34) : AppColors.surface.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(isCurrentBook ? palette.border.opacity(0.9) : AppColors.divider.opacity(0.56), lineWidth: 0.8)
            }
        }
        .buttonStyle(GardenAccentButtonStyle())
        .accessibilityLabel("\(book)\(isCurrentBook ? ", 현재 선택" : "")")
        .accessibilityHint("두 번 탭하여 장 선택으로 이동합니다")
    }
}

private extension BibleTestament {
    var readerCategories: [BibleReaderBookCategory] {
        switch self {
        case .old:
            [
                .init(title: "모세오경", bookNames: ["창세기", "출애굽기", "레위기", "민수기", "신명기"]),
                .init(title: "역사서", bookNames: ["여호수아", "사사기", "룻기", "사무엘상", "사무엘하", "열왕기상", "열왕기하", "역대상", "역대하", "에스라", "느헤미야", "에스더"]),
                .init(title: "시가서", bookNames: ["욥기", "시편", "잠언", "전도서", "아가"]),
                .init(title: "대선지서", bookNames: ["이사야", "예레미야", "예레미야애가", "에스겔", "다니엘"]),
                .init(title: "소선지서", bookNames: ["호세아", "요엘", "아모스", "오바댜", "요나", "미가", "나훔", "하박국", "스바냐", "학개", "스가랴", "말라기"])
            ]
        case .new:
            [
                .init(title: "복음서", bookNames: ["마태복음", "마가복음", "누가복음", "요한복음"]),
                .init(title: "역사서", bookNames: ["사도행전"]),
                .init(title: "바울서신", bookNames: ["로마서", "고린도전서", "고린도후서", "갈라디아서", "에베소서", "빌립보서", "골로새서", "데살로니가전서", "데살로니가후서", "디모데전서", "디모데후서", "디도서", "빌레몬서"]),
                .init(title: "공동서신", bookNames: ["히브리서", "야고보서", "베드로전서", "베드로후서", "요한일서", "요한이서", "요한삼서", "유다서"]),
                .init(title: "예언서", bookNames: ["요한계시록"])
            ]
        }
    }
}

private struct BibleReaderSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding private var book: String
    @Binding private var chapter: Int
    private let service: BibleDataService
    @State private var testament: BibleTestament
    @State private var selectedBook: String
    @State private var step: BibleReaderSelectorStep = .books

    init(book: Binding<String>, chapter: Binding<Int>, service: BibleDataService) {
        _book = book
        _chapter = chapter
        self.service = service
        let initialBook = book.wrappedValue
        BibleReaderBookAbbreviations.validate(canonicalBooks: service.allBooks())
        _selectedBook = State(initialValue: initialBook)
        let isNewTestament = service.firstVerse(book: initialBook)?.testament == BibleTestament.new.rawValue
        _testament = State(initialValue: isNewTestament ? .new : .old)
    }

    private var books: [String] {
        service.books(in: testament)
    }

    private var chapters: [Int] {
        service.chapters(in: selectedBook)
    }

    private var palette: BibleReaderTestamentPalette {
        BibleReaderTestamentPalette(testament: testament)
    }

    private var chapterPalette: BibleReaderTestamentPalette {
        let selectedTestament: BibleTestament = service.firstVerse(book: selectedBook)?.testament == BibleTestament.new.rawValue ? .new : .old
        return BibleReaderTestamentPalette(testament: selectedTestament)
    }

    private var bookCategories: [(category: BibleReaderBookCategory, books: [String])] {
        testament.readerCategories.compactMap { category in
            let categoryBooks = books.filter { category.bookNames.contains($0) }
            return categoryBooks.isEmpty ? nil : (category, categoryBooks)
        }
    }

    /// Keep the visual experiment reversible: only this definition changes when
    /// physical QA compares the 2-column index with the earlier 3-column grid.
    private var bookColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: AppSpacing.medium), GridItem(.flexible(), spacing: AppSpacing.medium)]
    }
    private let chapterColumns = [GridItem(.adaptive(minimum: 46), spacing: AppSpacing.small)]
    private let selectorTopID = "bible-reader-selector-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Group {
                    switch step {
                    case .books:
                        bookSelection
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    case .chapters:
                        chapterSelection
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .id(selectorTopID)
                .padding(AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.large)
            }
            .onChange(of: step) { _, _ in
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(selectorTopID, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle(step == .books ? "성경 선택" : selectedBook)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .background(BiblePaperSurface())
    }

    private var bookSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            VGSectionHeader("성경 선택", subtitle: "읽고 싶은 책을 선택하세요.")

            Picker("성경 구분", selection: $testament) {
                ForEach(BibleTestament.allCases) { testament in
                    Text(testament.title).tag(testament)
                }
            }
            .pickerStyle(.segmented)
            .tint(palette.accent)
            .onChange(of: testament) { _, newTestament in
                selectedBook = service.books(in: newTestament).first ?? ""
            }

            VStack(alignment: .leading, spacing: AppSpacing.section) {
                ForEach(bookCategories, id: \.category.id) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text(section.category.title)
                            .font(AppTypography.description.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .accessibilityAddTraits(.isHeader)

                        LazyVGrid(columns: bookColumns, spacing: AppSpacing.small) {
                            ForEach(section.books, id: \.self) { item in
                                bookButton(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var chapterSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        step = .books
                    }
                } label: {
                    Label("책 선택", systemImage: "chevron.left")
                        .font(AppTypography.description.weight(.semibold))
                        .foregroundStyle(chapterPalette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("책 선택으로 돌아가기")

                VGSectionHeader(selectedBook, subtitle: "장을 선택하세요.")
            }

            LazyVGrid(columns: chapterColumns, spacing: AppSpacing.small) {
                ForEach(chapters, id: \.self) { item in
                    Button {
                        book = selectedBook
                        chapter = item
                        dismiss()
                    } label: {
                        Text("\(item)")
                            .font(AppTypography.button)
                            .foregroundStyle(chapterPalette.accent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(item == chapter && selectedBook == book ? chapterPalette.selectedSurface : chapterPalette.surface.opacity(0.68))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                    .stroke(chapterPalette.border.opacity(item == chapter && selectedBook == book ? 0.9 : 0.65), lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(GardenAccentButtonStyle())
                    .accessibilityLabel("\(selectedBook) \(item)장\(item == chapter && selectedBook == book ? ", 현재 선택" : "")")
                }
            }
        }
    }

    private func selectBook(_ newBook: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedBook = newBook
            step = .chapters
        }
    }

    private func bookButton(_ item: String) -> some View {
        BibleReaderBookItem(
            book: item,
            palette: palette,
            isCurrentBook: item == book,
            action: { selectBook(item) }
        )
    }
}

private struct BibleReaderSearchView: View {
    @Environment(\.dismiss) private var dismiss

    private let service: BibleDataService
    private let onSelectVerse: (LocalBibleVerse) -> Void
    @State private var query = ""
    @StateObject private var search = BibleSearchController(resultLimit: 24)

    init(service: BibleDataService, onSelectVerse: @escaping (LocalBibleVerse) -> Void) {
        self.service = service
        self.onSelectVerse = onSelectVerse
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.small) {
                TextField("본문, 책 이름, 장절 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.editorPadding)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                searchResults
            }
            .padding(AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.large)
        }
        .navigationTitle("성경 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") { dismiss() }
            }
        }
        .background(BiblePaperSurface())
        .task {
            search.prepare(verses: service.loadAllVerses())
        }
        .onChange(of: query) { _, newQuery in
            search.update(query: newQuery)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("본문, 성경 책 이름, 장절로 말씀을 찾을 수 있어요.")
                .font(AppTypography.description)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, AppSpacing.medium)
        } else if search.isSearching {
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                Text("말씀을 찾는 중입니다.")
            }
            .font(AppTypography.description)
            .foregroundStyle(AppColors.textSecondary)
            .padding(.top, AppSpacing.medium)
        } else if search.results.isEmpty {
            VGEmptyStateView(
                icon: "magnifyingglass",
                title: "검색 결과가 없어요",
                message: "다른 단어나 성경 위치로 다시 검색해보세요."
            )
        } else {
            ForEach(search.results) { verse in
                Button {
                    onSelectVerse(verse)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                        Text(verse.referenceText)
                            .font(AppTypography.scriptureReference)
                            .foregroundStyle(AppColors.scriptureAccent)
                        Text(verse.text)
                            .font(AppTypography.description)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.medium)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(verse.referenceText). \(verse.text)")

                Divider().overlay(AppColors.divider)
            }

            if search.hasMoreResults {
                Text("더 많은 결과가 있습니다. 검색어를 더 구체적으로 입력해보세요.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, AppSpacing.xsmall)
            }
        }
    }
}

#Preview("Genesis 1") {
    NavigationStack {
        BibleReaderView(previewLocation: BibleReadingLocation(book: "창세기", chapter: 1))
    }
    .environmentObject(LikedVerseStore())
}

#Preview("Genesis 1 · Saved") {
    NavigationStack {
        BibleReaderView(
            previewLocation: BibleReadingLocation(book: "창세기", chapter: 1),
            previewLikedVerseIDs: ["창세기-1-1", "창세기-1-3", "창세기-1-12"]
        )
    }
    .environmentObject(LikedVerseStore())
}

#Preview("Genesis 1 · Search Target") {
    NavigationStack {
        BibleReaderView(
            previewLocation: BibleReadingLocation(book: "창세기", chapter: 1),
            previewHighlightedVerseID: "창세기-1-12"
        )
    }
    .environmentObject(LikedVerseStore())
}

#Preview("Bible Selector") {
    BibleReaderSelectorPreview()
}

private struct BibleReaderSelectorPreview: View {
    @State private var book = "창세기"
    @State private var chapter = 1

    var body: some View {
        NavigationStack {
            BibleReaderSelectorView(
                book: $book,
                chapter: $chapter,
                service: .shared
            )
        }
    }
}
