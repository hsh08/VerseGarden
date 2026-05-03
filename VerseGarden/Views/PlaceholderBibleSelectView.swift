import SwiftUI

struct PlaceholderBibleSelectView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("성경 데이터 연결 후 사용할 수 있습니다.")
                        .font(.title3.bold())
                    Text("구약/신약 → 성경 권 → 장 → 절 선택 구조로 구현 예정입니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("예정된 선택 흐름")
                        .font(.headline)

                    PlaceholderStep(title: "1단계", description: "구약 또는 신약 선택")
                    PlaceholderStep(title: "2단계", description: "성경 권 선택")
                    PlaceholderStep(title: "3단계", description: "장과 절 선택")
                }
            }
            .padding()
        }
        .navigationTitle("성경 직접 선택")
        .background(Color(.systemGroupedBackground))
    }
}

private struct PlaceholderStep: View {
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(width: 52, alignment: .leading)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
