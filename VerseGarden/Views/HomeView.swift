import FirebaseAuth
import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BibleVerse.book) private var verses: [BibleVerse]
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]

    private let calendar = Calendar.current
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        let verse = todayVerse

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                verseCard(verse)
                statsRow
                startWritingSection

                NavigationLink {
                    WriteView(verse: verse)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("오늘의 필사 시작")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("오늘의 구절로 바로 필사를 이어갑니다.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.88))
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer(minLength: 12)
            }
            .padding()
        }
        .navigationTitle("VerseGarden")
        .background(Color(.systemGroupedBackground))
        .task {
            seedVersesIfNeeded()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘도 한 구절, 천천히")
                .font(.title2.bold())
            Text("매일 필사 기록을 쌓아 잔디를 채웁니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.18), Color.mint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func verseCard(_ verse: BibleVerse?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 구절")
                .font(.headline)

            if let verse {
                Text(verse.text)
                    .font(.body)
                    .lineSpacing(6)

                Text("\(verse.book) \(verse.chapter):\(verse.verse)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("샘플 구절을 불러오는 중입니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var startWritingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("필사 시작하기")
                .font(.headline)

            NavigationLink {
                BibleSelectView()
            } label: {
                StartOptionCard(
                    title: "성경 직접 선택",
                    description: "원하는 성경 구절을 골라 필사해요",
                    icon: "books.vertical.fill",
                    accent: Color.green
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ThemeSelectView()
            } label: {
                StartOptionCard(
                    title: "테마별 말씀 필사",
                    description: "위로, 용기, 시험기간 등 상황에 맞는 말씀을 골라요",
                    icon: "sparkles.rectangle.stack.fill",
                    accent: Color.mint
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                MonthlyChallengeView()
            } label: {
                StartOptionCard(
                    title: "이번 달 필사",
                    description: "한 달 동안 이어가는 말씀 루틴",
                    icon: "calendar.badge.clock",
                    accent: Color.teal
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "연속 필사", value: "\(StreakCalculator.currentStreak(from: currentUserRecords, calendar: calendar))일")
            StatCard(title: "총 필사", value: "\(currentUserRecords.count)회")
        }
    }

    private var todayVerse: BibleVerse? {
        guard !verses.isEmpty else { return nil }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % verses.count
        return verses[index]
    }

    private func seedVersesIfNeeded() {
        guard verses.isEmpty else { return }

        for item in SampleVerses.items {
            let verse = BibleVerse(
                id: item.id,
                book: item.book,
                chapter: item.chapter,
                verse: item.verse,
                text: item.text
            )
            modelContext.insert(verse)
        }

        try? modelContext.save()
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StartOptionCard: View {
    let title: String
    let description: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
