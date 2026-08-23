import SwiftUI
import UIKit

struct GuidedTypingTextView: View {
    let targetText: String
    @Binding var inputText: String
    let analysis: TypingAnalysis

    @FocusState private var isFocused: Bool
    private let noteLineSpacing: CGFloat = 11
    private let noteFont: Font = .system(size: 19, weight: .regular, design: .serif)
    private let textFontSize: CGFloat = 19
    private let horizontalPadding: CGFloat = 20
    private let verticalPadding: CGFloat = 22
    private let minimumNotebookHeight: CGFloat = 168
    @State private var notebookHeight: CGFloat = 168
    @State private var measuredWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xFCFBF7))

            ScriptureNoteBackground(
                metrics: scriptureMetrics,
                verticalPadding: verticalPadding,
                horizontalInset: 18
            )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(guidedText)
                .font(noteFont)
                .lineSpacing(noteLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .transaction { transaction in
                    transaction.animation = nil
                }

            TextField("", text: $inputText)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.default)
                .textContentType(.none)
                .submitLabel(.done)
                .frame(width: 1, height: 1)
                .opacity(0.015)
                .padding(1)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: notebookHeight, alignment: .topLeading)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xD8DDD2), lineWidth: 1)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        measuredWidth = proxy.size.width
                        updateNotebookHeight(for: proxy.size.width)
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        measuredWidth = newWidth
                        updateNotebookHeight(for: newWidth)
                    }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
        .onChange(of: inputText) { _, newValue in
            let trimmedToTargetLength = String(newValue.prefix(targetText.count))
            if trimmedToTargetLength != newValue {
                inputText = trimmedToTargetLength
            }
        }
        .onChange(of: targetText) { _, _ in
            guard measuredWidth > 0 else { return }
            updateNotebookHeight(for: measuredWidth)
        }
    }

    private var uiNoteFont: UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        return UIFont(descriptor: descriptor, size: textFontSize)
    }

    private var scriptureMetrics: ScriptureNotebookMetrics {
        ScriptureNotebookMetrics(font: uiNoteFont, extraLineSpacing: noteLineSpacing)
    }

    private var guidedText: AttributedString {
        var attributed = AttributedString()

        for state in analysis.characterStates {
            let displayedCharacter = String(state.renderCharacter)
            var piece = AttributedString(displayedCharacter)

            switch state.state {
            case .correct:
                piece.foregroundColor = AppColors.primaryText.opacity(0.92)
            case .wrong:
                piece.foregroundColor = Color(hex: 0xA15852)
                if !state.isWhitespace {
                    piece.backgroundColor = Color(hex: 0xE8D3CF, opacity: 0.42)
                }
            case .remaining:
                piece.foregroundColor = AppColors.subtleText
            case .current:
                piece.foregroundColor = AppColors.secondaryText
                if !state.isWhitespace {
                    piece.backgroundColor = GardenTheme.primary.opacity(0.10)
                }
            }

            attributed.append(piece)
        }

        return attributed
    }

    private var noteLineStep: CGFloat {
        scriptureMetrics.lineAdvance
    }

    private func updateNotebookHeight(for availableWidth: CGFloat) {
        let contentWidth = max(availableWidth - (horizontalPadding * 2), 120)
        let estimatedHeight = estimatedTextHeight(for: targetText, width: contentWidth)
        let visibleLineCount = max(Int(ceil(estimatedHeight / noteLineStep)), 3)
        let computedHeight = CGFloat(visibleLineCount) * noteLineStep + (verticalPadding * 2) + 8
        let nextHeight = max(minimumNotebookHeight, computedHeight)

        guard abs(nextHeight - notebookHeight) > 1 else { return }
        notebookHeight = nextHeight
    }

    private func estimatedTextHeight(for text: String, width: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = noteLineSpacing
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiNoteFont,
            .paragraphStyle: paragraphStyle
        ]

        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return ceil(rect.height)
    }
}

private struct ScriptureNotebookMetrics {
    let font: UIFont
    let extraLineSpacing: CGFloat

    var ascender: CGFloat { font.ascender }
    var descender: CGFloat { abs(font.descender) }
    var lineHeight: CGFloat { font.lineHeight }
    var lineAdvance: CGFloat { font.lineHeight + extraLineSpacing }

    var ruleOffsetFromBaseline: CGFloat {
        max(descender * 0.72, 3)
    }
}

private struct ScriptureNoteBackground: View {
    let metrics: ScriptureNotebookMetrics
    let verticalPadding: CGFloat
    let horizontalInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let firstBaselineY = verticalPadding + metrics.ascender
            let firstRuleY = firstBaselineY + metrics.ruleOffsetFromBaseline
            let remainingHeight = max(proxy.size.height - firstRuleY, 0)
            let lineCount = Int(ceil(remainingHeight / metrics.lineAdvance)) + 1

            Canvas { context, size in
                for index in 0..<lineCount {
                    let y = firstRuleY + (CGFloat(index) * metrics.lineAdvance)
                    var path = Path()
                    path.move(to: CGPoint(x: horizontalInset, y: y))
                    path.addLine(to: CGPoint(x: size.width - horizontalInset, y: y))
                    context.stroke(
                        path,
                        with: .color(Color(hex: 0xDDE3D8)),
                        lineWidth: 0.75
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct TypingCharacterState {
    enum State {
        case correct
        case wrong
        case remaining
        case current
    }

    let targetCharacter: Character
    let typedCharacter: Character?
    let state: State

    var isWhitespace: Bool {
        targetCharacter == " "
    }

    var renderCharacter: Character {
        switch state {
        case .wrong:
            return targetCharacter
        case .correct, .remaining, .current:
            return typedCharacter ?? targetCharacter
        }
    }
}

struct TypingAnalysis {
    let characterStates: [TypingCharacterState]
    let correctPrefixCount: Int
    let hasWrongCharacter: Bool
    let isComplete: Bool
    let progress: Double
    let hasWhitespaceMismatch: Bool

    static let empty = TypingAnalysis(
        characterStates: [],
        correctPrefixCount: 0,
        hasWrongCharacter: false,
        isComplete: false,
        progress: 0,
        hasWhitespaceMismatch: false
    )
}

enum GuidedTypingValidator {
    static func analyze(_ inputText: String, targetText: String) -> TypingAnalysis {
        let targetCharacters = Array(targetText)
        let inputCharacters = Array(inputText)
        let complete = inputText == targetText
        let hasWrong = hasAnyWrongCharacter(inputCharacters, targetCharacters: targetCharacters)
        let correctPrefixCount = correctPrefixCount(inputCharacters, targetCharacters: targetCharacters)

        let states = targetCharacters.enumerated().map { index, targetCharacter in
            let typedCharacter = index < inputCharacters.count ? inputCharacters[index] : nil

            if let typedCharacter {
                if typedCharacter == targetCharacter {
                    return TypingCharacterState(targetCharacter: targetCharacter, typedCharacter: typedCharacter, state: .correct)
                }

                return TypingCharacterState(targetCharacter: targetCharacter, typedCharacter: typedCharacter, state: .wrong)
            }

            if index == inputCharacters.count && !complete && !hasWrong {
                return TypingCharacterState(targetCharacter: targetCharacter, typedCharacter: nil, state: .current)
            }

            return TypingCharacterState(targetCharacter: targetCharacter, typedCharacter: nil, state: .remaining)
        }

        return TypingAnalysis(
            characterStates: states,
            correctPrefixCount: correctPrefixCount,
            hasWrongCharacter: hasWrong,
            isComplete: complete,
            progress: targetCharacters.isEmpty ? 0 : Double(correctPrefixCount) / Double(targetCharacters.count),
            hasWhitespaceMismatch: hasWhitespaceMismatch(inputCharacters, targetCharacters: targetCharacters)
        )
    }

    static func correctPrefixCount(_ inputText: String, targetText: String) -> Int {
        correctPrefixCount(Array(inputText), targetCharacters: Array(targetText))
    }

    private static func correctPrefixCount(_ inputCharacters: [Character], targetCharacters: [Character]) -> Int {
        var count = 0

        for pair in zip(inputCharacters, targetCharacters) {
            guard pair.0 == pair.1 else { break }
            count += 1
        }

        return count
    }

    static func hasAnyWrongCharacter(_ inputText: String, targetText: String) -> Bool {
        hasAnyWrongCharacter(Array(inputText), targetCharacters: Array(targetText))
    }

    private static func hasAnyWrongCharacter(_ inputCharacters: [Character], targetCharacters: [Character]) -> Bool {
        if inputCharacters.count > targetCharacters.count {
            return true
        }

        for index in inputCharacters.indices {
            guard index < targetCharacters.count else { return true }
            if inputCharacters[index] != targetCharacters[index] {
                return true
            }
        }

        return false
    }

    private static func hasWhitespaceMismatch(_ inputCharacters: [Character], targetCharacters: [Character]) -> Bool {
        for index in inputCharacters.indices {
            guard index < targetCharacters.count else { return false }
            let input = inputCharacters[index]
            let target = targetCharacters[index]
            if input != target, (input == " " || target == " ") {
                return true
            }
        }
        return false
    }

    static func isValidPrefix(_ inputText: String, targetText: String) -> Bool {
        !hasAnyWrongCharacter(inputText, targetText: targetText)
    }

    static func progress(_ inputText: String, targetText: String) -> Double {
        analyze(inputText, targetText: targetText).progress
    }

    static func isComplete(_ inputText: String, targetText: String) -> Bool {
        inputText == targetText
    }
}
