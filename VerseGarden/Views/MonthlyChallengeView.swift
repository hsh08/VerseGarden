import SwiftUI

struct MonthlyChallengeView: View {
    private let days = Array(1...30)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("30일 루틴 미리보기")
                        .font(.headline)

                    ForEach(days, id: \.self) { day in
                        HStack(spacing: 12) {
                            Text("Day \(day)")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 68, alignment: .leading)

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 44)
                                .overlay(alignment: .leading) {
                                    Text("추천 구절 연결 예정")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 14)
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("이번 달 필사")
        .background(Color(.systemGroupedBackground))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("5월 추천 테마")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("용기를 주는 말씀")
                .font(.title3.bold())
            Text("이번 달에는 매일 한 구절씩 필사하며 루틴을 만들어보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.18), Color.teal.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
